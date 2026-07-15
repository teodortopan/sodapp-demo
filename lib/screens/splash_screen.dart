import 'dart:math';
import 'package:flutter/material.dart';
import '../demo/demo_data_seed.dart';
import '../utils/app_tokens.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _progressController;
  late final AnimationController _bounceController;
  late final AnimationController _tickController;
  late final Animation<double> _bounceAnim;
  bool _navigated = false;
  double _loadProgress = 0.0;
  bool _loadDone = false;

  // Exhaust particles
  final List<_ExhaustParticle> _particles = [];
  final _random = Random();

  @override
  void initState() {
    super.initState();
    // F3: diagnostic — this fires every time the splash screen mounts.
    // Should only appear once per cold start. If it appears mid-session
    // (after a sodero switched away and came back), the process restarted
    // and the resume bug is back.
    debugPrint('[Splash] initState — first frame');

    // Progress bar animation (smooth fill)
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Bumpy bounce
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..repeat(reverse: true);

    _bounceAnim = Tween<double>(begin: 0, end: -3).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    // Tick for exhaust particles (~60fps)
    _tickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..repeat();
    _tickController.addListener(_updateParticles);

    _initAndNavigate();
  }

  void _updateParticles() {
    if (!mounted) return;
    setState(() {
      // Spawn exhaust from behind the truck
      if (_random.nextDouble() < 0.5) {
        _particles.add(
          _ExhaustParticle(
            x: 0,
            y: _random.nextDouble() * 4 - 2,
            vx: -(_random.nextDouble() * 1.5 + 1.0),
            vy: -(_random.nextDouble() * 0.8 + 0.3),
            size: _random.nextDouble() * 4 + 2,
            opacity: 0.5 + _random.nextDouble() * 0.3,
            life: 1.0,
          ),
        );
      }

      for (final p in _particles) {
        p.x += p.vx;
        p.y += p.vy;
        p.life -= 0.03;
        p.opacity = (p.life * 0.5).clamp(0, 1);
        p.size += 0.2;
      }

      _particles.removeWhere((p) => p.life <= 0);
    });
  }

  Future<void> _initAndNavigate() async {
    _progressController.forward();
    _setProgress(0.3);
    await seedDemoData();
    _setProgress(1.0);
    _loadDone = true;
    await Future.delayed(const Duration(milliseconds: 500));
    if (!_progressController.isCompleted) {
      await _progressController.forward().orCancel.catchError((_) {});
    }
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted && !_navigated) {
      _navigated = true;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(),
          transitionsBuilder: (context, anim, secondaryAnimation, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  void _setProgress(double value) {
    if (mounted) {
      setState(() => _loadProgress = value);
    }
  }

  @override
  void dispose() {
    _tickController.removeListener(_updateParticles);
    _progressController.dispose();
    _bounceController.dispose();
    _tickController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final isDark = tokens.isDark;
    final screenWidth = MediaQuery.of(context).size.width;
    final roadWidth = screenWidth * 0.75;
    // Truck position along the road based on progress
    final truckProgress = _loadDone
        ? _loadProgress
        : _progressController.value.clamp(0.0, _loadProgress);
    final truckX = truckProgress * (roadWidth - 50);

    // Exhaust smoke is a real-world gray that adapts to theme: lighter
    // on dark bg, mid-gray on light bg. Either way it stays a visible
    // soft puff trailing the truck.
    final exhaustColor = isDark ? Colors.white : tokens.textSub;

    return Scaffold(
      backgroundColor: tokens.bg,
      body: Stack(
        children: [
          // Subtle radial glow centered behind the wordmark. Brand-tinted
          // (heroBlue) but very low opacity so it reads as ambient depth,
          // not a graphic element. Skipped on light mode where the
          // existing soft surface already has enough hierarchy.
          if (isDark)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.35),
                      radius: 0.9,
                      colors: [
                        tokens.heroBlue.withValues(alpha: 0.12),
                        tokens.bg.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Wordmark — larger, tighter, theme-aware.
                Text(
                  'SODAPP',
                  style: TextStyle(
                    color: tokens.text,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 44),
                // Truck + road area
                SizedBox(
                  width: roadWidth,
                  height: 80,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Road background (faint hairline track).
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : tokens.text.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Road progress (filled portion, the loading bar)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: AnimatedBuilder(
                          animation: _progressController,
                          builder: (context, child) {
                            final w = truckProgress * roadWidth;
                            return Container(
                              height: 4,
                              width: w.clamp(0, roadWidth),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                gradient: LinearGradient(
                                  colors: [
                                    tokens.heroBlueDeeper,
                                    tokens.heroBlue,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: tokens.heroBlue.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 6,
                                    offset: const Offset(0, 0),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      // Exhaust particles (positioned relative to truck)
                      ..._particles.map((p) {
                        return Positioned(
                          left: truckX + 5 + p.x,
                          bottom: 8 + 12 - p.y,
                          child: Container(
                            width: p.size,
                            height: p.size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: exhaustColor.withValues(
                                alpha: p.opacity * (isDark ? 0.3 : 0.22),
                              ),
                            ),
                          ),
                        );
                      }),
                      // Truck icon (bouncing, driving along road)
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          _bounceAnim,
                          _progressController,
                        ]),
                        builder: (_, child) {
                          return Positioned(
                            left: truckX,
                            bottom: 6 + _bounceAnim.value.abs(),
                            child: child!,
                          );
                        },
                        child: Image.asset(
                          'assets/app_icon.png',
                          width: 50,
                          height: 50,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Cargando label with subtle animated dot count for
                // life — same character width regardless of which dot
                // count is shown (we pad with non-breaking spaces).
                _LoadingLabel(controller: _bounceController, tokens: tokens),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Cargando" with 0–3 trailing dots that cycle while the bounce
/// controller does its repeat — reuses an existing ticker rather than
/// spinning up another animator. Padded with thin spaces so the layout
/// never reflows as dot count changes.
class _LoadingLabel extends StatelessWidget {
  final AnimationController controller;
  final AppTokens tokens;
  const _LoadingLabel({required this.controller, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // controller cycles 0..1..0..1 every 500ms; map to 0..3 dots.
        final phase = (DateTime.now().millisecondsSinceEpoch ~/ 350) % 4;
        final dots = '.' * phase;
        final padding = ' ' * (3 - phase);
        return Text(
          'Cargando$dots$padding',
          style: TextStyle(
            color: tokens.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        );
      },
    );
  }
}

class _ExhaustParticle {
  double x, y, vx, vy, size, opacity, life;
  _ExhaustParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.opacity,
    required this.life,
  });
}
