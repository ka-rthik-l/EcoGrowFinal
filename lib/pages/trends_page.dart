import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../services/api_service.dart';
import '../widgets/leaf_loader.dart';

class TrendsPage extends StatefulWidget {
  const TrendsPage({super.key});

  @override
  State<TrendsPage> createState() => _TrendsPageState();
}

class _TrendsPageState extends State<TrendsPage> {
  String selectedRange = 'Last Week';

  bool _loading = true;
  String? _error;

  List<double> nitrogenData = [];
  List<double> phosphorusData = [];
  List<double> potassiumData = [];
  List<double> moistureData = [];
  List<String> timestamps = [];

  static const Map<String, String> _rangeMap = {
    'Last Hour': 'hour',
    'Last Day': 'day',
    'Last Week': 'week',
  };

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
      final range = _rangeMap[selectedRange] ?? 'week';
      final data = await ApiService().getTrends(range);
      if (!mounted) return;
      setState(() {
        nitrogenData = List<double>.from(
          (data['nitrogen'] as List).map((e) => (e as num).toDouble()),
        );
        phosphorusData = List<double>.from(
          (data['phosphorus'] as List).map((e) => (e as num).toDouble()),
        );
        potassiumData = List<double>.from(
          (data['potassium'] as List).map((e) => (e as num).toDouble()),
        );
        moistureData = List<double>.from(
          (data['moisture'] as List).map((e) => (e as num).toDouble()),
        );
        timestamps = List<String>.from(data['timestamps'] as List);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load historical trends.';
        _loading = false;
      });
    }
  }

  String _getXAxisLabel(double value) {
    int index = value.toInt();
    if (index < 0 || index >= timestamps.length) return '';
    
    // Only show a few labels to avoid crowding
    int interval = (timestamps.length / 5).ceil();
    if (interval == 0) interval = 1;
    if (index % interval != 0) return '';

    try {
      final dt = DateTime.parse(timestamps[index]).toLocal();
      if (selectedRange == 'Last Hour') {
        return '${dt.minute}m';
      } else if (selectedRange == 'Last Day') {
        return '${dt.hour}:00';
      } else {
        return '${dt.day}/${dt.month}';
      }
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LeafLoader(message: 'Analyzing trends...');
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline_outlined, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Color(0xFF374151))),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry Connection'),
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
              'Audit Telemetry Trends',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Historical sensor data analysis over 48 hours',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
            const SizedBox(height: 24),
            
            _timeFilters(),
            
            const SizedBox(height: 32),
            
            if (nitrogenData.isNotEmpty) ...[
               const Text(
                'Nitrogen Levels (N)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 16),
              _chartCard(
                color: const Color(0xFF1B4332),
                data: nitrogenData,
                spikeThreshold: 80,
              ),
            ],
            
            const SizedBox(height: 32),
            
            if (phosphorusData.isNotEmpty) ...[
              const Text(
                'Phosphorus Levels (P)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 16),
              _chartCard(
                color: const Color(0xFF059669),
                data: phosphorusData,
                spikeThreshold: 60,
              ),
            ],

            const SizedBox(height: 32),
            
            if (potassiumData.isNotEmpty) ...[
              const Text(
                'Potassium Levels (K)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 16),
              _chartCard(
                color: const Color(0xFF2D6A4F),
                data: potassiumData,
                spikeThreshold: 90,
              ),
            ],

            const SizedBox(height: 32),
            
            if (moistureData.isNotEmpty) ...[
              const Text(
                'Moisture Levels (%)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 16),
              _chartCard(
                color: const Color(0xFF3B82F6),
                data: moistureData,
                spikeThreshold: 100, // No spike threshold for moisture usually
              ),
            ],
            
            const SizedBox(height: 32),
            _alertSummary(),
          ],
        ),
      ),
    );
  }

  Widget _chartCard({
    required Color color,
    required List<double> data,
    required double spikeThreshold,
  }) {
    // Dynamic limits logic (kept from previous fix)
    double maxVal = data.isEmpty ? 100 : data.reduce(math.max);
    double maxY = (maxVal * 1.1).ceilToDouble();
    if (maxY - maxVal < 5) maxY = maxVal + 10;
    if (spikeThreshold >= 100 && maxY < 105) maxY = 105;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 32, 24, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(
                color: const Color(0xFFF3F4F6),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) => Text(
                    value.toInt().toString(),
                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval: (timestamps.length / 5).ceil().toDouble() == 0 ? 1 : (timestamps.length / 5).ceil().toDouble(),
                  getTitlesWidget: (value, meta) => Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _getXAxisLabel(value),
                      style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: List.generate(
                  data.length,
                  (index) => FlSpot(index.toDouble(), data[index]),
                ),
                isCurved: true,
                color: color,
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) {
                    final bool isSpike = data[index] > spikeThreshold;
                    return FlDotCirclePainter(
                      radius: isSpike ? 4 : 2,
                      color: isSpike ? const Color(0xFFEF4444) : color,
                      strokeWidth: 0,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: color.withOpacity(0.05),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeFilters() {
    final ranges = ['Last Hour', 'Last Day', 'Last Week'];

    return Row(
      children: ranges.map((range) {
        final bool isSelected = selectedRange == range;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            onTap: () {
              setState(() => selectedRange = range);
              _loadData();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1B4332) : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? const Color(0xFF1B4332) : const Color(0xFFD1D5DB),
                ),
              ),
              child: Text(
                range,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF4B5563),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _alertSummary() {
    int criticalCount = 0;
    for (final v in nitrogenData) if (v > 80) criticalCount++;
    for (final v in phosphorusData) if (v > 60) criticalCount++;
    for (final v in potassiumData) if (v > 90) criticalCount++;
    for (final v in moistureData) if (v > 95) criticalCount++;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(
            criticalCount > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            color: criticalCount > 0 ? const Color(0xFFB91C1C) : const Color(0xFF059669),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trend Observation',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
                const SizedBox(height: 4),
                Text(
                  criticalCount > 0
                      ? 'Analysis detected $criticalCount anomalies in the selected period.'
                      : 'No critical anomalies detected in current telemetry window.',
                  style: const TextStyle(color: Color(0xFF4B5563), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
