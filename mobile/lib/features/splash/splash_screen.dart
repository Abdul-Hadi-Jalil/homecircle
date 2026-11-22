import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';

const _statusSequence = [
  'Syncing household routine...',
  'Updating pantry inventory...',
  'Gathering family calendar...',
  'Welcome back home',
];

/// Animated splash shown while the session restores (UI/splash screen).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 700),
  );
  late final AnimationController _ping = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );
  Timer? _timer;
  int _step = 0;
  double _labelOpacity = 1;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || MediaQuery.of(context).disableAnimations) return;
    _started = true;
    _orbit.repeat();
    _ping.repeat();
    _pulse.repeat(reverse: true);
    _timer = Timer.periodic(const Duration(milliseconds: 2400), (_) async {
      if (!mounted) return;
      setState(() => _labelOpacity = 0);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() {
        _step = (_step + 1) % _statusSequence.length;
        _labelOpacity = 1;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _orbit.dispose();
    _ping.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFF2248D1),
      body: Semantics(
        label: l.bootstrap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1B3BB8),
                    Color(0xFF2248D1),
                    Color(0xFF12246B),
                  ],
                ),
              ),
            ),
            const _Glow(
              top: -96,
              start: -80,
              size: 320,
              color: AppColors.primaryContainer,
              opacity: 0.30,
            ),
            const _Glow(
              topFraction: 1 / 3,
              end: -96,
              size: 320,
              color: AppColors.secondaryContainer,
              opacity: 0.20,
            ),
            const _Glow(
              bottom: -80,
              centered: true,
              size: 384,
              color: Color(0xFF2C50D9),
              opacity: 0.25,
            ),
            Positioned.fill(
              child: ExcludeSemantics(
                child: AnimatedBuilder(
                  animation: _orbit,
                  builder: (context, _) => CustomPaint(
                    painter: _OrbitPainter(_orbit.value),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: _TopPill(),
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: _Center(pulse: _pulse),
                        ),
                      ),
                    ),
                    _Bottom(
                      ping: _ping,
                      label: _statusSequence[_step],
                      opacity: _labelOpacity,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({
    required this.size,
    required this.color,
    required this.opacity,
    this.top,
    this.bottom,
    this.start,
    this.end,
    this.topFraction,
    this.centered = false,
  });
  final double size;
  final Color color;
  final double opacity;
  final double? top, bottom, start, end, topFraction;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final w = MediaQuery.sizeOf(context).width;
    final glow = IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: opacity),
                color.withValues(alpha: opacity * 0.55),
                color.withValues(alpha: 0),
              ],
              stops: const [0, 0.45, 1],
            ),
          ),
        ),
      ),
    );
    return Positioned(
      top: topFraction == null ? top : h * topFraction!,
      bottom: bottom,
      left: centered ? (w - size) / 2 : start,
      right: end,
      child: glow,
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // SVG viewBox 390x844, preserveAspectRatio xMidYMid slice.
    final scale = math.max(size.width / 390, size.height / 844);
    canvas.save();
    canvas.translate(
      (size.width - 390 * scale) / 2,
      (size.height - 844 * scale) / 2,
    );
    canvas.scale(scale);
    const center = Offset(195, 350);
    final rect = const Rect.fromLTWH(0, 0, 390, 844);
    final shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x59FFFFFF),
        Color(0x267FF6BF),
        Color(0x0DDDE1FF),
      ],
      stops: [0, 0.5, 1],
    ).createShader(rect);
    final stroke = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke;

    // Whole SVG is rendered at 35% opacity.
    canvas.saveLayer(rect, Paint()..color = Colors.white.withValues(alpha: 0.35));
    _dashedCircle(canvas, center, 140, 4, 8, 1, stroke, t * 2 * math.pi * (700 / 70));
    _dashedCircle(canvas, center, 190, 2, 12, 1, stroke, -t * 2 * math.pi * (700 / 100));
    final solid = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75;
    canvas.saveLayer(rect, Paint()..color = Colors.white.withValues(alpha: 0.4));
    canvas.drawCircle(center, 240, solid);
    canvas.restore();
    void dot(double x, double y, double r, Color c, double o) =>
        canvas.drawCircle(Offset(x, y), r, Paint()..color = c.withValues(alpha: o));
    dot(95, 250, 3.5, const Color(0xFF7FF6BF), 0.8);
    dot(300, 290, 2.5, const Color(0xFFFFDDB5), 0.7);
    dot(280, 450, 3, const Color(0xFFDDE1FF), 0.85);
    dot(110, 430, 2, Colors.white, 0.6);
    canvas.restore();
    canvas.restore();
  }

  void _dashedCircle(
    Canvas canvas,
    Offset c,
    double r,
    double dash,
    double gap,
    double width,
    Paint paint,
    double rotation,
  ) {
    paint.strokeWidth = width;
    final circumference = 2 * math.pi * r;
    final step = dash + gap;
    final count = (circumference / step).floor();
    final dashAngle = dash / r;
    final stepAngle = 2 * math.pi / count;
    for (var i = 0; i < count; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        rotation + i * stepAngle,
        dashAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.t != t;
}

class _TopPill extends StatelessWidget {
  const _TopPill();
  @override
  Widget build(BuildContext context) => _Glass(
    radius: 999,
    alpha: 0.10,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.secondaryFixed,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'PRIVATE HOUSEHOLD CLOUD',
          style: AppText.labelSm.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
            letterSpacing: 0.44,
            height: 14 / 11,
          ),
        ),
      ],
    ),
  );
}

/// Translucent pill with backdrop blur.
class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    required this.alpha,
    required this.padding,
    required this.radius,
    this.blur = 12,
    this.color = Colors.white,
    this.shadow = false,
  });
  final Widget child;
  final double alpha;
  final EdgeInsets padding;
  final double radius;
  final double blur;
  final Color color;
  final bool shadow;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: shadow
          ? const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ]
          : null,
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          color: color.withValues(alpha: alpha),
          child: child,
        ),
      ),
    ),
  );
}

class _Center extends StatelessWidget {
  const _Center({required this.pulse});
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _AppIcon(pulse: pulse),
      const SizedBox(height: 32),
      Text(
        'HomeCircle',
        textAlign: TextAlign.center,
        style: AppText.bodyMd.copyWith(
          fontSize: 32,
          height: 40 / 32,
          letterSpacing: -0.64,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          shadows: const [
            Shadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
      ),
      const SizedBox(height: 8),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Text(
          'One home. Every detail connected.',
          textAlign: TextAlign.center,
          style: AppText.bodyMd.copyWith(
            color: AppColors.primaryFixed.withValues(alpha: 0.95),
          ),
        ),
      ),
      const SizedBox(height: 24),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: const Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _RoutinePill(
              icon: Icons.checklist,
              color: AppColors.secondaryFixed,
              label: 'Chores',
            ),
            _RoutinePill(
              icon: Icons.kitchen_outlined,
              color: Color(0xFFFFB956),
              label: 'Pantry',
            ),
            _RoutinePill(
              icon: Icons.calendar_today_outlined,
              color: AppColors.primaryFixed,
              label: 'Sync',
            ),
          ],
        ),
      ),
    ],
  );
}

class _RoutinePill extends StatelessWidget {
  const _RoutinePill({
    required this.icon,
    required this.color,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => _Glass(
    radius: 999,
    alpha: 0.10,
    blur: 4,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppText.labelSm.copyWith(
            color: Colors.white.withValues(alpha: 0.9),
            height: 14 / 11,
          ),
        ),
      ],
    ),
  );
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.pulse});
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context).width >= 640 ? 128.0 : 112.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Ambient backdrop bloom.
        Positioned(
          left: -16,
          right: -16,
          top: -16,
          bottom: -16,
          child: AnimatedBuilder(
            animation: pulse,
            builder: (context, child) => Opacity(
              opacity: 0.7 * (1 - 0.5 * Curves.easeInOut.transform(pulse.value)),
              child: child,
            ),
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                    colors: [
                      AppColors.primary,
                      AppColors.secondaryContainer.withValues(alpha: 0.4),
                      const Color(0xFF2C50D9),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Glass outer ring.
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.35),
                Colors.white.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x73001256),
                blurRadius: 50,
                offset: Offset(0, 20),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Container(
              width: size,
              height: size,
              color: AppColors.primary,
              child: Image.asset(
                'assets/images/app_icon.png',
                fit: BoxFit.cover,
                semanticLabel: 'HomeCircle App Icon',
              ),
            ),
          ),
        ),
        // Household members badge.
        PositionedDirectional(
          bottom: -8,
          end: -12,
          child: _Glass(
            radius: 999,
            alpha: 0.8,
            color: const Color(0xFF283041),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MemberStack(),
                SizedBox(width: 6),
                Icon(Icons.home, size: 13, color: Color(0xE6FFFFFF)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberStack extends StatelessWidget {
  const _MemberStack();

  @override
  Widget build(BuildContext context) {
    Widget avatar(String letter, Color bg, Color fg) => Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Text(
        letter,
        style: AppText.labelSm.copyWith(fontSize: 9, color: fg, height: 1),
      ),
    );
    return SizedBox(
      width: 20 + 12 + 12,
      height: 20,
      child: Stack(
        children: [
          avatar('M', AppColors.tertiaryFixed, AppColors.onTertiaryFixed),
          Positioned(
            left: 12,
            child: avatar('L', AppColors.secondaryFixed, const Color(0xFF002113)),
          ),
          Positioned(
            left: 24,
            child: avatar('K', AppColors.primaryFixed, AppColors.onPrimaryFixed),
          ),
        ],
      ),
    );
  }
}

class _Bottom extends StatelessWidget {
  const _Bottom({
    required this.ping,
    required this.label,
    required this.opacity,
  });
  final Animation<double> ping;
  final String label;
  final double opacity;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Glass(
          radius: 999,
          alpha: 0.15,
          shadow: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Dots(ping: ping),
              const SizedBox(width: 10),
              Flexible(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: opacity,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 200),
                    offset: Offset(0, opacity == 1 ? 0 : 2 / 16),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.labelMd.copyWith(
                        color: Colors.white.withValues(alpha: 0.95),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 13,
              color: AppColors.primaryFixed.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'v1.0.0 • End-to-End Encrypted Household',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.labelSm.copyWith(
                  color: AppColors.primaryFixed.withValues(alpha: 0.7),
                  height: 14 / 11,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.ping});
  final Animation<double> ping;

  @override
  Widget build(BuildContext context) {
    Widget dot(double opacity) => Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
    return SizedBox(
      width: 6 * 3 + 6 * 2,
      height: 12,
      child: Stack(
        alignment: Alignment.centerLeft,
        clipBehavior: Clip.none,
        children: [
          // animate-ping: scale 1 -> 2 while fading out, over the first dot.
          AnimatedBuilder(
            animation: ping,
            builder: (context, _) {
              final t = Curves.easeOut.transform(ping.value);
              return Positioned(
                left: 0,
                child: Transform.scale(
                  scale: 1 + t,
                  child: Opacity(opacity: 1 - t, child: dot(1)),
                ),
              );
            },
          ),
          Positioned(left: 0, child: dot(1)),
          Positioned(left: 12, child: dot(0.75)),
          Positioned(left: 24, child: dot(0.5)),
        ],
      ),
    );
  }
}
