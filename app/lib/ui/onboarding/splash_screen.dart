import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../themes/icon_painter.dart';
import '../hud.dart';

/// Launch screen: logo over drifting, glowing POI glyphs on a blue glow.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..forward();

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final glyphs = poiGlyphs.values.take(14).toList();
    return Scaffold(
      backgroundColor: const Color(0xFF050814),
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = reduceMotion ? 1.0 : Curves.easeOutCubic.transform(_c.value);
          return Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0xFF1E4FD8), Color(0xFF0A1A4A), Color(0xFF050814)],
                    stops: [0, 0.45, 1],
                    radius: 0.9,
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (context, box) => Stack(
                  children: [
                    for (var i = 0; i < glyphs.length; i++)
                      Positioned(
                        left: (box.maxWidth * ((i * 0.37) % 1)) - 24,
                        top: box.maxHeight * ((i * 0.61 + 0.05) % 1) - 24 - 30 * t,
                        child: Opacity(
                          opacity: (0.18 + 0.2 * ((i % 3) / 2)) * t,
                          child: Transform.rotate(
                            angle: (i.isEven ? 1 : -1) * 0.25 * math.pi * 0.2,
                            child: Icon(glyphs[i], size: 48 + (i % 3) * 10, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Center(
                child: Opacity(
                  opacity: t,
                  child: Transform.scale(
                    scale: 0.9 + 0.1 * t,
                    child: Semantics(
                      header: true,
                      label: 'Overworld',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            child: Image.asset('assets/icons/default.png', width: 112, height: 112),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'OVERWORLD',
                            style: const TextStyle(
                              fontFamily: displayFont,
                              fontWeight: FontWeight.w700,
                              fontSize: 38,
                              color: Colors.white,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
