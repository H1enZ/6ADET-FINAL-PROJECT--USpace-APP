import 'package:flutter/material.dart';

/// Gently pulses its child, like a heartbeat. Still when the device asks
/// for reduced motion.
class Heartbeat extends StatefulWidget {
  const Heartbeat({super.key, required this.child});

  final Widget child;

  @override
  State<Heartbeat> createState() => _HeartbeatState();
}

class _HeartbeatState extends State<Heartbeat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.18).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}
