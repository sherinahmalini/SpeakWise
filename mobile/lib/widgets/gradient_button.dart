import 'package:flutter/material.dart';

class GradientButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;

  const GradientButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
  });

  static const Color darkGreen = Color(0xFF01411C);
  static const Color lightGreen = Color(0xFF9AF0BF);

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    final Color backgroundColor = dark ? darkGreen : lightGreen;

    final Color foregroundColor = dark ? Colors.white : darkGreen;

    final Color borderColor = dark
        ? lightGreen.withOpacity(.35)
        : darkGreen.withOpacity(.25);

    return SizedBox(
      width: double.infinity,
      height: 55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,

          borderRadius: BorderRadius.circular(16),

          border: Border.all(color: borderColor, width: 1),

          boxShadow: [
            BoxShadow(
              color: backgroundColor.withOpacity(.18),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),

        child: Material(
          color: Colors.transparent,

          child: InkWell(
            onTap: onPressed,

            borderRadius: BorderRadius.circular(16),

            splashColor: foregroundColor.withOpacity(.12),
            highlightColor: foregroundColor.withOpacity(.06),

            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,

              children: [
                Icon(icon, color: foregroundColor, size: 20),

                const SizedBox(width: 10),

                Text(
                  text,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ).copyWith(color: foregroundColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
