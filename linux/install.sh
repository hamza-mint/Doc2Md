#!/usr/bin/env bash
# Installs smart_doc2md.py + the Dolphin (KDE) right-click integration.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$HOME/.local/bin"
SERVICEMENU_DIR="$HOME/.local/share/kio/servicemenus"
[ -d "$SERVICEMENU_DIR" ] || SERVICEMENU_DIR="$HOME/.local/share/kservices5/ServiceMenus"

echo "==> Checking dependencies"

if ! command -v npm >/dev/null 2>&1; then
    echo "npm not found. Install Node.js first (nvm, or your package manager), then re-run this script." >&2
    exit 1
fi

if ! command -v anydoc >/dev/null 2>&1; then
    echo "Installing anydoc..."
    npm install -g @firecrawl/anydoc
fi

if ! command -v pdftotext >/dev/null 2>&1; then
    echo "poppler-utils (pdftotext/pdfinfo/pdfseparate) not found."
    if command -v dnf >/dev/null 2>&1; then
        echo "   Run: sudo dnf install poppler-utils"
    elif command -v apt >/dev/null 2>&1; then
        echo "   Run: sudo apt install poppler-utils"
    fi
    echo "Install it, then re-run this script."
    exit 1
fi

echo "==> Installing script"
mkdir -p "$BIN_DIR"
cp "$REPO_DIR/smart_doc2md.py" "$BIN_DIR/smart_doc2md.py"
chmod +x "$BIN_DIR/smart_doc2md.py"

echo "==> Installing Dolphin right-click entry"
mkdir -p "$SERVICEMENU_DIR"
sed "s|@HOME@|$HOME|g" "$REPO_DIR/linux/doc2md.desktop" > "$SERVICEMENU_DIR/doc2md.desktop"
chmod +x "$SERVICEMENU_DIR/doc2md.desktop"

if command -v kbuildsycoca6 >/dev/null 2>&1; then
    kbuildsycoca6 >/dev/null 2>&1 || true
elif command -v kbuildsycoca5 >/dev/null 2>&1; then
    kbuildsycoca5 >/dev/null 2>&1 || true
fi

echo "==> API key (optional, needed for hosted OCR of scanned pages)"
KEY_DIR="$HOME/.config/anydoc"
KEY_FILE="$KEY_DIR/api_key"
if [ ! -f "$KEY_FILE" ]; then
    read -rp "Firecrawl API key (from firecrawl.dev - press Enter to skip): " KEY
    if [ -n "${KEY:-}" ]; then
        mkdir -p "$KEY_DIR"
        printf '%s' "$KEY" > "$KEY_FILE"
        chmod 600 "$KEY_FILE"
        echo "Saved to $KEY_FILE"
    else
        echo "Skipped. OCR will run keyless (limited) until you add one at $KEY_FILE"
    fi
fi

echo "==> Done. Right-click a PDF/docx/pptx/xlsx in Dolphin -> Convert to Markdown."
