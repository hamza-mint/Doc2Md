# install.ps1 - installs smart_doc2md.py + Windows Explorer right-click entry.
#
# NOT tested on a real Windows machine yet - this was written based on
# standard Windows conventions, not verified end-to-end. Run it, and if
# anything breaks, report back so it can be fixed.
#
# Run in a normal (non-admin) PowerShell window:
#   powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = "Stop"
$RepoDir = Split-Path -Parent $PSScriptRoot
$InstallDir = "$env:LOCALAPPDATA\doc2md"
$Extensions = @(".pdf", ".docx", ".doc", ".pptx", ".ppt", ".xlsx", ".xls",
                ".odt", ".ods", ".odp", ".rtf", ".csv")

Write-Host "==> Checking dependencies"

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Error "npm not found. Install Node.js from nodejs.org first, then re-run this script."
    exit 1
}

if (-not (Get-Command anydoc -ErrorAction SilentlyContinue)) {
    Write-Host "Installing anydoc..."
    npm install -g @firecrawl/anydoc
}

if (-not (Get-Command pdftotext -ErrorAction SilentlyContinue)) {
    Write-Warning "poppler (pdftotext/pdfinfo/pdfseparate) not found on PATH."
    Write-Warning "Install it with one of:"
    Write-Warning "  scoop install poppler        (https://scoop.sh)"
    Write-Warning "  choco install poppler         (https://chocolatey.org)"
    Write-Warning "  or a manual build: https://github.com/oschwartz10612/poppler-windows"
    Write-Warning "Install it, then re-run this script."
    exit 1
}

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Error "python not found on PATH. Install Python 3 from python.org (check 'Add to PATH' during setup), then re-run."
    exit 1
}

Write-Host "==> Installing script to $InstallDir"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item "$RepoDir\smart_doc2md.py" "$InstallDir\smart_doc2md.py" -Force

Write-Host "==> Registering right-click 'Convert to Markdown' entry (current user only, no admin needed)"
$PythonPath = (Get-Command python).Source
foreach ($ext in $Extensions) {
    $KeyPath = "HKCU:\Software\Classes\SystemFileAssociations\$ext\shell\ConvertToMarkdown"
    New-Item -Path $KeyPath -Force | Out-Null
    Set-ItemProperty -Path $KeyPath -Name "(default)" -Value "Convert to Markdown (anydoc)"
    New-Item -Path "$KeyPath\command" -Force | Out-Null
    $Command = '"' + $PythonPath + '" "' + "$InstallDir\smart_doc2md.py" + '" "%1"'
    Set-ItemProperty -Path "$KeyPath\command" -Name "(default)" -Value $Command
}

Write-Host "==> API key (optional, needed for hosted OCR of scanned pages)"
$KeyDir = "$env:APPDATA\anydoc"
$KeyFile = "$KeyDir\api_key"
if (-not (Test-Path $KeyFile)) {
    $Key = Read-Host "Firecrawl API key (from firecrawl.dev - press Enter to skip)"
    if ($Key) {
        New-Item -ItemType Directory -Force -Path $KeyDir | Out-Null
        Set-Content -Path $KeyFile -Value $Key -NoNewline
        Write-Host "Saved to $KeyFile"
    } else {
        Write-Host "Skipped. OCR will run keyless (limited) until you add one at $KeyFile"
    }
}

Write-Host "==> Done. Right-click a supported file -> Convert to Markdown."
Write-Host "    Note: only converts one file at a time (multi-select isn't wired up yet)."
