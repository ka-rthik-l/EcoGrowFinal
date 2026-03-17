import 'package:flutter/material.dart';

import 'pages/dashboard_page.dart';
import 'pages/trends_page.dart';
import 'pages/analysis_page.dart';
import 'pages/alerts_page.dart';
import 'pages/login_page.dart';
import 'services/api_service.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _notificationsMuted = false;

  final List<Widget> _pages = const [
    DashboardPage(),
    TrendsPage(),
    AnalysisPage(),
    AlertsPage(),
  ];

  Future<void> _logout() async {
    await ApiService().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  void _toggleNotifications() {
    setState(() {
      _notificationsMuted = !_notificationsMuted;
    });
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _notificationsMuted 
            ? 'Notifications muted for this session' 
            : 'Notifications activated',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: _notificationsMuted ? const Color(0xFF374151) : const Color(0xFF1B4332),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 24,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.eco_rounded,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EcoGrow',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const Text(
                  'Auditor Portal',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _notificationsMuted 
                ? Icons.notifications_off_rounded 
                : Icons.notifications_active_rounded, 
              color: _notificationsMuted ? const Color(0xFF9CA3AF) : const Color(0xFF059669),
              size: 22,
            ),
            tooltip: _notificationsMuted ? 'Unmute Notifications' : 'Mute Notifications',
            onPressed: _toggleNotifications,
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: Color(0xFF6B7280)),
            tooltip: 'End Session',
            onPressed: _logout,
          ),
          const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFFE5E7EB),
            height: 1.0,
          ),
        ),
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFFE5E7EB), width: 1.0),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: const Color(0xFF9CA3AF),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded, size: 22),
              activeIcon: Icon(Icons.grid_view_rounded, size: 22),
              label: 'TELEMETRY',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.stacked_line_chart_rounded, size: 22),
              label: 'TRENDS',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_turned_in_outlined, size: 22),
              activeIcon: Icon(Icons.assignment_turned_in_rounded, size: 22),
              label: 'AUDIT',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.emergency_outlined, size: 22),
              activeIcon: Icon(Icons.emergency_rounded, size: 22),
              label: 'INCIDENTS',
            ),
          ],
        ),
      ),
    );
  }
}
