import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';

class GlassBackground extends StatelessWidget {
  final String? artworkPath;
  final Widget? customChild;
  final Color accentColor;
  final bool isDark;

  const GlassBackground({
    super.key,
    required this.artworkPath,
    this.customChild,
    this.accentColor = const Color(0xFF9B51E0),
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Base Image Layer
        if (customChild != null)
          Positioned.fill(child: customChild!)
        else if (artworkPath != null)
          if (File(artworkPath!).existsSync())
            Positioned.fill(
              child: Image.file(File(artworkPath!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildFallback()),
            )
          else
            Positioned.fill(child: _buildFallback())
        else
          Positioned.fill(child: _buildFallback()),

        // 2. Gradient Overlay (Darkens/Lightens for text legibility)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.6),
                  isDark ? Colors.black.withOpacity(0.9) : Colors.white.withOpacity(0.9),
                ],
              ),
            ),
          ),
        ),

        // 3. Blur Effect (The "Glass" look)
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }

  Widget _buildFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A0B2E), // Deep Dark Purple
            Colors.black,
            const Color(0xFF0D1117), // Deep Dark Blue-Grey
          ],
        ),
      ),
    );
  }
}
