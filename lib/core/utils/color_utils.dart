import 'package:flutter/material.dart';

class ColorUtils {
  /// Determines if a color is dark based on luminance.
  /// Returns true if the color is dark (luminance < 0.5), false otherwise.
  static bool isDark(Color color) {
    return color.computeLuminance() < 0.5;
  }

  /// Calculates the appropriate text color (black or white) based on the background color's luminance.
  /// If the background is dark, returns white text. If light, returns black text.
  static Color getContrastText(Color backgroundColor) {
    return isDark(backgroundColor) ? Colors.white : Colors.black;
  }

  /// Calculates the appropriate start/end colors for a gradient or overlay based on the accent color.
  /// Returns a record satisfying the user's requirement:
  /// - Bright accent: Light blurred background + Black text
  /// - Dark accent: Force light mode overlay + White text (Wait, user said "Force light mode overlay" but also "White Text"?)
  ///
  /// Let's stick to the direct logic requested:
  /// Step 2: Decide theme mode automatically:
  /// final accent = extractedColor;
  /// final isDarkAccent = accent.computeLuminance() < 0.5;
  /// final textColor = isDarkAccent ? Colors.white : Colors.black;
  /// final backgroundColor = isDarkAccent ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.15);
  static ({Color textColor, Color backgroundColor, bool isDark}) getUiColors(Color accent) {
    final isDarkAccent = isDark(accent);
    final textColor = isDarkAccent ? Colors.white : Colors.black;
    // Note: The background color logic here seems to be for an overlay on top of the blurred image?
    // User logic:
    // backgroundColor = isDarkAccent ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.15);
    final backgroundColor = isDarkAccent ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.15);

    return (textColor: textColor, backgroundColor: backgroundColor, isDark: isDarkAccent);
  }

  /// Fallback color logic (Safety Net)
  /// If extracted color is too dark or too gray (luminance < 0.15), return default purple.
  static Color getSafeAccentColor(Color extractedColor) {
    if (extractedColor.computeLuminance() < 0.15) {
      return const Color(0xFF9B51E0); // Default purple
    }
    return extractedColor;
  }
}
