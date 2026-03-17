import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/api_service.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  bool _loading = true;
  String? _error;

  // Analysis data
  int _healthScore = 0;
  bool _isOrganic = false;
  String _label = '';
  String _interpretation = '';
  Map<String, String> _metrics = {};

  // Trends data (last week)
  List<double> _nitrogen = [];
  List<double> _phosphorus = [];
  List<double> _potassium = [];
  List<double> _moisture = [];
  List<String> _timestamps = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Fetch analysis + trends in parallel
      final results = await Future.wait([
        ApiService().getAnalysis(),
        ApiService().getTrends('week'),
      ]);

      final analysis = results[0];
      final trends = results[1];

      if (!mounted) return;
      setState(() {
        _healthScore = (analysis['healthScore'] as num).toInt();
        _isOrganic = analysis['isOrganic'] as bool;
        _label = analysis['label'] ?? '';
        _interpretation = analysis['interpretation'] ?? '';
        _metrics = Map<String, String>.from(analysis['metrics'] as Map);

        _nitrogen = _castDoubleList(trends['nitrogen']);
        _phosphorus = _castDoubleList(trends['phosphorus']);
        _potassium = _castDoubleList(trends['potassium']);
        _moisture = _castDoubleList(trends['moisture']);
        _timestamps = List<String>.from(trends['timestamps'] ?? []);

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load audit analysis.';
        _loading = false;
      });
    }
  }

  List<double> _castDoubleList(dynamic raw) {
    if (raw == null) return [];
    return (raw as List).map((e) => (e as num).toDouble()).toList();
  }

  // ── Stats helpers ────────────────────────────────────────────────────────
  double _avg(List<double> l) =>
      l.isEmpty ? 0 : l.reduce((a, b) => a + b) / l.length;
  double _min(List<double> l) => l.isEmpty ? 0 : l.reduce(min);
  double _max(List<double> l) => l.isEmpty ? 0 : l.reduce(max);
  String _fmt(double v) => v.toStringAsFixed(1);

  String _shortTs(String ts) {
    if (ts.length < 10) return ts;
    return ts.substring(0, 10); // "2026-03-17"
  }

  // ── PDF Export ───────────────────────────────────────────────────────────
  Future<void> _exportPdf() async {
    final doc = pw.Document();
    final now = DateTime.now();
    final reportId =
        'ECO-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch % 10000}';

    final primaryGreen = PdfColor.fromHex('#1B4332');
    final lightGreen = PdfColor.fromHex('#D1FAE5');
    final accentGreen = PdfColor.fromHex('#52B788');

    final alertOrange = PdfColor.fromHex('#F97316');
    final grey = PdfColor.fromHex('#6B7280');
    final lightGrey = PdfColor.fromHex('#F9FAFB');
    final borderGrey = PdfColor.fromHex('#E5E7EB');
    final white = PdfColors.white;

    // Classification status colour
    final statusColor = _isOrganic ? accentGreen : alertOrange;

    // Date range string
    final dateFrom =
        _timestamps.isNotEmpty ? _shortTs(_timestamps.first) : 'N/A';
    final dateTo =
        _timestamps.isNotEmpty ? _shortTs(_timestamps.last) : 'N/A';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 12),
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: pw.BoxDecoration(
            color: primaryGreen,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'EcoGrow',
                    style: pw.TextStyle(
                      color: white,
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Soil Audit Report',
                    style: pw.TextStyle(color: accentGreen, fontSize: 11),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Report ID: $reportId',
                    style: pw.TextStyle(color: white, fontSize: 9),
                  ),
                  pw.Text(
                    'Generated: ${now.day}/${now.month}/${now.year}  ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                    style: pw.TextStyle(color: white, fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'EcoGrow Soil Intelligence Platform',
                style: pw.TextStyle(color: grey, fontSize: 8),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(color: grey, fontSize: 8),
              ),
            ],
          ),
        ),
        build: (context) => [
          // ── SECTION 1: Classification Summary ────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: primaryGreen,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      _label.toUpperCase().replaceAll('_', ' '),
                      style: pw.TextStyle(
                        color: white,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      _isOrganic
                          ? 'ORGANIC VERIFIED ✓'
                          : 'CHEMICAL TRACES DETECTED',
                      style: pw.TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      '$_healthScore%',
                      style: pw.TextStyle(
                        color: white,
                        fontSize: 36,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Health Score',
                      style: pw.TextStyle(color: accentGreen, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 16),

          // ── SECTION 2: Interpretation ─────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: _isOrganic
                  ? PdfColor.fromHex('#ECFDF5')
                  : PdfColor.fromHex('#FFF7ED'),
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(
                color: _isOrganic
                    ? PdfColor.fromHex('#A7F3D0')
                    : PdfColor.fromHex('#FED7AA'),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'ML Interpretation',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryGreen,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  _interpretation,
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: _isOrganic
                        ? PdfColor.fromHex('#065F46')
                        : PdfColor.fromHex('#9A3412'),
                    lineSpacing: 3,
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 16),

          // ── SECTION 3: Audit Metrics ──────────────────────────────────────
          pw.Text(
            'AUDIT METRICS',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: primaryGreen,
              letterSpacing: 1,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: borderGrey, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: primaryGreen),
                children: [
                  _tableHeader('Metric', white),
                  _tableHeader('Status', white),
                ],
              ),
              ..._metrics.entries.map((e) {
                final isGood = e.value.toLowerCase().contains('optimal') ||
                    e.value.toLowerCase().contains('stable') ||
                    e.value.toLowerCase().contains('good');
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: lightGrey),
                  children: [
                    _tableCell(e.key.toUpperCase()),
                    _tableCellColored(
                      e.value,
                      isGood
                          ? PdfColor.fromHex('#059669')
                          : PdfColor.fromHex('#B91C1C'),
                    ),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 20),

          // ── SECTION 4: Last 7-Day Sensor Summary ─────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'LAST 7-DAY SENSOR SUMMARY',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryGreen,
                  letterSpacing: 1,
                ),
              ),
              pw.Text(
                '$dateFrom  →  $dateTo  (${_timestamps.length} readings)',
                style: pw.TextStyle(color: grey, fontSize: 9),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: borderGrey, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1.2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: primaryGreen),
                children: [
                  _tableHeader('Sensor', white),
                  _tableHeader('Min', white),
                  _tableHeader('Max', white),
                  _tableHeader('Average', white),
                ],
              ),
              _sensorRow('Nitrogen (N)', _nitrogen, lightGreen, primaryGreen),
              _sensorRow('Phosphorus (P)', _phosphorus, lightGrey, PdfColor.fromHex('#374151')),
              _sensorRow('Potassium (K)', _potassium, lightGreen, primaryGreen),
              _sensorRow('Moisture', _moisture, lightGrey, PdfColor.fromHex('#374151')),
            ],
          ),

          pw.SizedBox(height: 20),

          // ── SECTION 5: Reading Trends Bar Summary ────────────────────
          if (_nitrogen.isNotEmpty) ...[
            pw.Text(
              'NITROGEN TREND (Last 20 Readings)',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: primaryGreen,
                letterSpacing: 1,
              ),
            ),
            pw.SizedBox(height: 8),
            _miniBarChart(_nitrogen.length > 20
                ? _nitrogen.sublist(_nitrogen.length - 20)
                : _nitrogen,
                primaryGreen),
            pw.SizedBox(height: 6),
            pw.Text(
              'Moisture Trend (Last 20 Readings)',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#0F766E'),
                letterSpacing: 1,
              ),
            ),
            pw.SizedBox(height: 8),
            _miniBarChart(_moisture.length > 20
                ? _moisture.sublist(_moisture.length - 20)
                : _moisture,
                PdfColor.fromHex('#0D9488')),
          ],

          pw.SizedBox(height: 20),

          // ── SECTION 6: Disclaimer ─────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: lightGrey,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: borderGrey, width: 0.5),
            ),
            child: pw.Text(
              'This report is auto-generated by the EcoGrow ML platform based on soil sensor telemetry. '
              'Results are indicative and should be corroborated with field inspection before regulatory action. '
              'Report ID: $reportId',
              style: pw.TextStyle(
                fontSize: 8,
                color: grey,
                lineSpacing: 3,
              ),
            ),
          ),
        ],
      ),
    );

    // Open system print/save dialog
    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'EcoGrow_Audit_$reportId.pdf',
    );
  }

  // ── PDF helper widgets ────────────────────────────────────────────────────
  pw.Widget _tableHeader(String text, PdfColor color) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );

  pw.Widget _tableCell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 9, color: PdfColor.fromHex('#374151'))),
      );

  pw.Widget _tableCellColored(String text, PdfColor color) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: pw.FontWeight.bold)),
      );

  pw.TableRow _sensorRow(
    String name,
    List<double> values,
    PdfColor bg,
    PdfColor textColor,
  ) =>
      pw.TableRow(
        decoration: pw.BoxDecoration(color: bg),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Text(name,
                style: pw.TextStyle(
                    fontSize: 9,
                    color: textColor,
                    fontWeight: pw.FontWeight.bold)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Text(_fmt(_min(values)),
                style: pw.TextStyle(fontSize: 9, color: textColor)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Text(_fmt(_max(values)),
                style: pw.TextStyle(fontSize: 9, color: textColor)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Text(_fmt(_avg(values)),
                style: pw.TextStyle(fontSize: 9, color: textColor)),
          ),
        ],
      );

  pw.Widget _miniBarChart(List<double> values, PdfColor barColor) {
    if (values.isEmpty) return pw.SizedBox();
    final maxVal = _max(values);
    final chartH = 50.0;
    return pw.Container(
      height: chartH + 20,
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F9FAFB'),
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColor.fromHex('#E5E7EB'), width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: values.map((v) {
                final barH = maxVal > 0 ? (v / maxVal) * chartH : 4.0;
                return pw.Container(
                  width: 8,
                  height: barH.clamp(4, chartH),
                  decoration: pw.BoxDecoration(
                    color: barColor,
                    borderRadius:
                        const pw.BorderRadius.vertical(top: pw.Radius.circular(2)),
                  ),
                );
              }).toList(),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Min: ${_fmt(_min(values))}',
                  style: pw.TextStyle(
                      fontSize: 7, color: PdfColor.fromHex('#6B7280'))),
              pw.Text('Avg: ${_fmt(_avg(values))}',
                  style: pw.TextStyle(
                      fontSize: 7, color: PdfColor.fromHex('#6B7280'))),
              pw.Text('Max: ${_fmt(_max(values))}',
                  style: pw.TextStyle(
                      fontSize: 7, color: PdfColor.fromHex('#6B7280'))),
            ],
          ),
        ],
      ),
    );
  }

  // ── Flutter UI ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(_error!,
                style: const TextStyle(color: Color(0xFF374151))),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry Analysis'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Model Prediction',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ML-based classification · ${_timestamps.length} readings this week',
              style:
                  const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
            const SizedBox(height: 32),

            // --- RESULT CARD ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF1B4332),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    _label.toUpperCase().replaceAll('_', ' '),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: CircularProgressIndicator(
                          value: _healthScore / 100,
                          strokeWidth: 12,
                          backgroundColor: Colors.white10,
                          color: _isOrganic
                              ? const Color(0xFF52B788)
                              : const Color(0xFFEF4444),
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            '$_healthScore%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Confidence',
                            style: TextStyle(
                                color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- INTERPRETATION ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _isOrganic
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _isOrganic
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFFEDD5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isOrganic
                            ? Icons.eco
                            : Icons.warning_amber_rounded,
                        color: _isOrganic
                            ? const Color(0xFF059669)
                            : const Color(0xFFC2410C),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isOrganic
                            ? 'ORGANIC VERIFIED'
                            : 'CHEMICAL TRACES DETECTED',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _isOrganic
                              ? const Color(0xFF059669)
                              : const Color(0xFFC2410C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _interpretation,
                    style: TextStyle(
                      color: _isOrganic
                          ? const Color(0xFF065F46)
                          : const Color(0xFF9A3412),
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- WEEK STATS PREVIEW ----
            if (_nitrogen.isNotEmpty) ...[
              const Text(
                'Last 7-Day Averages',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatChip('N', _avg(_nitrogen), const Color(0xFF1B4332)),
                  _StatChip('P', _avg(_phosphorus), const Color(0xFF92400E)),
                  _StatChip('K', _avg(_potassium), const Color(0xFF5B21B6)),
                  _StatChip('H₂O', _avg(_moisture), const Color(0xFF0F766E)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${_timestamps.length} readings · ${_timestamps.isNotEmpty ? _shortTs(_timestamps.first) : ""} to ${_timestamps.isNotEmpty ? _shortTs(_timestamps.last) : ""}',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 24),
            ],

            // --- METRICS ---
            const Text(
              'Audit Detail Breakdown',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827)),
            ),
            const SizedBox(height: 16),

            ..._metrics.entries
                .map((entry) => _AuditDetailRow(
                      label: entry.key.toUpperCase(),
                      status: entry.value,
                    )),

            const SizedBox(height: 32),

            // --- EXPORT BUTTON ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _exportPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text(
                  'Export Audit Report (PDF)',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B4332),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Generates a full week-overview report with sensor stats, ML classification, and trend charts.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Flutter helper widgets ────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _StatChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color),
            ),
            const SizedBox(height: 4),
            Text(
              value.toStringAsFixed(1),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditDetailRow extends StatelessWidget {
  final String label;
  final String status;

  const _AuditDetailRow({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final bool isOptimal =
        status.toLowerCase().contains('optimal') ||
        status.toLowerCase().contains('good') ||
        status.toLowerCase().contains('stable');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151)),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isOptimal
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isOptimal
                    ? const Color(0xFF059669)
                    : const Color(0xFFB91C1C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
