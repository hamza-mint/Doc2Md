# doc2md

يحول أي مستند (PDF, docx, pptx, xlsx, odt, ods, odp, rtf, csv) لملف
Markdown نظيف — مفيد لتغذية محتوى المستند لأي AI بأقل توكنز وأعلى دقة،
بدل ما تدّيه الملف الخام أو صورة سكان.

## ليه صفحة PDF بصفحة بدل الملف كله دفعة واحدة؟

- استخراج anydoc المحلي بيقلب حروف العربي (RTL) لو الصفحة فيها نص حقيقي
  — الكود بيتفادى ده باستخدام `pdftotext` بدل anydoc على أي صفحة فيها
  نص حقيقي (عربي أو إنجليزي، النتيجة سليمة في الحالتين).
- ملف سكان كبير (كذا صفحة) بيفشل أحياناً لو اتبعت كله مرة واحدة للـ OCR
  السحابي (`Firecrawl Parse: status code 499`) — فكل صفحة سكان بتتبعت
  لوحدها.

## المتطلبات

- [Node.js/npm](https://nodejs.org) → `npm install -g @firecrawl/anydoc`
- Python 3
- [poppler](https://poppler.freedesktop.org/) (`pdftotext`, `pdfinfo`, `pdfseparate`)
- مفتاح [Firecrawl](https://firecrawl.dev) مجاني (اختياري، بس لازم لو
  محتاج OCR لملفات سكان)

## التركيب

```
doc2md/
├── smart_doc2md.py      # المنطق الأساسي - متعدد الأنظمة (Linux/macOS/Windows)
├── linux/                # تكامل right-click في Dolphin (KDE)
│   ├── install.sh
│   └── doc2md.desktop
├── windows/               # تكامل right-click في Windows Explorer
│   └── install.ps1        # لسه مش مجرب فعلياً على ويندوز حقيقي - جرّبه وقولّي
└── skill/                 # Skill جاهز لـ Claude Code / Claude Desktop
    ├── SKILL.md
    └── smart_doc2md.py
```

## التثبيت

### Linux (KDE / Dolphin)

```bash
./linux/install.sh
```

بيثبت anydoc، يتأكد من poppler، ينسخ السكريبت، ويسجل زرار "Convert to
Markdown" في قائمة الفأرة اليمين على Dolphin.

### Windows

```powershell
powershell -ExecutionPolicy Bypass -File windows\install.ps1
```

**ملاحظة:** الجزء ده اتكتب على أساس الطريقة المعيارية لعمل تكامل زي ده
على ويندوز، لكن **معملوش اختبار فعلي على جهاز ويندوز حقيقي**. جرّبه
وابلّغ عن أي مشكلة.

### تشغيل مباشر من غير أي تكامل (أي نظام فيه Python)

```bash
python3 smart_doc2md.py file1.pdf file2.docx
```

بينتج ملف `.md` جنب كل ملف أصلي.

### كـ Skill لـ Claude Code / Claude Desktop

انسخ مجلد `skill/` لمجلد الـ skills بتاع الأداة اللي بتستخدمها. راجع
`skill/SKILL.md` للتفاصيل.

## مفتاح الـ API

```bash
mkdir -p ~/.config/anydoc && echo "YOUR_KEY" > ~/.config/anydoc/api_key   # Linux/macOS
```

```powershell
mkdir "$env:APPDATA\anydoc"; "YOUR_KEY" | Set-Content "$env:APPDATA\anydoc\api_key"   # Windows
```

من غير مفتاح، الـ OCR السحابي بيشتغل بوضع محدود ("keyless").
