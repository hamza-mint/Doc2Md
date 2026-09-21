#!/usr/bin/env python3
"""
smart_doc2md.py - convert any office document to Markdown.

Cross-platform core (Linux / macOS / Windows). Right-click / context-menu
integration is set up separately per OS - see linux/ and windows/.

Why PDFs are handled page-by-page instead of handed whole to anydoc:
  1. anydoc's native PDF text extraction reverses Arabic (RTL) glyph
     order character-by-character - confirmed by direct test. pdftotext
     does not have this bug, so any page with a real text layer is
     extracted with pdftotext instead, regardless of language.
  2. A large multi-page scanned PDF sent to hosted OCR in a single
     request can fail with "Firecrawl Parse: status code 499"
     (connection cut before OCR finishes) - confirmed on a 10-page/8MB
     scan. A single page from the same file OCRs fine, so each scanned
     page is sent to hosted OCR individually.

Requires on PATH: anydoc, pdftotext, pdfinfo, pdfseparate (poppler).
Optional Firecrawl API key (for hosted OCR of scanned pages):
  Linux/macOS: ~/.config/anydoc/api_key
  Windows:     %APPDATA%\\anydoc\\api_key
Without a key, anydoc's OCR call still runs "keyless" with tighter
limits - fine for occasional use, get a free key at firecrawl.dev for
anything regular.
"""

import os
import platform
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

SUPPORTED_EXTENSIONS = {
    ".pdf", ".docx", ".doc", ".pptx", ".ppt", ".xlsx", ".xls",
    ".odt", ".ods", ".odp", ".rtf", ".csv",
}


def get_api_key():
    if platform.system() == "Windows":
        key_path = Path(os.environ.get("APPDATA", "")) / "anydoc" / "api_key"
    else:
        key_path = Path.home() / ".config" / "anydoc" / "api_key"
    if key_path.exists():
        return key_path.read_text(encoding="utf-8").strip()
    return None


def notify(title, message):
    """Best-effort desktop notification; always also prints to stdout."""
    system = platform.system()
    try:
        if system == "Linux" and shutil.which("notify-send"):
            subprocess.run(["notify-send", title, message], check=False)
        elif system == "Darwin":
            script = f'display notification "{message}" with title "{title}"'
            subprocess.run(["osascript", "-e", script], check=False)
        elif system == "Windows":
            # Untested on a real Windows machine - verify. Falls back to
            # a plain print if PowerShell/WinForms isn't available.
            ps = (
                '[System.Reflection.Assembly]::LoadWithPartialName('
                '"System.Windows.Forms") | Out-Null; '
                '$n = New-Object System.Windows.Forms.NotifyIcon; '
                '$n.Icon = [System.Drawing.SystemIcons]::Information; '
                '$n.Visible = $true; '
                f'$n.ShowBalloonTip(4000, "{title}", "{message}", "Info")'
            )
            subprocess.run(["powershell", "-NoProfile", "-Command", ps], check=False)
    except Exception:
        pass
    print(f"[{title}] {message}")


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


def pdf_page_count(pdf_path):
    result = run(["pdfinfo", str(pdf_path)])
    for line in result.stdout.splitlines():
        if line.startswith("Pages:"):
            return int(line.split(":", 1)[1].strip())
    return None


def pdftotext_page(pdf_path, page_num):
    result = run(["pdftotext", "-layout", "-f", str(page_num), "-l", str(page_num),
                  str(pdf_path), "-"])
    return result.stdout


def convert_pdf(pdf_path: Path, out_path: Path, api_key):
    pages = pdf_page_count(pdf_path)
    if pages is None:
        notify("فشل التحويل", f"{pdf_path.name}: تعذر قراءة الملف (pdfinfo فشل)")
        return

    ocr_pages = 0
    failed_pages = 0
    chunks = []

    with tempfile.TemporaryDirectory() as tmp:
        tmpdir = Path(tmp)
        for i in range(1, pages + 1):
            text = pdftotext_page(pdf_path, i)
            if text.strip():
                chunks.append(text.rstrip() + "\n")
                continue

            page_pdf = tmpdir / f"page_{i}.pdf"
            page_md = tmpdir / f"page_{i}.md"
            run(["pdfseparate", "-f", str(i), "-l", str(i), str(pdf_path), str(page_pdf)])

            cmd = ["anydoc", str(page_pdf), "-o", str(page_md), "--ocr", "hosted"]
            if api_key:
                cmd += ["--api-key", api_key]
            result = run(cmd)

            if result.returncode == 0 and page_md.exists():
                chunks.append(page_md.read_text(encoding="utf-8").rstrip() + "\n")
                ocr_pages += 1
            else:
                err = (result.stderr or result.stdout).strip()
                chunks.append(f"[صفحة {i}: فشل التحويل - {err}]\n")
                failed_pages += 1

    out_path.write_text("\n".join(chunks), encoding="utf-8")

    if failed_pages:
        notify("تحويل جزئي", f"{pdf_path.name}: {failed_pages} صفحة فشلت من أصل {pages}")
    elif ocr_pages:
        notify("تحويل المستند", f"{pdf_path.name}: {ocr_pages} صفحة احتاجت OCR سحابي من أصل {pages}")
    else:
        notify("تحويل المستند", f"{pdf_path.name}: تم محلياً بالكامل ({pages} صفحة)")


def convert_other(path: Path, out_path: Path):
    result = run(["anydoc", str(path), "-o", str(out_path)])
    if result.returncode == 0:
        notify("تحويل المستند", f"{path.name}: تم بنجاح")
    else:
        err = (result.stderr or result.stdout).strip()
        notify("فشل التحويل", f"{path.name}: {err}")


def main():
    if len(sys.argv) < 2:
        print("Usage: smart_doc2md.py <file1> [file2 ...]", file=sys.stderr)
        sys.exit(2)

    if not shutil.which("anydoc"):
        print("anydoc not found on PATH - run: npm install -g @firecrawl/anydoc",
              file=sys.stderr)
        sys.exit(1)

    api_key = get_api_key()

    for arg in sys.argv[1:]:
        path = Path(arg)
        if not path.exists():
            print(f"skip (not found): {path}", file=sys.stderr)
            continue
        if path.suffix.lower() not in SUPPORTED_EXTENSIONS:
            print(f"skip (unsupported type): {path}", file=sys.stderr)
            continue

        out_path = path.with_suffix(".md")
        if path.suffix.lower() == ".pdf":
            convert_pdf(path, out_path, api_key)
        else:
            convert_other(path, out_path)


if __name__ == "__main__":
    main()
