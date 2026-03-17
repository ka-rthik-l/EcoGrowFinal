import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _alerts = [];

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
      final data = await ApiService().getAlerts();
      if (!mounted) return;
      setState(() {
        _alerts = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load incident logs.';
        _loading = false;
      });
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return 'Recent';
    try {
      final ts = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(ts);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return timestamp;
    }
  }

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
            Icon(Icons.warning_amber_outlined, size: 48, color: Theme.of(context).colorScheme.error),
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
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _alerts.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Incident Reports',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Automated anomaly detection and system alerts',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                ),
                const SizedBox(height: 32),
              ],
            );
          }
          
          final alert = _alerts[index - 1];
          return _IncidentCard(
            title: alert['title'] ?? 'System Anomaly',
            details: alert['details'] ?? '',
            level: alert['level'] ?? 'info',
            time: _formatTime(alert['timestamp']),
          );
        },
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  final String title;
  final String details;
  final String level;
  final String time;

  const _IncidentCard({
    required this.title,
    required this.details,
    required this.level,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCritical = level.toLowerCase() == 'critical';
    final bool isWarning = level.toLowerCase() == 'warning';
    
    final Color accentColor = isCritical 
        ? const Color(0xFFB91C1C) 
        : (isWarning ? const Color(0xFFD97706) : const Color(0xFF3B82F6));
    
    final Color bgColor = isCritical 
        ? const Color(0xFFFEF2F2) 
        : (isWarning ? const Color(0xFFFFFBEB) : const Color(0xFFEFF6FF));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    isCritical ? Icons.error_outline : (isWarning ? Icons.warning_amber_rounded : Icons.info_outline),
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            level.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            time,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        details,
                        style: const TextStyle(color: Color(0xFF4B5563), fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Text(
                  'Action:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                ),
                const SizedBox(width: 8),
                Text(
                  isCritical ? 'Immediate inspection required' : 'Monitor trend for escalation',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, size: 16, color: Color(0xFFD1D5DB)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
