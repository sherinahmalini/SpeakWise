import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  // =========================================================
  // COLORS
  // =========================================================

  static const Color darkGreen = Color(0xFF01411C);
  static const Color lightGreen = Color(0xFF9AF0BF);

  // =========================================================
  // SUPPORT DETAILS
  // =========================================================

  static const String supportPhoneDisplay = '011-1687 4667';

  // Malaysian number:
  // 01116874667 -> +60 11-1687 4667
  static const String supportWhatsAppNumber = '601116874667';

  // =========================================================
  // OPEN WHATSAPP
  // =========================================================

  Future<void> _openWhatsApp(BuildContext context) async {
    const String message =
        'Hello SpeakWise Support! I need help with the SpeakWise app.';

    final Uri whatsappUri = Uri.parse(
      'https://wa.me/$supportWhatsAppNumber'
      '?text=${Uri.encodeComponent(message)}',
    );

    try {
      final bool opened = await launchUrl(
        whatsappUri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && context.mounted) {
        _showError(
          context,
          'Unable to open WhatsApp. Please contact $supportPhoneDisplay.',
        );
      }
    } catch (e) {
      debugPrint('WhatsApp launch error: $e');

      if (context.mounted) {
        _showError(
          context,
          'Unable to open WhatsApp. Please contact $supportPhoneDisplay.',
        );
      }
    }
  }

  // =========================================================
  // ERROR MESSAGE
  // =========================================================

  void _showError(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    final Color textColor = dark ? Colors.white : const Color(0xFF17221A);

    final Color secondaryColor =
        dark ? Colors.white70 : const Color(0xFF52635A);

    final Color cardColor = dark ? const Color(0xFF07150D) : Colors.white;

    final Color accentColor = dark ? lightGreen : darkGreen;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      // =====================================================
      // APP BAR
      // =====================================================

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(
          color: accentColor,
        ),
        title: Text(
          'Help & Support',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // =====================================================
      // BODY
      // =====================================================

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          24,
          10,
          24,
          35,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =================================================
            // HERO SECTION
            // =================================================

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: dark
                      ? [
                          const Color(0xFF063D24),
                          const Color(0xFF102B1D),
                        ]
                      : [
                          const Color(0xFFE1F9E9),
                          Colors.white,
                        ],
                ),
                border: Border.all(
                  color: accentColor.withOpacity(.35),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How can we help you?',
                          style: GoogleFonts.poppins(
                            color: textColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Find helpful information about SpeakWise.',
                          style: GoogleFonts.poppins(
                            color: secondaryColor,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  Container(
                    width: 65,
                    height: 65,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 34,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // =================================================
            // QUICK HELP
            // =================================================

            Text(
              'Quick Help',
              style: GoogleFonts.poppins(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              'Select a topic below to learn more.',
              style: GoogleFonts.poppins(
                color: secondaryColor,
                fontSize: 11,
              ),
            ),

            const SizedBox(height: 14),

            // =================================================
            // GETTING STARTED
            // =================================================

            _helpCard(
              context,
              icon: Icons.rocket_launch_outlined,
              title: 'Getting Started',
              description: 'Learn the basics of using SpeakWise.',
              cardColor: cardColor,
              textColor: textColor,
              secondaryColor: secondaryColor,
              accentColor: accentColor,
            ),

            // =================================================
            // UPLOAD PRESENTATION
            // =================================================

            _helpCard(
              context,
              icon: Icons.upload_file_outlined,
              title: 'Upload Presentation',
              description: 'Learn how to upload your presentation files.',
              cardColor: cardColor,
              textColor: textColor,
              secondaryColor: secondaryColor,
              accentColor: accentColor,
            ),

            // =================================================
            // SPEECH ASSESSMENT
            // =================================================

            _helpCard(
              context,
              icon: Icons.mic_none_rounded,
              title: 'Speech Assessment',
              description: 'Learn how to record or upload your speech.',
              cardColor: cardColor,
              textColor: textColor,
              secondaryColor: secondaryColor,
              accentColor: accentColor,
            ),

            // =================================================
            // AI PRACTICE
            // =================================================

            _helpCard(
              context,
              icon: Icons.psychology_outlined,
              title: 'AI Practice',
              description: 'Practice your presentation skills with AI.',
              cardColor: cardColor,
              textColor: textColor,
              secondaryColor: secondaryColor,
              accentColor: accentColor,
            ),

            // =================================================
            // MY ASSESSMENTS
            // =================================================

            _helpCard(
              context,
              icon: Icons.assessment_outlined,
              title: 'My Assessments',
              description: 'View your previous presentation results.',
              cardColor: cardColor,
              textColor: textColor,
              secondaryColor: secondaryColor,
              accentColor: accentColor,
            ),

            // =================================================
            // ACCOUNT & PROFILE
            // =================================================

            _helpCard(
              context,
              icon: Icons.person_outline_rounded,
              title: 'Account & Profile',
              description: 'Manage your profile and account details.',
              cardColor: cardColor,
              textColor: textColor,
              secondaryColor: secondaryColor,
              accentColor: accentColor,
            ),

            const SizedBox(height: 20),

            // =================================================
            // STILL NEED HELP
            // =================================================

            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  _showSupportDialog(context);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: accentColor.withOpacity(.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(.10),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.support_agent_rounded,
                          color: accentColor,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Still need help?',
                              style: GoogleFonts.poppins(
                                color: textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Chat with SpeakWise Support on WhatsApp.',
                              style: GoogleFonts.poppins(
                                color: secondaryColor,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: secondaryColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // HELP CARD
  // =========================================================

  Widget _helpCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color cardColor,
    required Color textColor,
    required Color secondaryColor,
    required Color accentColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            _showHelpDialog(
              context,
              title,
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: accentColor.withOpacity(.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(.10),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    icon,
                    color: accentColor,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: GoogleFonts.poppins(
                          color: secondaryColor,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: secondaryColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // HELP DIALOG
  // =========================================================

  void _showHelpDialog(
    BuildContext context,
    String title,
  ) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    final Color textColor = dark ? Colors.white : const Color(0xFF17221A);

    final Color secondaryColor =
        dark ? Colors.white70 : const Color(0xFF52635A);

    final Color accentColor = dark ? lightGreen : darkGreen;

    IconData helpIcon;
    String helpText;

    switch (title) {
      // =====================================================
      // GETTING STARTED
      // =====================================================

      case 'Getting Started':
        helpIcon = Icons.rocket_launch_outlined;

        helpText = 'Welcome to SpeakWise!\n\n'
            '1. Register or log in to your account.\n\n'
            '2. Open the SpeakWise dashboard.\n\n'
            '3. Choose the feature you want to use.\n\n'
            '4. Upload your presentation and provide the required information.\n\n'
            '5. Complete your speech assessment.\n\n'
            '6. Review your AI-generated results and feedback.\n\n'
            '7. Your saved assessments can be viewed from My Assessments.';
        break;

      // =====================================================
      // UPLOAD PRESENTATION
      // =====================================================

      case 'Upload Presentation':
        helpIcon = Icons.upload_file_outlined;

        helpText = 'Uploading a Presentation\n\n'
            '1. Open Upload Presentation from the dashboard.\n\n'
            '2. Choose Upload File or Paste Link.\n\n'
            '3. If uploading files, select your presentation file or supporting images.\n\n'
            '4. Supported presentation files include PDF, PPT, PPTX, DOC and DOCX.\n\n'
            '5. Supported image files include PNG, JPG, JPEG and WEBP.\n\n'
            '6. Enter your programme, presentation title and topic.\n\n'
            '7. You may also enter an optional presentation description.\n\n'
            '8. Select your presentation language and assessment type.\n\n'
            '9. Press Continue to Speech Assessment.';
        break;

      // =====================================================
      // SPEECH ASSESSMENT
      // =====================================================

      case 'Speech Assessment':
        helpIcon = Icons.mic_none_rounded;

        helpText = 'Speech Assessment\n\n'
            '1. Continue to the Speech Assessment after entering your presentation information.\n\n'
            '2. Record or upload your speech using the available option.\n\n'
            '3. Make sure your speech is clear and audible.\n\n'
            '4. Submit your speech when you are ready.\n\n'
            '5. SpeakWise will analyse your speaking performance.\n\n'
            '6. Your result may include pronunciation, fluency, grammar, vocabulary, speech clarity and pacing.\n\n'
            '7. Review the AI feedback to identify areas you can improve.';
        break;

      // =====================================================
      // AI PRACTICE
      // =====================================================

      case 'AI Practice':
        helpIcon = Icons.psychology_outlined;

        helpText = 'AI Practice\n\n'
            '1. Open AI Practice from the dashboard.\n\n'
            '2. Start a practice session.\n\n'
            '3. Follow the questions or prompts shown by SpeakWise.\n\n'
            '4. Respond as naturally as possible.\n\n'
            '5. Use the practice session to improve your confidence and communication skills.\n\n'
            '6. Repeat practice sessions whenever you want additional preparation.';
        break;

      // =====================================================
      // MY ASSESSMENTS
      // =====================================================

      case 'My Assessments':
        helpIcon = Icons.assessment_outlined;

        helpText = 'My Assessments\n\n'
            '1. Open My Assessments from the dashboard.\n\n'
            '2. Your saved speech assessments will appear on this page.\n\n'
            '3. Select an assessment to view the complete result.\n\n'
            '4. You can review your score, performance areas and AI feedback.\n\n'
            '5. Use Rename if you want to change the name of a saved assessment.\n\n'
            '6. Use Delete if you no longer want to keep an assessment.\n\n'
            '7. You can also search or filter your saved assessments.';
        break;

      // =====================================================
      // ACCOUNT & PROFILE
      // =====================================================

      case 'Account & Profile':
        helpIcon = Icons.person_outline_rounded;

        helpText = 'Account & Profile\n\n'
            '1. Click your name from the dashboard to open your profile.\n\n'
            '2. View your account and personal information.\n\n'
            '3. Update your profile information where editing is available.\n\n'
            '4. Keep your account information accurate.\n\n'
            '5. Return to the dashboard when you are finished.\n\n'
            '6. Use the Logout button below your name when you want to sign out.';
        break;

      default:
        helpIcon = Icons.help_outline_rounded;
        helpText = 'Help information is currently unavailable.';
    }

    // =======================================================
    // SHOW HELP DIALOG
    // =======================================================

    showDialog(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          backgroundColor: dark ? const Color(0xFF0B1510) : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(
                    .10,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  helpIcon,
                  color: accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 500,
            ),
            child: SingleChildScrollView(
              child: Text(
                helpText,
                style: GoogleFonts.poppins(
                  color: secondaryColor,
                  fontSize: 13,
                  height: 1.55,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: Text(
                'CLOSE',
                style: GoogleFonts.poppins(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // SUPPORT DIALOG
  // =========================================================

  void _showSupportDialog(
    BuildContext context,
  ) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    final Color textColor = dark ? Colors.white : const Color(0xFF17221A);

    final Color secondaryColor =
        dark ? Colors.white70 : const Color(0xFF52635A);

    final Color accentColor = dark ? lightGreen : darkGreen;

    showDialog(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          backgroundColor: dark ? const Color(0xFF0B1510) : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),

          // =================================================
          // TITLE
          // =================================================

          title: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(
                    .10,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.support_agent_rounded,
                  color: accentColor,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'SpeakWise Support',
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // =================================================
          // CONTENT
          // =================================================

          content: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 500,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need additional help?',
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Contact the SpeakWise support team directly through WhatsApp.',
                  style: GoogleFonts.poppins(
                    color: secondaryColor,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),

                const SizedBox(height: 18),

                // =============================================
                // PHONE NUMBER
                // =============================================

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(
                      .08,
                    ),
                    borderRadius: BorderRadius.circular(
                      14,
                    ),
                    border: Border.all(
                      color: accentColor.withOpacity(
                        .20,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        color: accentColor,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Support Number',
                              style: GoogleFonts.poppins(
                                color: secondaryColor,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(
                              height: 2,
                            ),
                            Text(
                              supportPhoneDisplay,
                              style: GoogleFonts.poppins(
                                color: textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // =============================================
                // WHATSAPP BUTTON
                // =============================================

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(
                        dialogContext,
                      );

                      _openWhatsApp(
                        context,
                      );
                    },
                    icon: const Icon(
                      Icons.chat_rounded,
                    ),
                    label: Text(
                      'CHAT ON WHATSAPP',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: dark ? darkGreen : Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          14,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // =============================================
                // SUPPORT TIP
                // =============================================

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(
                      .06,
                    ),
                    borderRadius: BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: accentColor,
                        size: 19,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: Text(
                          'When reporting a problem, explain what you were trying to do and what happened so the support team can help you faster.',
                          style: GoogleFonts.poppins(
                            color: secondaryColor,
                            fontSize: 10,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // =================================================
          // ACTIONS
          // =================================================

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: Text(
                'CLOSE',
                style: GoogleFonts.poppins(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
