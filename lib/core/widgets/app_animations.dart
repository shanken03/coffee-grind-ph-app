import 'package:flutter/material.dart';

/// Shared motion tokens and accessibility-aware helpers for Coffee Grind PH.
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 140);
  static const Duration standard = Duration(milliseconds: 300);
  static const Duration entrance = Duration(milliseconds: 460);
  static const Duration slow = Duration(milliseconds: 600);
  static const Curve defaultCurve = Curves.easeOutCubic;

  static bool reduceMotion(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  static Duration resolveDuration(BuildContext context, Duration desired) {
    return reduceMotion(context) ? Duration.zero : desired;
  }
}

/// Finite entrance animation combining fade, slide offset, and subtle scale.
/// Supports staggered reveal via [startInterval] (0.0 .. < 1.0).
class AppFadeSlideScale extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Offset beginOffset;
  final double beginScale;
  final double startInterval;
  final Curve curve;

  const AppFadeSlideScale({
    super.key,
    required this.child,
    this.duration = AppMotion.entrance,
    this.beginOffset = const Offset(0, 20),
    this.beginScale = 0.96,
    this.startInterval = 0.0,
    this.curve = AppMotion.defaultCurve,
  });

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) {
      return child;
    }

    final safeStart = startInterval.clamp(0.0, 0.9);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: duration,
      curve: Curves.linear,
      builder: (context, rawValue, animatedChild) {
        final double normalized = safeStart <= 0.0
            ? rawValue
            : ((rawValue - safeStart) / (1.0 - safeStart)).clamp(0.0, 1.0);
        final double t = curve.transform(normalized);
        final double currentScale = beginScale + ((1.0 - beginScale) * t);

        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(
              beginOffset.dx * (1.0 - t),
              beginOffset.dy * (1.0 - t),
            ),
            child: Transform.scale(
              scale: currentScale,
              child: animatedChild,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// Tactile press-down scale feedback that never blocks child tap/InkWell handlers.
class AppPressableScale extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final double pressedScale;

  const AppPressableScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = 0.96,
  });

  @override
  State<AppPressableScale> createState() => _AppPressableScaleState();
}

class _AppPressableScaleState extends State<AppPressableScale> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled && value) return;
    if (_isPressed != value && mounted) {
      setState(() => _isPressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = AppMotion.reduceMotion(context);
    if (reduce) return widget.child;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: (_isPressed && widget.enabled) ? widget.pressedScale : 1.0,
        duration: AppMotion.fast,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Finite bounce animation triggered whenever [triggerValue] increases.
class AppAnimatedBounce extends StatefulWidget {
  final int triggerValue;
  final Widget child;
  final double peakScale;

  const AppAnimatedBounce({
    super.key,
    required this.triggerValue,
    required this.child,
    this.peakScale = 1.22,
  });

  @override
  State<AppAnimatedBounce> createState() => _AppAnimatedBounceState();
}

class _AppAnimatedBounceState extends State<AppAnimatedBounce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: widget.peakScale,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: widget.peakScale,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 55,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant AppAnimatedBounce oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.triggerValue > oldWidget.triggerValue &&
        !AppMotion.reduceMotion(context)) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) {
      return widget.child;
    }
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );
  }
}

/// Animated linear progress bar interpolating smoothly toward [value].
class AppAnimatedProgressBar extends StatelessWidget {
  final double value;
  final double minHeight;
  final Color backgroundColor;
  final Color valueColor;
  final Duration duration;

  const AppAnimatedProgressBar({
    super.key,
    required this.value,
    this.minHeight = 10,
    required this.backgroundColor,
    required this.valueColor,
    this.duration = const Duration(milliseconds: 650),
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0.0, 1.0);
    if (AppMotion.reduceMotion(context)) {
      return LinearProgressIndicator(
        value: safeValue,
        minHeight: minHeight,
        backgroundColor: backgroundColor,
        valueColor: AlwaysStoppedAnimation<Color>(valueColor),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: safeValue),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return LinearProgressIndicator(
          value: animatedValue,
          minHeight: minHeight,
          backgroundColor: backgroundColor,
          valueColor: AlwaysStoppedAnimation<Color>(valueColor),
        );
      },
    );
  }
}

/// Checkout confirmation badge with pop-in scale animation.
class AppCheckoutSuccessCheckmark extends StatelessWidget {
  final Widget child;
  final Duration duration;

  const AppCheckoutSuccessCheckmark({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 520),
  });

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: duration,
      curve: Curves.easeOutBack,
      builder: (context, t, animatedChild) {
        final safeOpacity = t.clamp(0.0, 1.0);
        return Opacity(
          opacity: safeOpacity,
          child: Transform.scale(
            scale: 0.55 + (0.45 * t),
            child: animatedChild,
          ),
        );
      },
      child: child,
    );
  }
}
