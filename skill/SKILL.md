---
name: doc2md
description: Use this skill whenever you are given, or need to read, an office document or PDF (pdf, docx, pptx, xlsx, odt, ods, odp, rtf, csv) as part of a task. Convert it to Markdown with this skill's script BEFORE reading its contents, instead of reading the raw file directly (via vision/OCR on a PDF, or a generic document parser). This produces a clean, compact Markdown version that is far cheaper in tokens and easier to reason about than the raw file - especially for scanned/image PDFs, which are otherwise expensive to read directly. Trigger on any raw pdf/docx/pptx/xlsx/odt/rtf/csv file path or attachment you are about to open or transcribe.
---

# doc2md - convert documents to Markdown before reading them

## Why

Reading a raw PDF (especially a scanned one) or an office file directly
costs far more tokens than reading the same content as clean Markdown,
and is more error-prone for the model to parse. This skill converts
first, so you read structured text instead.

## How to use

Run the bundled script on the file, then read the `.md` file it
produces instead of the original:

```bash
python3 <path-to-this-skill>/smart_doc2md.py "/path/to/file.pdf"
```

This writes `/path/to/file.md` next to the original (same name, `.md`
extension). Read that file's contents for your task.

For multiple files, pass them all in one call:

```bash
python3 <path-to-this-skill>/smart_doc2md.py "file1.pdf" "file2.docx" "file3.pptx"
```

## What it does differently from a plain converter

- PDFs are processed page-by-page. A page with a real text layer is
  extracted with `pdftotext` (correct reading order for Arabic and
  other RTL scripts - `anydoc`'s own native PDF text extraction
  reverses RTL glyph order and is deliberately NOT used for these
  pages). A page with no text layer (scanned/image) is OCR'd
  individually via `anydoc --ocr hosted`, avoiding request failures
  that happen when a large multi-page scan is OCR'd in one request.
- Non-PDF formats (docx, pptx, xlsx, odt, ods, odp, rtf, csv) are
  converted as a whole file via `anydoc`.

## Requirements

- `anydoc` on PATH (`npm install -g @firecrawl/anydoc`)
- `pdftotext`, `pdfinfo`, `pdfseparate` on PATH (poppler)
- Optional Firecrawl API key for hosted OCR of scanned pages:
  `~/.config/anydoc/api_key` (Linux/macOS) or
  `%APPDATA%\anydoc\api_key` (Windows). Without one, OCR still runs in
  a limited "keyless" mode.

## If the script fails or isn't installed

Fall back to reading the file directly rather than blocking the task,
and mention to the user that doc2md's dependencies aren't set up.
