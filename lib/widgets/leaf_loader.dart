import 'package:flutter/material.dart';

class LeafLoader extends StatefulWidget {
  final String message;
  const LeafLoader({super.key, this.message = 'Loading data...'});

  @override
  State<LeafLoader> createState() => _LeafLoaderState();
}

class _LeafLoaderState extends State<LeafLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.rotate(
                angle: (_animation.value - 0.5) * 0.5, // Subtle rocking
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B4332).withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.eco_rounded, // The "leaf" icon
                    size: 60,
                    color: const Color(0xFF1B4332).withOpacity(0.2 + (_animation.value * 0.8)), // Pulsing color
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            widget.message,
            style: const TextStyle(
              color: Color(0xFF1B4332),
              fontWeight: FontWeight.w600,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          const SizedBox(
            width: 40,
            child: LinearProgressIndicator(
              backgroundColor: Color(0xFFE5E7EB),
              color: Color(0xFF1B4332),
              minHeight: 2,
            ),
          ),
        ],
      ),
    );
  }
}
