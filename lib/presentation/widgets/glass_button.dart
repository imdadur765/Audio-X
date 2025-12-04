import 'package:flutter/material.dart';

class GlassButton extends StatelessWidget {
  final String imagePath;
  final VoidCallback onTap;
  final double size;
  final double containerSize;
  final Color? accentColor;
  final bool isActive;
  final Color iconColor;

  const GlassButton({
    super.key,
    required this.imagePath,
    required this.onTap,
    this.size = 24,
    this.containerSize = 48,
    this.accentColor,
    this.isActive = false,
    this.iconColor = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccentColor = accentColor ?? Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: containerSize,
        height: containerSize,
        decoration: BoxDecoration(
          color: isActive ? effectiveAccentColor.withOpacity(0.2) : Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Image.asset(imagePath, width: size, height: size, color: isActive ? effectiveAccentColor : iconColor),
        ),
      ),
    );
  }
}
