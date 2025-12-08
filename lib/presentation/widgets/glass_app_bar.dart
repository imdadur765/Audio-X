import 'dart:ui';
import 'package:flutter/material.dart';

class GlassAppBar extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final double height;
  final double blurSigma;

  const GlassAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.height = kToolbarHeight,
    this.blurSigma = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          color: Colors.black.withOpacity(0.2), // Semi-transparent based on dark mode pref
          alignment: Alignment.center,
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          height: height + MediaQuery.of(context).padding.top,
          child: NavigationToolbar(
            leading: leading,
            middle: Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            trailing: actions != null ? Row(mainAxisSize: MainAxisSize.min, children: actions!) : null,
          ),
        ),
      ),
    );
  }
}
