import 'package:flutter/material.dart';

class ScaleTransitionWrapper extends StatefulWidget {
  /// The child widget to apply the scale transition to
  final Widget child;

  /// Duration for the scale animation
  final Duration duration;

  /// The curve to use for the scale animation
  final Curve curve;

  /// The alignment to use for the scale origin
  final Alignment alignment;

  /// The starting scale value (0.0 to 1.0)
  final double beginScale;

  /// The ending scale value
  final double endScale;

  /// Whether to automatically start the animation when inserted into the tree
  final bool autoStart;

  /// Whether to repeat the animation
  final bool repeat;

  /// Whether to reverse the animation when it completes
  final bool reverse;

  const ScaleTransitionWrapper({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
    this.alignment = Alignment.center,
    this.beginScale = 0.0,
    this.endScale = 1.0,
    this.autoStart = true,
    this.repeat = false,
    this.reverse = false,
  }) : super(key: key);

  @override
  State<ScaleTransitionWrapper> createState() => _ScaleTransitionWrapperState();
}

class _ScaleTransitionWrapperState extends State<ScaleTransitionWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animation = Tween<double>(
      begin: widget.beginScale,
      end: widget.endScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    if (widget.autoStart) {
      if (widget.repeat) {
        if (widget.reverse) {
          _controller.repeat(reverse: true);
        } else {
          _controller.repeat();
        }
      } else if (widget.reverse) {
        _controller.forward().then((_) => _controller.reverse());
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void didUpdateWidget(ScaleTransitionWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update animation properties if they changed
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }

    if (oldWidget.beginScale != widget.beginScale || oldWidget.endScale != widget.endScale) {
      _animation = Tween<double>(
        begin: widget.beginScale,
        end: widget.endScale,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Public method to start the animation
  void forward() {
    _controller.forward();
  }

  /// Public method to reverse the animation
  void reverse() {
    _controller.reverse();
  }

  /// Public method to stop the animation
  void stop() {
    _controller.stop();
  }

  /// Public method to reset the animation
  void reset() {
    _controller.reset();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      alignment: widget.alignment,
      child: widget.child,
    );
  }
}
