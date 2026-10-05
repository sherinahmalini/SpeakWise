import 'package:flutter/material.dart';

class ThemeToggle extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const ThemeToggle({super.key, required this.isDark, required this.onTap});

  static const Color darkPrimary = Color(0xFF01411C);
  static const Color lightPrimary = Color(0xFF9AF0BF);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 68,
        height: 36,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),

          color: isDark ? const Color(0xFF07100A) : const Color(0xFFEAF9EF),

          border: Border.all(
            color: isDark
                ? lightPrimary.withOpacity(.55)
                : darkPrimary.withOpacity(.35),
          ),

          boxShadow: [
            BoxShadow(
              color: isDark
                  ? darkPrimary.withOpacity(.40)
                  : darkPrimary.withOpacity(.15),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),

        child: AnimatedAlign(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,

          alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,

          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),

            width: 28,
            height: 28,

            decoration: BoxDecoration(
              shape: BoxShape.circle,

              color: isDark ? darkPrimary : lightPrimary,

              border: Border.all(
                color: isDark
                    ? lightPrimary.withOpacity(.45)
                    : darkPrimary.withOpacity(.30),
              ),

              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? darkPrimary.withOpacity(.45)
                      : darkPrimary.withOpacity(.20),
                  blurRadius: 8,
                ),
              ],
            ),

            child: Icon(
              isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
              size: 16,
              color: isDark ? lightPrimary : darkPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
