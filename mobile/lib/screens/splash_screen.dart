import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  // =========================================================
  // SPEAKWISE COLOURS
  // =========================================================

  static const Color darkPrimary = Color(0xFF01411C);
  static const Color lightPrimary = Color(0xFF9AF0BF);

  @override
  void initState() {
    super.initState();

    _timer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    // =========================================================
    // COLOUR SYSTEM
    // =========================================================

    final Color primary = dark ? darkPrimary : lightPrimary;

    final Color accent = dark ? lightPrimary : darkPrimary;

    final Color background = dark
        ? const Color(0xFF050A07)
        : const Color(0xFFF7FBF8);

    final Color textColor = dark ? Colors.white : const Color(0xFF17221A);

    final Color secondaryText = dark ? Colors.white70 : const Color(0xFF5F6B63);

    return Scaffold(
      backgroundColor: background,

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),

            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,

              children: [
                // =================================================
                // LOGO
                // =================================================
                Container(
                  width: 170,
                  height: 170,

                  padding: const EdgeInsets.all(30),

                  decoration: BoxDecoration(
                    color: primary.withOpacity(.14),

                    borderRadius: BorderRadius.circular(40),

                    border: Border.all(
                      color: accent.withOpacity(.40),
                      width: 1.5,
                    ),

                    boxShadow: [
                      BoxShadow(
                        color: primary.withOpacity(dark ? .20 : .10),

                        blurRadius: 35,

                        spreadRadius: 2,
                      ),
                    ],
                  ),

                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 32),

                // =================================================
                // APP NAME
                // =================================================
                Text(
                  'SpeakWise',

                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: .3,
                  ),
                ),

                const SizedBox(height: 8),

                // =================================================
                // TAGLINE
                // =================================================
                Text(
                  'AI Presentation Coach',

                  style: GoogleFonts.poppins(
                    color: accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 12),

                // =================================================
                // DESCRIPTION
                // =================================================
                Text(
                  'Speak better.\nPresent with confidence.',

                  textAlign: TextAlign.center,

                  style: GoogleFonts.poppins(
                    color: secondaryText,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),

                const SizedBox(height: 45),

                // =================================================
                // LOADING
                // =================================================
                Container(
                  width: 48,
                  height: 48,

                  padding: const EdgeInsets.all(9),

                  decoration: BoxDecoration(
                    color: primary.withOpacity(.10),

                    shape: BoxShape.circle,
                  ),

                  child: CircularProgressIndicator(
                    strokeWidth: 3,

                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),

                const SizedBox(height: 18),

                Text(
                  'Preparing your AI experience...',

                  textAlign: TextAlign.center,

                  style: GoogleFonts.poppins(
                    color: secondaryText,
                    fontSize: 11,
                  ),
                ),

                const SizedBox(height: 55),

                // =================================================
                // FEATURES
                // =================================================
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,

                  children: [
                    _feature(
                      Icons.auto_awesome_rounded,
                      'AI Assessment',
                      secondaryText,
                      primary,
                      accent,
                    ),

                    const SizedBox(width: 18),

                    _feature(
                      Icons.mic_none_rounded,
                      'Speech Analysis',
                      secondaryText,
                      primary,
                      accent,
                    ),

                    const SizedBox(width: 18),

                    _feature(
                      Icons.psychology_outlined,
                      'AI Practice',
                      secondaryText,
                      primary,
                      accent,
                    ),
                  ],
                ),

                const SizedBox(height: 35),

                // =================================================
                // FOOTER
                // =================================================
                Text(
                  'SpeakWise • AI Presentation Coach',

                  style: GoogleFonts.poppins(color: secondaryText, fontSize: 9),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // FEATURE ITEM
  // =========================================================

  Widget _feature(
    IconData icon,
    String title,
    Color secondaryText,
    Color primary,
    Color accent,
  ) {
    return Column(
      children: [
        Container(
          width: 38,
          height: 38,

          decoration: BoxDecoration(
            color: primary.withOpacity(.12),

            borderRadius: BorderRadius.circular(11),
          ),

          child: Icon(icon, color: accent, size: 19),
        ),

        const SizedBox(height: 6),

        Text(
          title,

          textAlign: TextAlign.center,

          style: GoogleFonts.poppins(
            color: secondaryText,
            fontSize: 8,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
