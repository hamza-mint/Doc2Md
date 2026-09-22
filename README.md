# doc2md

Convert any office document (PDF, DOCX, PPTX, XLSX, ODT, ODS, ODP, RTF, CSV) into clean Markdown — built specifically so the output can be fed to an AI model with far fewer tokens and much better comprehension than handing it the raw file (or a scanned image).

## Why this exists

Feeding an AI a raw PDF — especially a scanned one — is expensive (images cost far more tokens than text) and often produces worse results than giving it clean, structured Markdown. This tool converts documents to Markdown first, using deterministic command-line tools rather than a model, so the conversion itself costs zero AI tokens.

It's built on [`anydoc`](https://github.com/firecrawl/anydoc) (Firecrawl), but does **not** hand PDFs to `anydoc` as a whole file. Two real bugs were found and fixed by processing PDFs page-by-page instead:

1. **Arabic/RTL text gets reversed.** `anydoc`'s native PDF text extraction reverses right-to-left glyph order character-by-character on any page with a real text layer — `"اختبار اللغة"` comes out as `"ةغللا رابتخا"`. This happens even when the document is also routed through hosted OCR — the bug hits the text-layer pages regardless of the OCR flag. Confirmed by direct testing. **Fix:** any page with a real text layer is extracted with `pdftotext` instead, which preserves correct order for both Arabic and English.
2. **Large scanned PDFs can fail OCR entirely.** Sending a big multi-page scanned PDF to hosted OCR in a single request can fail with `Firecrawl Parse: status code 499` (the connection is cut before OCR finishes). Confirmed on a real 10-page / 8 MB scanned file — the same file's first page alone OCR'd successfully. **Fix:** each scanned page is extracted and sent to hosted OCR individually, then the results are spliced back together in the correct page order.

A known limitation: a single PDF that mixes real-text Arabic pages with scanned image pages in the *same* file isn't fully solved yet — the current logic pulls the real-text pages correctly via `pdftotext` but doesn't yet re-inject OCR results for the scanned pages of that same file inline with them in all cases. This is on the list to improve.

## How it works

For each file:
- **Non-PDF formats** (DOCX, PPTX, XLSX, ODT, ODS, ODP, RTF, CSV) are converted as a whole file via `anydoc`.
- **PDFs** are processed one page at a time:
  1. Try `pdftotext -layout` on the page. If it returns real text, use it directly (correct order, any language, no size limit, free, instant).
  2. If the page has no text layer (i.e. it's a scanned image), extract just that page as a standalone one-page PDF and send it alone to `anydoc --ocr hosted`.
  3. Splice every page's result back together in the original page order into one Markdown file.

A desktop notification reports whether the file converted fully locally, needed cloud OCR for some pages, or partially failed.

## Repository layout

```
doc2md/
├── smart_doc2md.py    # Core conversion logic — cross-platform (Linux/macOS/Windows)
├── linux/             # Right-click integration for Dolphin (KDE Plasma)
│   ├── install.sh      #   Installer: checks deps, installs the script, registers the menu entry
│   └── doc2md.desktop  #   KDE service menu definition (template — install.sh fills in your home path)
├── windows/            # Right-click integration for Windows Explorer
│   └── install.ps1      #   Installer: checks deps, installs the script, registers a context-menu entry
│                         #   NOT yet verified on a real Windows machine — see "Windows" section below
└── skill/              # A Claude Agent Skill wrapping this tool
    ├── SKILL.md          #   Tells a Claude agent (Claude Code / Claude Desktop) to convert
    │                     #   documents with this script before reading them, instead of
    │                     #   reading raw files directly
    └── smart_doc2md.py   #   A copy of the core script, bundled so the skill folder is self-contained
```

## Requirements

| Tool | Purpose | Install |
|---|---|---|
| Node.js + npm | Runs `anydoc` | [nodejs.org](https://nodejs.org) |
| `anydoc` | Converts non-PDF formats; hosted OCR for scanned PDF pages | `npm install -g @firecrawl/anydoc` |
| Python 3 | Runs the core script | [python.org](https://python.org) (usually preinstalled on Linux/macOS) |
| `poppler` (`pdftotext`, `pdfinfo`, `pdfseparate`) | Reads PDF text layers and splits pages | see below |
| Firecrawl API key (optional) | Higher-quality/higher-limit hosted OCR | free at [firecrawl.dev](https://firecrawl.dev) |

**Installing poppler:**
- Fedora: `sudo dnf install poppler-utils`
- Debian/Ubuntu: `sudo apt install poppler-utils`
- macOS: `brew install poppler`
- Windows: `scoop install poppler`, or `choco install poppler`, or a manual build from [oschwartz10612/poppler-windows](https://github.com/oschwartz10612/poppler-windows)

Without an API key, hosted OCR still runs in a limited "keyless" mode — fine for occasional use.

## Installation — Linux (KDE Plasma / Dolphin)

1. Clone this repo.
2. Run the installer:
   ```bash
   ./linux/install.sh
   ```
3. The installer will:
   - Check for `npm`, `anydoc`, and `pdftotext` (and tell you exactly what to install if anything's missing)
   - Copy `smart_doc2md.py` to `~/.local/bin/`
   - Copy `linux/doc2md.desktop` to `~/.local/share/kio/servicemenus/` (substituting your real home directory in place of the template placeholder)
   - Rebuild KDE's service cache (`kbuildsycoca6`/`kbuildsycoca5`) so the new menu entry shows up immediately, with no restart needed
   - Prompt you for a Firecrawl API key (optional — press Enter to skip)
4. Right-click any PDF/DOCX/PPTX/XLSX/ODT/RTF/CSV file in Dolphin → **Convert to Markdown (anydoc)**.

## Installation — Windows

> **Not yet tested on a real Windows machine.** This was written to standard Windows conventions but hasn't been run end-to-end. Please test it and report any issues.

1. Clone this repo.
2. Open a normal (non-administrator) PowerShell window in the repo folder and run:
   ```powershell
   powershell -ExecutionPolicy Bypass -File windows\install.ps1
   ```
3. The installer will:
   - Check for `npm`, `anydoc`, `pdftotext`, and `python` (and tell you what to install if anything's missing)
   - Copy `smart_doc2md.py` to `%LOCALAPPDATA%\doc2md\`
   - Register a **Convert to Markdown** entry under `HKEY_CURRENT_USER\Software\Classes\SystemFileAssociations\<ext>\shell\` for each supported extension (current-user only — no administrator rights needed)
   - Prompt you for a Firecrawl API key (optional — press Enter to skip)
4. Right-click a supported file in File Explorer → **Convert to Markdown (anydoc)**.

**Known limitation on Windows:** the context menu entry converts one file at a time (`%1`); multi-select batch conversion isn't wired up yet.

## Direct usage (any OS with Python — no right-click integration needed)

```bash
python3 smart_doc2md.py file1.pdf file2.docx file3.pptx
```

This writes a `.md` file next to each input file (same name, `.md` extension).

## Using it as a Claude Agent Skill

If you use Claude Code, Claude Desktop, or another agent that supports Skills, copy the `skill/` folder into that tool's skills directory. See `skill/SKILL.md` for what it tells the agent to do (convert documents with this script before reading them, instead of reading raw files or images directly — saving tokens and avoiding the bugs described above).

## Setting the Firecrawl API key manually

```bash
mkdir -p ~/.config/anydoc && echo "YOUR_KEY" > ~/.config/anydoc/api_key   # Linux/macOS
chmod 600 ~/.config/anydoc/api_key
```

```powershell
New-Item -ItemType Directory -Force "$env:APPDATA\anydoc"
"YOUR_KEY" | Set-Content "$env:APPDATA\anydoc\api_key" -NoNewline
```

## Troubleshooting

- **"You are not authorized to execute this file" (Dolphin/KDE):** the `.desktop` file itself needs execute permission, not just the script it points to. `chmod +x` the file under `~/.local/share/kio/servicemenus/` and rebuild the cache with `kbuildsycoca6` (or `kbuildsycoca5` on Plasma 5).
- **Right-click entry doesn't appear at all:** rebuild KDE's service cache (`kbuildsycoca6`) or log out/in. On Windows, confirm the registry keys were created under `HKCU:\Software\Classes\SystemFileAssociations\<ext>\shell\ConvertToMarkdown`.
- **`Firecrawl Parse: status code 499`:** this is exactly the large-scanned-file bug described above — make sure you're running the page-by-page version of the script (`smart_doc2md.py` in this repo), not calling `anydoc --ocr hosted` on the whole file yourself.
- **Arabic text comes out reversed:** same root cause as above — make sure the PDF page in question actually has a real text layer (run `pdftotext -layout -f N -l N file.pdf -` on that page number to check) and that you're using this repo's script rather than calling `anydoc` directly on the PDF.

## License

MIT — use it, fork it, adapt it.
