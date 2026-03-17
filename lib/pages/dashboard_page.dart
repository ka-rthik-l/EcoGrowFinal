import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../widgets/leaf_loader.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loading = true;
  String? _error;

  // Sensor data
  double _nitrogen = 0;
  double _phosphorus = 0;
  double _potassium = 0;
  double _moisture = 0;
  String _timestamp = '';

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _loadData(isBackground: true);
    });
  }

  Future<void> _loadData({bool isBackground = false}) async {
    if (!isBackground) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final data = await ApiService().getDashboard();
      if (!mounted) return;
      setState(() {
        _nitrogen = (data['nitrogen'] as num).toDouble();
        _phosphorus = (data['phosphorus'] as num).toDouble();
        _potassium = (data['potassium'] as num).toDouble();
        _moisture = (data['moisture'] as num).toDouble();
        _timestamp = data['timestamp'] ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load telemetry data.';
        _loading = false;
      });
    }
  }

  String _timeAgo() {
    if (_timestamp.isEmpty) return 'No data';
    try {
      final ts = DateTime.parse(_timestamp);
      final diff = DateTime.now().difference(ts);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return _timestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LeafLoader(message: 'Syncing telemetry...');
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 16),
            _statusCard(),
            const SizedBox(height: 24),
            _buildChart(),
            const SizedBox(height: 24),
            const Text(
              'Soil Nutrient Analysis',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            const SizedBox(height: 12),
            _soilGrid(),
            const SizedBox(height: 24),
            _summaryCard(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Auditor Dashboard',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Real-time NPK and moisture monitoring',
          style: TextStyle(color: const Color(0xFF6B7280), fontSize: 14),
        ),
      ],
    );
  }

  Widget _statusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.sensors, color: Color(0xFF059669), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audit Status',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                ),
                Text(
                  'Compliance Verified',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Last Sync',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
              ),
              Text(
                _timeAgo(),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF374151)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Chart with dynamic Y-axis limits ---
  Widget _buildChart() {
    final values = [_nitrogen, _phosphorus, _potassium, _moisture];
    final labels = ['N', 'P', 'K', 'M'];
    final colors = const [
      Color(0xFF1B4332),
      Color(0xFF059669),
      Color(0xFF2D6A4F),
      Color(0xFF3B82F6),
    ];

    // Calculate dynamic Y-axis limit
    double maxVal = values.reduce(math.max);
    // Base value is 100, only increase if values exceed it
    double dynamicMaxY = math.max(100.0, (maxVal * 1.1).ceilToDouble());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Sensor Readings',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: dynamicMaxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${labels[group.x]}\n${rod.toY.toStringAsFixed(1)}',
                        const TextStyle(color: Colors.white),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()}', style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < labels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              labels[value.toInt()],
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  // Adjust interval dynamically if needed, but 20 is a good default
                  horizontalInterval: dynamicMaxY / 5, 
                  getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xFFE5E7EB), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(4, (index) {
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: values[index],
                        width: 20,
                        borderRadius: BorderRadius.circular(4),
                        color: colors[index],
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: List.generate(4, (index) => _buildLegendItem(labels[index], colors[index])),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
      ],
    );
  }

  String _getNutrientStatus(double value, String type) {
    if (type == 'N') {
      if (value < 30) return 'LOW';
      if (value > 70) return 'HIGH';
      return 'OPTIMAL';
    } else if (type == 'P') {
      if (value < 20) return 'LOW';
      if (value > 50) return 'HIGH';
      return 'OPTIMAL';
    } else if (type == 'K') {
      if (value < 40) return 'LOW';
      if (value > 80) return 'HIGH';
      return 'OPTIMAL';
    } else {
      // Moisture
      if (value < 30) return 'DRY';
      if (value > 70) return 'WET';
      return 'STABLE';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'OPTIMAL':
      case 'STABLE':
        return const Color(0xFF059669);
      case 'HIGH':
      case 'WET':
        return const Color(0xFFD97706);
      case 'LOW':
      case 'DRY':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Widget _soilGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.9,
      children: [
        _MetricCard(
          title: 'Nitrogen (N)',
          value: '${_nitrogen.toStringAsFixed(1)} mg/kg',
          status: _getNutrientStatus(_nitrogen, 'N'),
          statusColor: _getStatusColor(_getNutrientStatus(_nitrogen, 'N')),
          targetRange: '30-70',
          icon: Icons.science_outlined,
          color: const Color(0xFF1B4332),
        ),
        _MetricCard(
          title: 'Phosphorus (P)',
          value: '${_phosphorus.toStringAsFixed(1)} mg/kg',
          status: _getNutrientStatus(_phosphorus, 'P'),
          statusColor: _getStatusColor(_getNutrientStatus(_phosphorus, 'P')),
          targetRange: '20-50',
          icon: Icons.science_outlined,
          color: const Color(0xFF059669),
        ),
        _MetricCard(
          title: 'Potassium (K)',
          value: '${_potassium.toStringAsFixed(1)} mg/kg',
          status: _getNutrientStatus(_potassium, 'K'),
          statusColor: _getStatusColor(_getNutrientStatus(_potassium, 'K')),
          targetRange: '40-80',
          icon: Icons.science_outlined,
          color: const Color(0xFF2D6A4F),
        ),
        _MetricCard(
          title: 'Moisture',
          value: '${_moisture.toStringAsFixed(1)}%',
          status: _getNutrientStatus(_moisture, 'M'),
          statusColor: _getStatusColor(_getNutrientStatus(_moisture, 'M')),
          targetRange: '30-70',
          icon: Icons.water_drop_outlined,
          color: const Color(0xFF3B82F6),
        ),
      ],
    );
  }

  Widget _summaryCard() {
    String observation = 'Telemetry parameters are within established safety thresholds.';
    String recommendation = 'Continue standard irrigation and monitoring protocols.';

    if (_moisture < 30) {
      observation = 'Critical soil dehydration detected in active root zones.';
      recommendation = 'Initiate immediate irrigation sequence. Check soil texture for drainage issues.';
    } else if (_nitrogen > 70 || _phosphorus > 50 || _potassium > 80) {
      observation = 'Nutrient saturation detected. Possible chemical runoff risk.';
      recommendation = 'Cease fertilizer application. Monitor for salt accumulation/crust formation.';
    } else if (_nitrogen < 30 && _phosphorus < 20) {
      observation = 'Low primary nutrient density detected. Soil depletion risk.';
      recommendation = 'Schedule organic enrichment. Soil requires nitrogen fixation boost.';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF9FAFB), Color(0xFFF3F4F6)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.analytics_rounded,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Auditor Intelligence Report',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _insightRow('Current Observation', observation, Icons.visibility_outlined),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(color: Color(0xFFE5E7EB), height: 1),
          ),
          _insightRow('Official Recommendation', recommendation, Icons.lightbulb_outline_rounded),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_user_outlined, color: Color(0xFF059669), size: 16),
                SizedBox(width: 8),
                Text(
                  'COMPLIANCE GRADE: A',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF059669),
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightRow(String title, String content, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6B7280)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF9CA3AF),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: const TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String status;
  final Color statusColor;
  final String targetRange;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.status,
    required this.statusColor,
    required this.targetRange,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 8),
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.65,
              child: Container(
                decoration: BoxDecoration(
                  color: color.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TARGET', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF))),
              Text(targetRange, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
            ],
          ),
        ],
      ),
    );
  }
}
