import 'package:flutter/material.dart';
import '../config/theme.dart';

class FcLoading extends StatelessWidget {
  final String? message;
  const FcLoading({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.primary,
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.secondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class FcShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const FcShimmer({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = 6,
  });

  @override
  State<FcShimmer> createState() => _FcShimmerState();
}

class _FcShimmerState extends State<FcShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: const [0.0, 0.5, 1.0],
            colors: const [
              Color(0xFFE8E8E8),
              Color(0xFFF5F5F5),
              Color(0xFFE8E8E8),
            ],
            transform: _SlideTransform(_anim.value),
          ),
        ),
      ),
    );
  }
}

class _SlideTransform extends GradientTransform {
  final double slide;
  const _SlideTransform(this.slide);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slide, 0, 0);
  }
}
