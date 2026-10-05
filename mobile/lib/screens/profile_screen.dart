import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_screen.dart';
import '../widgets/gradient_button.dart';
import '../widgets/theme_toggle.dart';
import '../theme/theme_controller.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // =========================================================
  // SERVICES
  // =========================================================

  final AuthService _authService = AuthService();

  // =========================================================
  // COLOURS
  // =========================================================

  static const Color darkPrimary = Color(0xFF01411C);
  static const Color lightPrimary = Color(0xFF9AF0BF);

  // =========================================================
  // USER DATA
  // =========================================================

  String fullName = 'Loading...';
  String email = 'Loading...';
  String matricNumber = 'Loading...';

  // =========================================================
  // ASSESSMENT STATISTICS
  // =========================================================

  int analyses = 0;
  int highestScore = 0;
  String level = 'Beginner';

  bool isLoading = true;
  bool isUpdatingProfile = false;
  bool isLoggingOut = false;

  // =========================================================
  // THEME HELPERS
  // =========================================================

  bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  Color primaryColor(BuildContext context) {
    return isDark(context) ? darkPrimary : lightPrimary;
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

  Color borderColor(BuildContext context) {
    return isDark(context)
        ? lightPrimary.withOpacity(.25)
        : darkPrimary.withOpacity(.18);
  }

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // =========================================================
  // LOAD USER DATA
  // =========================================================

  Future<void> _loadUserData() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final user = _authService.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          fullName = 'No user';
          email = '';
          matricNumber = '';
          analyses = 0;
          highestScore = 0;
          level = 'Beginner';
          isLoading = false;
        });

        return;
      }

      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _authService.getUserData(user.uid);

      if (!mounted) return;

      if (snapshot.exists) {
        final Map<String, dynamic>? data = snapshot.data();

        final String storedName = data?['fullName']?.toString().trim() ?? '';

        final String storedEmail = data?['email']?.toString().trim() ?? '';

        final String storedMatric =
            data?['matricNumber']?.toString().trim() ?? '';

        setState(() {
          fullName = storedName.isNotEmpty
              ? storedName
              : (user.displayName?.trim().isNotEmpty == true
                  ? user.displayName!.trim()
                  : 'User');

          email = storedEmail.isNotEmpty ? storedEmail : (user.email ?? '');

          matricNumber =
              storedMatric.isNotEmpty ? storedMatric : 'Not provided';
        });
      } else {
        setState(() {
          fullName = user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : 'User';

          email = user.email ?? '';
          matricNumber = 'Not provided';
        });
      }

      await _loadAssessmentStats(user.uid);

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Profile loading error: $e');

      if (!mounted) return;

      setState(() {
        isLoading = false;

        if (fullName == 'Loading...') {
          fullName = 'User';
        }

        if (email == 'Loading...') {
          email = _authService.currentUser?.email ?? '';
        }

        if (matricNumber == 'Loading...') {
          matricNumber = 'Not provided';
        }
      });

      _showMessage(
        'Unable to load profile information.',
        isError: true,
      );
    }
  }

  // =========================================================
  // LOAD ASSESSMENT STATISTICS
  // =========================================================

  Future<void> _loadAssessmentStats(String uid) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('assessments')
              .where(
                'userId',
                isEqualTo: uid,
              )
              .get();

      final int total = snapshot.docs.length;

      int highest = 0;

      for (final doc in snapshot.docs) {
        final Map<String, dynamic> data = doc.data();

        final dynamic scoreValue = data['overallScore'] ?? data['score'];

        int score = 0;

        if (scoreValue is num) {
          score = scoreValue.round();
        } else {
          score = double.tryParse(
                scoreValue?.toString() ?? '0',
              )?.round() ??
              0;
        }

        score = score.clamp(0, 100);

        if (score > highest) {
          highest = score;
        }
      }

      if (!mounted) return;

      setState(() {
        analyses = total;
        highestScore = highest;
        level = _calculateLevel(highest);
      });
    } catch (e) {
      debugPrint('Assessment statistics error: $e');

      if (!mounted) return;

      setState(() {
        analyses = 0;
        highestScore = 0;
        level = 'Beginner';
      });
    }
  }

  // =========================================================
  // CALCULATE PROFILE LEVEL
  // =========================================================

  String _calculateLevel(int score) {
    if (score >= 90) {
      return 'Advanced';
    }

    if (score >= 75) {
      return 'Intermediate';
    }

    return 'Beginner';
  }

  // =========================================================
  // SHOW MESSAGE
  // =========================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
        backgroundColor: isError ? Colors.red.shade700 : darkPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // =========================================================
  // EDIT PROFILE
  // =========================================================

  Future<void> _editProfile() async {
    if (isLoading || isUpdatingProfile) {
      return;
    }

    final TextEditingController nameController = TextEditingController(
      text: fullName == 'User' || fullName == 'Loading...' ? '' : fullName,
    );

    final TextEditingController matricController = TextEditingController(
      text: matricNumber == 'Not provided' || matricNumber == 'Loading...'
          ? ''
          : matricNumber,
    );

    final bool dark = isDark(context);
    final Color accent = accentColor(context);
    final Color text = textColor(context);
    final Color secondary = secondaryTextColor(context);

    final Map<String, String>? result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: dark ? const Color(0xFF07150D) : Colors.white,
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
                  color: accent.withOpacity(.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.edit_outlined,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Edit Profile',
                  style: GoogleFonts.poppins(
                    color: text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Update your name and matric number.',
                  style: GoogleFonts.poppins(
                    color: secondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.words,
                  style: GoogleFonts.poppins(
                    color: text,
                    fontSize: 13,
                  ),
                  decoration: _editInputDecoration(
                    context,
                    label: 'Full Name',
                    icon: Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: matricController,
                  maxLength: 40,
                  style: GoogleFonts.poppins(
                    color: text,
                    fontSize: 13,
                  ),
                  decoration: _editInputDecoration(
                    context,
                    label: 'Matric Number',
                    icon: Icons.badge_outlined,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accent.withOpacity(.15),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: accent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your login email cannot be changed from this profile page.',
                          style: GoogleFonts.poppins(
                            color: secondary,
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
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                'CANCEL',
                style: GoogleFonts.poppins(
                  color: secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                final String name = nameController.text.trim();

                final String matric = matricController.text.trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).hideCurrentSnackBar();

                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Please enter your full name.',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );

                  return;
                }

                if (matric.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).hideCurrentSnackBar();

                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Please enter your matric number.',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );

                  return;
                }

                Navigator.pop(
                  dialogContext,
                  {
                    'fullName': name,
                    'matricNumber': matric,
                  },
                );
              },
              child: Text(
                'SAVE',
                style: GoogleFonts.poppins(
                  color: accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    matricController.dispose();

    if (result == null) {
      return;
    }

    final String newFullName = result['fullName']?.trim() ?? '';

    final String newMatricNumber = result['matricNumber']?.trim() ?? '';

    if (newFullName.isEmpty || newMatricNumber.isEmpty) {
      return;
    }

    if (newFullName == fullName && newMatricNumber == matricNumber) {
      return;
    }

    if (!mounted) return;

    setState(() {
      isUpdatingProfile = true;
    });

    try {
      await _authService.updateUserProfile(
        fullName: newFullName,
        matricNumber: newMatricNumber,
      );

      if (!mounted) return;

      setState(() {
        fullName = newFullName;
        matricNumber = newMatricNumber;
      });

      _showMessage(
        'Profile updated successfully.',
      );
    } catch (e) {
      debugPrint('Profile update error: $e');

      if (!mounted) return;

      _showMessage(
        'Unable to update your profile. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          isUpdatingProfile = false;
        });
      }
    }
  }

  // =========================================================
  // EDIT INPUT DECORATION
  // =========================================================

  InputDecoration _editInputDecoration(
    BuildContext context, {
    required String label,
    required IconData icon,
  }) {
    final bool dark = isDark(context);
    final Color accent = accentColor(context);

    return InputDecoration(
      labelText: label,
      counterText: '',
      labelStyle: GoogleFonts.poppins(
        color: secondaryTextColor(context),
        fontSize: 12,
      ),
      prefixIcon: Icon(
        icon,
        color: accent,
      ),
      filled: true,
      fillColor: dark ? Colors.white.withOpacity(.05) : const Color(0xFFF3F8F5),
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
    );
  }

  // =========================================================
  // PROFILE HEADER
  // =========================================================

  Widget profileHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: borderColor(context),
        ),
        boxShadow: [
          BoxShadow(
            color: darkPrimary.withOpacity(.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
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
                  color: darkPrimary.withOpacity(.20),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      isDark(context) ? const Color(0xFF07150D) : Colors.white,
                ),
                child: Icon(
                  Icons.person,
                  size: 48,
                  color: accentColor(context),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            fullName,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: textColor(context),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            email,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: secondaryTextColor(context),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: primaryColor(context).withOpacity(.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'SpeakWise User',
              style: GoogleFonts.poppins(
                color: accentColor(context),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // PROFILE TILE
  // =========================================================

  Widget profileTile(
    BuildContext context,
    IconData icon,
    String title,
    String value,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor(context),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 5,
        ),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accentColor(context).withOpacity(.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: accentColor(context),
            size: 21,
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            color: secondaryTextColor(context),
            fontSize: 11,
          ),
        ),
        subtitle: Text(
          value,
          style: GoogleFonts.poppins(
            color: textColor(context),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // STAT CARD
  // =========================================================

  Widget statCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: cardColor(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: borderColor(context),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: accentColor(context),
              size: 23,
            ),
            const SizedBox(height: 7),
            Text(
              value,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: textColor(context),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: secondaryTextColor(context),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> _logout() async {
    if (isLoggingOut) {
      return;
    }

    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final bool dark = isDark(context);
        final Color accent = accentColor(context);

        return AlertDialog(
          backgroundColor: dark ? const Color(0xFF07150D) : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'Logout?',
            style: GoogleFonts.poppins(
              color: textColor(context),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to logout from SpeakWise?',
            style: GoogleFonts.poppins(
              color: secondaryTextColor(context),
              fontSize: 12,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(
                'CANCEL',
                style: GoogleFonts.poppins(
                  color: secondaryTextColor(context),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(
                'LOGOUT',
                style: GoogleFonts.poppins(
                  color: accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !mounted) {
      return;
    }

    setState(() {
      isLoggingOut = true;
    });

    try {
      await _authService.logout();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Logout error: $e');

      if (!mounted) return;

      setState(() {
        isLoggingOut = false;
      });

      _showMessage(
        'Unable to logout. Please try again.',
        isError: true,
      );
    }
  }

  // =========================================================
  // REFRESH PROFILE
  // =========================================================

  Future<void> _refreshProfile() async {
    if (_authService.currentUser == null) {
      return;
    }

    await _loadUserData();
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: isUpdatingProfile || isLoggingOut
              ? null
              : () {
                  Navigator.pop(context);
                },
          icon: Icon(
            Icons.arrow_back_rounded,
            color: textColor(context),
          ),
        ),
        title: Text(
          'My Profile',
          style: GoogleFonts.poppins(
            color: textColor(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: ThemeToggle(
                isDark: ThemeController.isDark,
                onTap: isUpdatingProfile || isLoggingOut
                    ? () {}
                    : ThemeController.toggleTheme,
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool desktop = constraints.maxWidth >= 900;

          return RefreshIndicator(
            color: accentColor(context),
            onRefresh: _refreshProfile,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: desktop ? 60 : 20,
                vertical: 20,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 850,
                  ),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Profile',
                              style: GoogleFonts.poppins(
                                color: textColor(context),
                                fontSize: desktop ? 30 : 25,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Manage your SpeakWise account and view your progress.',
                              style: GoogleFonts.poppins(
                                color: secondaryTextColor(
                                  context,
                                ),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 25),

                      if (isLoading)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: 20,
                          ),
                          child: LinearProgressIndicator(
                            minHeight: 3,
                            borderRadius: BorderRadius.circular(10),
                            color: accentColor(context),
                          ),
                        ),

                      profileHeader(context),

                      const SizedBox(height: 20),

                      // =================================================
                      // PERFORMANCE STATS
                      // =================================================

                      Row(
                        children: [
                          statCard(
                            context,
                            'Analyses',
                            analyses.toString(),
                            Icons.analytics_outlined,
                          ),
                          const SizedBox(width: 10),
                          statCard(
                            context,
                            'Highest Score',
                            highestScore.toString(),
                            Icons.star_outline_rounded,
                          ),
                          const SizedBox(width: 10),
                          statCard(
                            context,
                            'Level',
                            level,
                            Icons.workspace_premium_outlined,
                          ),
                        ],
                      ),

                      const SizedBox(height: 25),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Account Information',
                          style: GoogleFonts.poppins(
                            color: textColor(context),
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      profileTile(
                        context,
                        Icons.badge_outlined,
                        'Matric Number',
                        matricNumber,
                      ),

                      profileTile(
                        context,
                        Icons.email_outlined,
                        'Email',
                        email,
                      ),

                      const SizedBox(height: 15),

                      // =================================================
                      // EDIT PROFILE
                      // =================================================

                      GradientButton(
                        text: isUpdatingProfile
                            ? 'UPDATING PROFILE...'
                            : 'EDIT PROFILE',
                        icon: isUpdatingProfile
                            ? Icons.hourglass_top_rounded
                            : Icons.edit_outlined,
                        onPressed:
                            isLoading || isUpdatingProfile || isLoggingOut
                                ? () {}
                                : _editProfile,
                      ),

                      const SizedBox(height: 12),

                      // =================================================
                      // LOGOUT
                      // =================================================

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: accentColor(context),
                            side: BorderSide(
                              color: accentColor(context),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed:
                              isLoading || isUpdatingProfile || isLoggingOut
                                  ? null
                                  : _logout,
                          icon: isLoggingOut
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: accentColor(context),
                                  ),
                                )
                              : const Icon(
                                  Icons.logout_rounded,
                                ),
                          label: Text(
                            isLoggingOut ? 'LOGGING OUT...' : 'LOGOUT',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      Text(
                        'SpeakWise AI Speech Assistant',
                        style: GoogleFonts.poppins(
                          color: secondaryTextColor(context),
                          fontSize: 10,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        'Improve your communication, one practice at a time.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: secondaryTextColor(context),
                          fontSize: 10,
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
