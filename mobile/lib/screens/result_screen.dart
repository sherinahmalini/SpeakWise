import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widgets/theme_toggle.dart';
import '../theme/theme_controller.dart';

class ResultScreen extends StatefulWidget {
  final double overallScore;
  final double pronunciation;
  final double fluency;
  final double grammar;
  final double vocabulary;
  final double speechClarity;
  final double pacing;
  final String feedback;

  const ResultScreen({
    super.key,
    this.overallScore = 0,
    this.pronunciation = 0,
    this.fluency = 0,
    this.grammar = 0,
    this.vocabulary = 0,
    this.speechClarity = 0,
    this.pacing = 0,
    this.feedback = 'No feedback available for this assessment.',
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isSaving = false;
  bool resultSaved = false;

  static const Color darkPrimary = Color(0xFF01411C);
  static const Color lightPrimary = Color(0xFF9AF0BF);

  // =========================================================
  // THEME HELPERS
  // =========================================================

  bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  Color accentColor(BuildContext context) {
    return isDark(context) ? lightPrimary : darkPrimary;
  }

  Color textColor(BuildContext context) {
    return isDark(context) ? Colors.white : const Color(0xFF17221A);
  }

  Color secondaryTextColor(BuildContext context) {
    return isDark(context) ? Colors.white70 : const Color(0xFF5F6B63);
  }

  Color cardColor(BuildContext context) {
    return isDark(context) ? const Color(0xFF07150D) : Colors.white;
  }

  // =========================================================
  // SAFE SCORES
  // =========================================================

  double safeScore(double value) {
    if (value.isNaN || value.isInfinite) {
      return 0;
    }

    return value.clamp(0, 100).toDouble();
  }

  double get overallScore => safeScore(widget.overallScore);

  double get pronunciation => safeScore(widget.pronunciation);

  double get fluency => safeScore(widget.fluency);

  double get grammar => safeScore(widget.grammar);

  double get vocabulary => safeScore(widget.vocabulary);

  double get speechClarity => safeScore(widget.speechClarity);

  double get pacing => safeScore(widget.pacing);

  String get feedback {
    final String value = widget.feedback.trim();

    if (value.isEmpty) {
      return 'No feedback available for this assessment.';
    }

    return value;
  }

  // =========================================================
  // SCORES MAP
  // =========================================================

  Map<String, double> get scores {
    return {
      'Pronunciation': pronunciation,
      'Fluency': fluency,
      'Grammar': grammar,
      'Vocabulary': vocabulary,
      'Speech Clarity': speechClarity,
      'Pacing': pacing,
    };
  }

  // =========================================================
  // STRONGEST / WEAKEST AREA
  // =========================================================

  String get strongestArea {
    return scores.entries
        .reduce(
          (a, b) => a.value >= b.value ? a : b,
        )
        .key;
  }

  String get weakestArea {
    return scores.entries
        .reduce(
          (a, b) => a.value <= b.value ? a : b,
        )
        .key;
  }

  // =========================================================
  // SCORE LEVEL
  // =========================================================

  String get scoreLevel {
    if (overallScore >= 90) {
      return 'Excellent';
    }

    if (overallScore >= 80) {
      return 'Very Good';
    }

    if (overallScore >= 60) {
      return 'Good';
    }

    if (overallScore >= 40) {
      return 'Average';
    }

    return 'Needs Improvement';
  }

  // =========================================================
  // SCORE DESCRIPTION
  // =========================================================

  String get scoreDescription {
    if (overallScore >= 90) {
      return 'Outstanding communication performance!';
    }

    if (overallScore >= 80) {
      return 'You demonstrated strong communication skills.';
    }

    if (overallScore >= 60) {
      return 'You have good communication skills with room to improve.';
    }

    if (overallScore >= 40) {
      return 'Your communication skills are developing.';
    }

    return 'More practice is recommended to improve your speaking skills.';
  }

  // =========================================================
  // SHOW MESSAGE
  // =========================================================

  void showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(
            color: Colors.white,
          ),
        ),
        backgroundColor: isError ? Colors.red.shade700 : darkPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // =========================================================
  // GET ASSESSMENT TITLE
  // =========================================================

  Future<String?> _getAssessmentTitle() async {
    if (!mounted) {
      return null;
    }

    final bool dark = isDark(context);

    final Color text = dark ? Colors.white : const Color(0xFF17221A);

    final Color secondary = dark ? Colors.white70 : const Color(0xFF5F6B63);

    final Color accent = dark ? lightPrimary : darkPrimary;

    String assessmentName = 'Speech Assessment';

    final String? title = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: dark ? const Color(0xFF0B1510) : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),

          // ===================================================
          // DIALOG TITLE
          // ===================================================

          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withOpacity(.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.drive_file_rename_outline_rounded,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Name Your Assessment',
                  style: GoogleFonts.poppins(
                    color: text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // ===================================================
          // DIALOG INPUT
          // ===================================================

          content: TextFormField(
            initialValue: assessmentName,
            autofocus: true,
            maxLength: 50,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            style: GoogleFonts.poppins(
              color: text,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              labelText: 'Assessment name',
              hintText: 'Enter a name',
              counterStyle: GoogleFonts.poppins(
                color: secondary,
                fontSize: 10,
              ),
              labelStyle: GoogleFonts.poppins(
                color: secondary,
              ),
              hintStyle: GoogleFonts.poppins(
                color: secondary,
              ),
              filled: true,
              fillColor: dark
                  ? Colors.white.withOpacity(.05)
                  : const Color(0xFFF3F8F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: accent.withOpacity(.25),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: accent,
                  width: 1.5,
                ),
              ),
            ),
            onChanged: (String value) {
              assessmentName = value;
            },
            onFieldSubmitted: (String value) {
              final String newTitle = value.trim();

              if (newTitle.isEmpty) {
                return;
              }

              Navigator.of(dialogContext).pop(newTitle);
            },
          ),

          // ===================================================
          // DIALOG ACTIONS
          // ===================================================

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                'CANCEL',
                style: GoogleFonts.poppins(
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final String newTitle = assessmentName.trim();

                if (newTitle.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).hideCurrentSnackBar();

                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Please enter an assessment name.',
                        style: GoogleFonts.poppins(),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );

                  return;
                }

                Navigator.of(dialogContext).pop(newTitle);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: dark ? darkPrimary : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'SAVE',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return null;
    }

    return title;
  }

  // =========================================================
  // SAVE RESULT
  // =========================================================

  Future<void> _saveResult() async {
    if (isSaving || resultSaved) {
      return;
    }

    final User? user = _auth.currentUser;

    if (user == null) {
      showMessage(
        'Please log in before saving your result.',
        isError: true,
      );
      return;
    }

    final String? assessmentTitle = await _getAssessmentTitle();

    if (!mounted) {
      return;
    }

    if (assessmentTitle == null || assessmentTitle.trim().isEmpty) {
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await _firestore.collection('assessments').add({
        'userId': user.uid,
        'title': assessmentTitle.trim(),

        'overallScore': overallScore,
        'score': overallScore,
        'pronunciation': pronunciation,
        'fluency': fluency,
        'grammar': grammar,
        'vocabulary': vocabulary,
        'speechClarity': speechClarity,
        'pacing': pacing,

        'feedback': feedback,
        'level': scoreLevel,
        'strongestArea': strongestArea,
        'weakestArea': weakestArea,
        'status': 'Completed',

        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      setState(() {
        isSaving = false;
        resultSaved = true;
      });

      showMessage(
        'Assessment result saved successfully.',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'Unable to save assessment result: $e',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        isSaving = false;
      });

      showMessage(
        'Unable to save the assessment result. Please try again.',
        isError: true,
      );
    }
  }

  // =========================================================
  // CARD DECORATION
  // =========================================================

  BoxDecoration cardDecoration(
    BuildContext context,
  ) {
    final bool dark = isDark(context);

    return BoxDecoration(
      color: cardColor(context),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color:
            dark ? lightPrimary.withOpacity(.25) : darkPrimary.withOpacity(.18),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(
            dark ? .10 : .025,
          ),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  // =========================================================
  // SCORE RANGE CARD
  // =========================================================

  Widget scoreRangeCard(
    BuildContext context,
  ) {
    final bool dark = isDark(context);
    final Color accent = accentColor(context);

    final List<Map<String, String>> ranges = [
      {
        'range': '90–100',
        'level': 'Excellent',
      },
      {
        'range': '80–89',
        'level': 'Very Good',
      },
      {
        'range': '60–79',
        'level': 'Good',
      },
      {
        'range': '40–59',
        'level': 'Average',
      },
      {
        'range': '0–39',
        'level': 'Needs Improvement',
      },
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Score Range Guide',
            style: GoogleFonts.poppins(
              color: textColor(context),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          ...ranges.map(
            (item) {
              final bool selected = item['level'] == scoreLevel;

              return Container(
                margin: const EdgeInsets.only(
                  bottom: 8,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? accent.withOpacity(.12)
                      : dark
                          ? Colors.white.withOpacity(.04)
                          : Colors.grey.withOpacity(.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? accent : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['range']!,
                        style: GoogleFonts.poppins(
                          color: textColor(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      item['level']!,
                      style: GoogleFonts.poppins(
                        color: selected ? accent : secondaryTextColor(context),
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check_circle_rounded,
                        color: accent,
                        size: 18,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SCORE CIRCLE
  // =========================================================

  Widget scoreCircle(
    BuildContext context,
  ) {
    final bool dark = isDark(context);
    final Color accent = accentColor(context);

    return Container(
      width: 155,
      height: 155,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [
            darkPrimary,
            lightPrimary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: darkPrimary.withOpacity(.25),
            blurRadius: 25,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: dark ? const Color(0xFF020804) : Colors.white,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                overallScore.round().toString(),
                style: GoogleFonts.poppins(
                  color: accent,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '/ 100',
                style: GoogleFonts.poppins(
                  color: secondaryTextColor(context),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // OVERALL CARD
  // =========================================================

  Widget overallCard(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: cardDecoration(context),
      child: Column(
        children: [
          Text(
            'Overall AI Score',
            style: GoogleFonts.poppins(
              color: secondaryTextColor(context),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          scoreCircle(context),
          const SizedBox(height: 18),
          Text(
            scoreLevel,
            style: GoogleFonts.poppins(
              color: accentColor(context),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            scoreDescription,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: secondaryTextColor(context),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SUMMARY ITEM
  // =========================================================

  Widget summaryItem(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    final Color accent = accentColor(context);

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withOpacity(.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            color: accent,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: secondaryTextColor(context),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  color: textColor(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================
  // SUMMARY CARD
  // =========================================================

  Widget summaryCard(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assessment Summary',
            style: GoogleFonts.poppins(
              color: textColor(context),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          summaryItem(
            context,
            'Strongest Area',
            strongestArea,
            Icons.trending_up_rounded,
          ),
          const SizedBox(height: 14),
          summaryItem(
            context,
            'Needs Practice',
            weakestArea,
            Icons.flag_outlined,
          ),
          const SizedBox(height: 14),
          summaryItem(
            context,
            'Assessment Level',
            scoreLevel,
            Icons.assessment_outlined,
          ),
          const SizedBox(height: 14),
          summaryItem(
            context,
            'Assessment Status',
            'Completed',
            Icons.check_circle_outline_rounded,
          ),
        ],
      ),
    );
  }

  // =========================================================
  // FEEDBACK CARD
  // =========================================================

  Widget feedbackCard(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: accentColor(context),
              ),
              const SizedBox(width: 12),
              Text(
                'AI Feedback',
                style: GoogleFonts.poppins(
                  color: textColor(context),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            feedback,
            style: GoogleFonts.poppins(
              color: secondaryTextColor(context),
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // METRIC CARD
  // =========================================================

  Widget metricCard(
    BuildContext context,
    String title,
    double value,
    IconData icon,
  ) {
    final Color accent = accentColor(context);
    final bool dark = isDark(context);
    final double safeValue = safeScore(value);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(context).copyWith(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withOpacity(.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: textColor(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: safeValue / 100,
                    minHeight: 7,
                    backgroundColor:
                        dark ? Colors.white12 : const Color(0xFFE5EDE7),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text(
            '${safeValue.round()}%',
            style: GoogleFonts.poppins(
              color: accent,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // METRIC SECTION
  // =========================================================

  Widget metricSection(
    BuildContext context,
  ) {
    final List<Widget> metrics = [
      metricCard(
        context,
        'Pronunciation',
        pronunciation,
        Icons.record_voice_over_outlined,
      ),
      metricCard(
        context,
        'Fluency',
        fluency,
        Icons.speed_outlined,
      ),
      metricCard(
        context,
        'Grammar',
        grammar,
        Icons.spellcheck_outlined,
      ),
      metricCard(
        context,
        'Vocabulary',
        vocabulary,
        Icons.auto_awesome_outlined,
      ),
      metricCard(
        context,
        'Speech Clarity',
        speechClarity,
        Icons.volume_up_outlined,
      ),
      metricCard(
        context,
        'Pacing',
        pacing,
        Icons.timer_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        if (constraints.maxWidth >= 750) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: metrics.sublist(0, 3),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  children: metrics.sublist(3, 6),
                ),
              ),
            ],
          );
        }

        return Column(
          children: metrics,
        );
      },
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final bool dark = isDark(context);

    final Color buttonColor = dark ? darkPrimary : lightPrimary;

    final Color buttonText = dark ? Colors.white : darkPrimary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      // =====================================================
      // APP BAR
      // =====================================================

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: isSaving
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          icon: Icon(
            Icons.arrow_back_rounded,
            color: textColor(context),
          ),
        ),
        title: Text(
          'Assessment Result',
          style: GoogleFonts.poppins(
            color: textColor(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(
              right: 16,
            ),
            child: Center(
              child: ThemeToggle(
                isDark: ThemeController.isDark,
                onTap: ThemeController.toggleTheme,
              ),
            ),
          ),
        ],
      ),

      // =====================================================
      // BODY
      // =====================================================

      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(
                maxWidth: 1100,
              ),
              padding: const EdgeInsets.fromLTRB(
                30,
                20,
                30,
                40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===========================================
                  // TITLE
                  // ===========================================

                  Text(
                    'Your Assessment Result',
                    style: GoogleFonts.poppins(
                      color: textColor(context),
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Here is your SpeakWise AI speech performance analysis.',
                    style: GoogleFonts.poppins(
                      color: secondaryTextColor(context),
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 25),

                  // ===========================================
                  // OVERALL + SUMMARY
                  // ===========================================

                  LayoutBuilder(
                    builder: (
                      BuildContext context,
                      BoxConstraints constraints,
                    ) {
                      if (constraints.maxWidth >= 750) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: overallCard(context),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: summaryCard(context),
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          overallCard(context),
                          const SizedBox(height: 18),
                          summaryCard(context),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // ===========================================
                  // SCORE GUIDE
                  // ===========================================

                  scoreRangeCard(context),

                  const SizedBox(height: 30),

                  // ===========================================
                  // PERFORMANCE TITLE
                  // ===========================================

                  Text(
                    'Speech Performance',
                    style: GoogleFonts.poppins(
                      color: textColor(context),
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    'Detailed analysis of your communication skills.',
                    style: GoogleFonts.poppins(
                      color: secondaryTextColor(context),
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 15),

                  // ===========================================
                  // METRICS
                  // ===========================================

                  metricSection(context),

                  const SizedBox(height: 20),

                  // ===========================================
                  // FEEDBACK
                  // ===========================================

                  feedbackCard(context),

                  const SizedBox(height: 25),

                  // ===========================================
                  // BUTTONS
                  // ===========================================

                  LayoutBuilder(
                    builder: (
                      BuildContext context,
                      BoxConstraints constraints,
                    ) {
                      if (constraints.maxWidth < 520) {
                        return Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: HoverButton(
                                height: 52,
                                backgroundColor: buttonColor,
                                foregroundColor: buttonText,
                                icon: Icons.refresh_rounded,
                                label: 'TRY AGAIN',
                                onPressed: isSaving
                                    ? null
                                    : () {
                                        Navigator.of(
                                          context,
                                        ).pop();
                                      },
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: HoverButton(
                                height: 52,
                                outlined: true,
                                foregroundColor: accentColor(context),
                                borderColor: accentColor(context),
                                icon: resultSaved
                                    ? Icons.check_circle_outline
                                    : Icons.save_outlined,
                                label: resultSaved
                                    ? 'SAVED'
                                    : isSaving
                                        ? 'SAVING...'
                                        : 'SAVE RESULT',
                                isLoading: isSaving,
                                onPressed: isSaving || resultSaved
                                    ? null
                                    : _saveResult,
                              ),
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: HoverButton(
                              height: 52,
                              backgroundColor: buttonColor,
                              foregroundColor: buttonText,
                              icon: Icons.refresh_rounded,
                              label: 'TRY AGAIN',
                              onPressed: isSaving
                                  ? null
                                  : () {
                                      Navigator.of(
                                        context,
                                      ).pop();
                                    },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: HoverButton(
                              height: 52,
                              outlined: true,
                              foregroundColor: accentColor(context),
                              borderColor: accentColor(context),
                              icon: resultSaved
                                  ? Icons.check_circle_outline
                                  : Icons.save_outlined,
                              label: resultSaved
                                  ? 'SAVED'
                                  : isSaving
                                      ? 'SAVING...'
                                      : 'SAVE RESULT',
                              isLoading: isSaving,
                              onPressed:
                                  isSaving || resultSaved ? null : _saveResult,
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================
// HOVER BUTTON
// ===========================================================

class HoverButton extends StatefulWidget {
  final double height;
  final Color? backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool isLoading;

  const HoverButton({
    super.key,
    required this.height,
    required this.foregroundColor,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.backgroundColor,
    this.borderColor,
    this.outlined = false,
    this.isLoading = false,
  });

  @override
  State<HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<HoverButton> {
  bool isHovered = false;

  @override
  void didUpdateWidget(
    covariant HoverButton oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (widget.onPressed == null && isHovered) {
      isHovered = false;
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final Color hoverColor = widget.foregroundColor;

    return MouseRegion(
      cursor: widget.onPressed == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) {
        if (widget.onPressed == null || isHovered || !mounted) {
          return;
        }

        setState(() {
          isHovered = true;
        });
      },
      onExit: (_) {
        if (!mounted || !isHovered) {
          return;
        }

        setState(() {
          isHovered = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          boxShadow: isHovered && widget.onPressed != null
              ? [
                  BoxShadow(
                    color: hoverColor.withOpacity(.30),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: widget.outlined
            ? OutlinedButton.icon(
                onPressed: widget.onPressed,
                icon: widget.isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: widget.foregroundColor,
                        ),
                      )
                    : Icon(
                        widget.icon,
                        color: widget.foregroundColor,
                        size: 19,
                      ),
                label: Text(
                  widget.label,
                  style: GoogleFonts.poppins(
                    color: widget.foregroundColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: widget.borderColor ?? widget.foregroundColor,
                    width: isHovered ? 2 : 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              )
            : ElevatedButton.icon(
                onPressed: widget.onPressed,
                icon: widget.isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: widget.foregroundColor,
                        ),
                      )
                    : Icon(
                        widget.icon,
                        size: 19,
                      ),
                label: Text(
                  widget.label,
                  style: GoogleFonts.poppins(
                    color: isHovered
                        ? widget.backgroundColor
                        : widget.foregroundColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isHovered
                      ? widget.foregroundColor
                      : widget.backgroundColor,
                  foregroundColor: isHovered
                      ? widget.backgroundColor
                      : widget.foregroundColor,
                  disabledBackgroundColor:
                      widget.backgroundColor?.withOpacity(.50),
                  disabledForegroundColor:
                      widget.foregroundColor.withOpacity(.60),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
      ),
    );
  }
}
