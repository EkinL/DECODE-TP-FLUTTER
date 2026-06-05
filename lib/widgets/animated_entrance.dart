import 'package:flutter/material.dart';
import 'package:motor/motor.dart';

class AnimatedEntrance extends StatelessWidget {
  const AnimatedEntrance({required this.child, this.offsetY = 14, super.key});

  final Widget child;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    return SingleMotionBuilder(
      from: 0,
      value: 1,
      motion: const CupertinoMotion.smooth(),
      builder: (BuildContext context, double t, Widget? child) {
        final double progress = t.clamp(0.0, 1.0);

        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, (1 - progress) * offsetY),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
