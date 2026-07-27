import 'dart:async';

import 'package:flutter/material.dart';

/// Wraps a single list item to provide a staggered slide-up + fade-in
/// entry animation based on its [index] in the list.
///
/// Items animate in sequentially with [delayPerItem] between each one,
/// creating a cascading "waterfall" effect.
class StaggeredListItem extends StatefulWidget {
  const StaggeredListItem({
    required this.index,
    required this.child,
    this.delayPerItem = const Duration(milliseconds: 50),
    this.duration = const Duration(milliseconds: 400),
    this.verticalOffset = 30.0,
    super.key,
  });

  final int index;
  final Widget child;
  final Duration delayPerItem;
  final Duration duration;
  final double verticalOffset;

  @override
  State<StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;
  Timer? _delayTimer;
  bool _hasPlayed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion || _hasPlayed) {
      _delayTimer?.cancel();
      _delayTimer = null;
      _controller?.dispose();
      _controller = null;
      return;
    }

    if (_controller != null) {
      return;
    }

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller!,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, widget.verticalOffset),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller!, curve: Curves.easeOutCubic),
    );

    // Schedule the delayed start
    final delay = widget.delayPerItem * widget.index;
    _delayTimer?.cancel();
    if (delay == Duration.zero) {
      if (mounted && _controller != null) {
        _controller!.forward().then((_) {
          _hasPlayed = true;
        });
      }
    } else {
      _delayTimer = Timer(delay, () {
        if (mounted && _controller != null) {
          _controller!.forward().then((_) {
            _hasPlayed = true;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _delayTimer = null;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || _hasPlayed) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: controller,
      child: widget.child,
      builder: (context, child) {
        return Transform.translate(
          offset: _slideAnimation!.value,
          child: Opacity(
            opacity: _fadeAnimation!.value,
            child: child,
          ),
        );
      },
    );
  }
}
