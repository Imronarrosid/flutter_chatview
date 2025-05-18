import 'package:flutter/material.dart';

class SwipeLeftAnimationWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double swipeDistance;
  final Curve curve;
  final double? childWidth;
  final double? childHeight;

  const SwipeLeftAnimationWidget({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.swipeDistance = 100.0,
    this.curve = Curves.easeInOut,
    this.childWidth,
    this.childHeight,
  }) : super(key: key);

  @override
  State<SwipeLeftAnimationWidget> createState() => _SwipeLeftAnimationWidgetState();
}

class _SwipeLeftAnimationWidgetState extends State<SwipeLeftAnimationWidget> {
  bool _isAtStartPosition = true;
  late double _currentOffset;

  @override
  void initState() {
    super.initState();
    _currentOffset = 0;
    _startAnimation();
  }

  void _startAnimation() {
    Future.delayed(widget.duration, () {
      if (!mounted) return;

      setState(() {
        _isAtStartPosition = !_isAtStartPosition;
        _currentOffset = _isAtStartPosition ? 0 : -widget.swipeDistance;
      });

      _startAnimation();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: widget.duration,
      curve: widget.curve,
      width: widget.childWidth,
      height: widget.childHeight,
      transform: Matrix4.translationValues(_currentOffset, 0, 0),
      child: widget.child,
    );
  }
}
