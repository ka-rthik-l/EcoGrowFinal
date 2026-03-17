# PDF Export — Audit Report Setup Guide

## Current State

The **"Export Audit Report (PDF)"** button exists in `lib/pages/analysis_page.dart` (line 217–227) but `onPressed` is empty — it does nothing yet.

```dart
OutlinedButton.icon(
  onPressed: () {},   // ← nothing wired up
  icon: const Icon(Icons.file_download_outlined),
  label: const Text('Export Audit Report (PDF)'),
)
```

No PDF package is installed in `pubspec.yaml`.

---

## Is It Possible? ✅ Yes — Fully Achievable

PDF generation + download is well-supported in Flutter. Complexity is **medium** — roughly 3–4 hours of focused work.

---

## Complexity Breakdown

### 1. Package Choice (Low complexity)

Two main options:

| Package | Complexity | Best For |
|---|---|---|
| [`pdf`](https://pub.dev/packages/pdf) + [`printing`](https://pub.dev/packages/printing) | ⭐⭐ Medium | Full custom layout, charts, logos |
| [`flutter_to_pdf`](https://pub.dev/packages/flutter_to_pdf) | ⭐ Low | Capture existing Flutter widgets as-is |

**Recommended:** `pdf` + `printing` — industry standard, works on Android/iOS/Web/Desktop.

```yaml
# Add to pubspec.yaml
dependencies:
  pdf: ^3.10.8
  printing: ^5.12.0
```

---

### 2. PDF Content to Generate (Medium complexity)

The report must pull live data already available in the widget state:

| Section | Data Source | Notes |
|---|---|---|
| Header | App name, timestamp, user email | Static + `DateTime.now()` |
| Soil Classification | `_label`, `_isOrganic` | Already fetched |
| Health Score | `_healthScore` | Draw as a progress bar in PDF |
| Interpretation | `_interpretation` | Multi-line text block |
| Audit Detail Breakdown | `_metrics` map | Table with status badges |
| Footer | Report ID, disclaimer | Static text |

No extra API calls needed — all data is already loaded in `_AnalysisPageState`.

---

### 3. PDF Generation Code (Medium complexity)

You write the layout using the `pdf` package's own widget system (similar to Flutter but separate):

```dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<void> _exportPdf() async {
  final doc = pw.Document();

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    build: (pw.Context context) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('EcoGrow — Soil Audit Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('Generated: ${DateTime.now()}'),
        pw.Divider(),
        pw.Text('Classification: ${_label.toUpperCase()}'),
        pw.Text('Health Score: $_healthScore%'),
        pw.Text('Organic: ${_isOrganic ? "Yes ✅" : "No ❌"}'),
        pw.SizedBox(height: 16),
        pw.Text('Interpretation:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Text(_interpretation),
        pw.SizedBox(height: 16),
        pw.Text('Audit Metrics:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ..._metrics.entries.map((e) =>
          pw.Row(children: [
            pw.Text('${e.key.toUpperCase()}: '),
            pw.Text(e.value),
          ])
        ),
      ],
    ),
  ));

  // Show native print/share/save dialog
  await Printing.layoutPdf(onLayout: (_) async => doc.save());
}
```

---

### 4. Save vs Print vs Share (Low complexity)

The `printing` package handles all three in one call:

| Method | What it does |
|---|---|
| `Printing.layoutPdf()` | Opens native **print dialog** (save as PDF option included) |
| `Printing.sharePdf()` | Opens native **share sheet** (WhatsApp, Drive, email, etc.) |
| `FileSaver` package | Saves directly to **Downloads folder** silently |

**Simplest approach:** `Printing.layoutPdf()` — zero extra permissions needed, works on Android + iOS.

---

### 5. Android Permissions (Low complexity if using `Printing`)

- Using `Printing.layoutPdf()` or `Printing.sharePdf()` → **No extra permissions needed**.
- Using `FileSaver` to save directly to storage → Requires `WRITE_EXTERNAL_STORAGE` permission (Android 12 and below) or `MANAGE_EXTERNAL_STORAGE` (Android 13+). This adds complexity.

**Recommendation:** Stick with `Printing.layoutPdf()` to avoid permission headaches.

---

## Overall Complexity Rating

| Task | Effort |
|---|---|
| Add packages to pubspec.yaml | 5 min |
| Write `_exportPdf()` method | 30–60 min |
| Style the PDF (logo, colors, table borders) | 1–2 hrs |
| Wire button `onPressed` | 2 min |
| Test on Android device | 30 min |
| **Total** | **~3–4 hrs** |

**Difficulty: 4/10** — No backend changes needed, no permissions issues if using `Printing`, all data already available in state.

---

## What Would NOT Work

- ❌ Rendering Flutter widgets directly as PDF (the `pdf` package uses its own layout system, not Flutter's)
- ❌ Charts/graphs from `fl_chart` cannot be directly embedded — would need to be redrawn using `pdf`'s `pw.Chart` or rendered as an image first using `printing`'s `rasterizeWidget()`

---

## Recommended Implementation Steps (when ready)

1. Add `pdf: ^3.10.8` and `printing: ^5.12.0` to `pubspec.yaml`
2. Run `flutter pub get`
3. Create `_exportPdf()` method in `_AnalysisPageState`
4. Replace `onPressed: () {}` with `onPressed: _exportPdf`
5. Test on device — the native Android print dialog will appear with a "Save as PDF" option
