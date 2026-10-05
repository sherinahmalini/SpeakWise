import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'dashboard.dart';
import 'register_screen.dart';
import '../widgets/theme_toggle.dart';
import '../theme/theme_controller.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final AuthService _authService = AuthService();

  bool obscurePassword = true;
  bool isLoading = false;
  bool isGoogleLoading = false;
  bool isCardHovered = false;
  bool isLoginHovered = false;
  bool isRegisterHovered = false;

  static const Color darkPrimary = Color(0xFF01411C);
  static const Color lightPrimary = Color(0xFF9AF0BF);

  bool get _busy => isLoading || isGoogleLoading;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // =========================================================
  // EMAIL VALIDATION
  // =========================================================

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email);
  }

  // =========================================================
  // LOGIN WITH EMAIL + PASSWORD
  // =========================================================

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    final String email = emailController.text.trim();
    final String password = passwordController.text;

    if (email.isEmpty) {
      _showError('Please enter your email.');
      return;
    }

    if (!_isValidEmail(email)) {
      _showError('Please enter a valid email address.');
      return;
    }

    if (password.isEmpty) {
      _showError('Please enter your password.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final UserCredential? credential = await _authService.login(
        email: email,
        password: password,
      );

      if (!mounted) return;

      final User? user = FirebaseAuth.instance.currentUser;

      if (credential?.user == null || user == null) {
        _showError('Unable to sign in. Please try again.');
        return;
      }

      final bool usesPasswordProvider = user.providerData.any(
        (provider) => provider.providerId == 'password',
      );

      if (usesPasswordProvider && !user.emailVerified) {
        setState(() {
          isLoading = false;
        });

        await _showEmailVerificationDialog(
          email: user.email ?? email,
        );

        return;
      }

      _openDashboard();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showError(_firebaseErrorMessage(e));
    } catch (_) {
      if (!mounted) return;
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // =========================================================
  // GOOGLE SIGN-IN
  // =========================================================

  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus();

    if (_busy) return;

    setState(() {
      isGoogleLoading = true;
    });

    try {
      final UserCredential? credential = await _authService.signInWithGoogle();

      if (!mounted) return;

      if (credential?.user == null) {
        return;
      }

      final bool needsMatricNumber =
          await _authService.googleUserNeedsMatricNumber();

      if (!mounted) return;

      if (needsMatricNumber) {
        setState(() {
          isGoogleLoading = false;
        });

        final bool completed = await _showGoogleMatricNumberDialog();

        if (!mounted) return;

        if (!completed) {
          await _authService.logout();
          return;
        }
      }

      if (!mounted) return;

      _openDashboard();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showError(_firebaseErrorMessage(e));
    } catch (e) {
      if (!mounted) return;

      final String message = e.toString();

      // If the user simply closed/cancelled Google's account
      // chooser, don't show an alarming error message.
      if (message.toLowerCase().contains('canceled') ||
          message.toLowerCase().contains('cancelled')) {
        return;
      }

      _showError(
        message.replaceFirst('Exception: ', '').trim(),
      );
    } finally {
      if (mounted) {
        setState(() {
          isGoogleLoading = false;
        });
      }
    }
  }

  // =========================================================
  // GOOGLE MATRIC NUMBER DIALOG
  // =========================================================

  Future<bool> _showGoogleMatricNumberDialog() async {
    final TextEditingController matricController = TextEditingController();

    bool saving = false;
    String? errorText;

    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final bool dark = Theme.of(dialogContext).brightness == Brightness.dark;

        final Color accent = dark ? lightPrimary : darkPrimary;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              final String matric = matricController.text.trim();

              if (matric.isEmpty) {
                setDialogState(() {
                  errorText = 'Please enter your matric number.';
                });
                return;
              }

              setDialogState(() {
                saving = true;
                errorText = null;
              });

              try {
                await _authService.completeGoogleProfile(
                  matricNumber: matric,
                );

                if (!dialogContext.mounted) return;

                Navigator.of(dialogContext).pop(true);
              } catch (_) {
                if (!dialogContext.mounted) return;

                setDialogState(() {
                  saving = false;
                  errorText =
                      'Unable to save your matric number. Please try again.';
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.school_outlined,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Complete your profile',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Google account is connected. '
                      'Enter your matric number to finish setting up SpeakWise.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: matricController,
                      enabled: !saving,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!saving) {
                          save();
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Matric Number',
                        hintText: 'Enter your matric number',
                        errorText: errorText,
                        prefixIcon: Icon(
                          Icons.badge_outlined,
                          color: accent,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: accent,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop(false);
                        },
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(),
                  ),
                ),
                ElevatedButton(
                  onPressed: saving ? null : save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: dark ? darkPrimary : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Continue',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    matricController.dispose();

    return result == true;
  }

  // =========================================================
  // EMAIL VERIFICATION DIALOG
  // =========================================================

  Future<void> _showEmailVerificationDialog({
    required String email,
  }) async {
    bool checking = false;
    bool sending = false;
    String? statusMessage;
    bool statusIsError = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final bool dark = Theme.of(dialogContext).brightness == Brightness.dark;

        final Color accent = dark ? lightPrimary : darkPrimary;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> checkVerification() async {
              setDialogState(() {
                checking = true;
                statusMessage = null;
              });

              try {
                final bool verified = await _authService.isEmailVerified();

                if (!dialogContext.mounted) return;

                if (verified) {
                  Navigator.of(dialogContext).pop();

                  if (!mounted) return;

                  _showSuccess(
                    'Email verified successfully.',
                  );

                  _openDashboard();
                  return;
                }

                setDialogState(() {
                  checking = false;
                  statusIsError = true;
                  statusMessage = 'Your email is not verified yet. '
                      'Open the verification email, click the link, '
                      'then come back and press "I Verified My Email".';
                });
              } catch (_) {
                if (!dialogContext.mounted) return;

                setDialogState(() {
                  checking = false;
                  statusIsError = true;
                  statusMessage = 'Unable to check verification right now.';
                });
              }
            }

            Future<void> resend() async {
              setDialogState(() {
                sending = true;
                statusMessage = null;
              });

              try {
                await _authService.sendEmailVerification();

                if (!dialogContext.mounted) return;

                setDialogState(() {
                  sending = false;
                  statusIsError = false;
                  statusMessage = 'Verification email sent again. '
                      'Please check your inbox and spam folder.';
                });
              } on FirebaseAuthException catch (e) {
                if (!dialogContext.mounted) return;

                setDialogState(() {
                  sending = false;
                  statusIsError = true;
                  statusMessage = _firebaseErrorMessage(e);
                });
              } catch (_) {
                if (!dialogContext.mounted) return;

                setDialogState(() {
                  sending = false;
                  statusIsError = true;
                  statusMessage = 'Unable to resend the verification email.';
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.mark_email_unread_outlined,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Verify your email',
                      style: GoogleFonts.poppins(
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'We need to confirm that this email belongs to you.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(.08),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: accent.withOpacity(.20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            color: accent,
                            size: 19,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              email,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '1. Open your email inbox.\n'
                      '2. Find the Firebase/SpeakWise verification email.\n'
                      '3. Click the verification link.\n'
                      '4. Return here and confirm below.',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        height: 1.7,
                      ),
                    ),
                    if (statusMessage != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: statusIsError
                              ? Colors.red.withOpacity(.08)
                              : accent.withOpacity(.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusMessage!,
                          style: GoogleFonts.poppins(
                            color: statusIsError ? Colors.red.shade400 : accent,
                            fontSize: 10.5,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: checking || sending
                      ? null
                      : () async {
                          Navigator.of(dialogContext).pop();
                          await _authService.logout();
                        },
                  child: Text(
                    'Back to Login',
                    style: GoogleFonts.poppins(),
                  ),
                ),
                TextButton(
                  onPressed: checking || sending ? null : resend,
                  child: sending
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Resend Email',
                          style: GoogleFonts.poppins(
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                ElevatedButton(
                  onPressed: checking || sending ? null : checkVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: dark ? darkPrimary : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'I Verified My Email',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================
  // FORGOT PASSWORD
  // =========================================================

  Future<void> _forgotPassword() async {
    final String email = emailController.text.trim();

    if (email.isEmpty) {
      _showError('Please enter your email first.');
      return;
    }

    if (!_isValidEmail(email)) {
      _showError('Please enter a valid email address.');
      return;
    }

    try {
      await _authService.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;

      _showSuccess(
        'Password reset email sent. Check your inbox.',
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showError(_firebaseErrorMessage(e));
    } catch (_) {
      if (!mounted) return;
      _showError(
        'Unable to send reset email. Please try again.',
      );
    }
  }

  // =========================================================
  // OPEN DASHBOARD
  // =========================================================

  void _openDashboard() {
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const Dashboard(),
      ),
      (route) => false,
    );
  }

  // =========================================================
  // FIREBASE ERROR MESSAGE
  // =========================================================

  String _firebaseErrorMessage(
    FirebaseAuthException e,
  ) {
    switch (e.code) {
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Incorrect email or password.';

      case 'user-not-found':
        return 'No account found with this email.';

      case 'wrong-password':
        return 'Incorrect email or password.';

      case 'invalid-email':
        return 'Please enter a valid email address.';

      case 'user-disabled':
        return 'This account has been disabled.';

      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';

      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';

      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase.';

      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using another sign-in method.';

      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  // =========================================================
  // SNACKBARS
  // =========================================================

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(fontSize: 12),
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(fontSize: 12),
        ),
        backgroundColor: darkPrimary,
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

    final Color primary = dark ? darkPrimary : lightPrimary;

    final Color accent = dark ? lightPrimary : darkPrimary;

    final Color background =
        dark ? const Color(0xFF050A07) : const Color(0xFFF7FBF8);

    final Color cardColor = dark ? const Color(0xFF0B1510) : Colors.white;

    final Color textColor = dark ? Colors.white : const Color(0xFF17201A);

    final Color secondaryText = dark ? Colors.white70 : const Color(0xFF5F6B63);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool wide = constraints.maxWidth >= 800;

            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 1000,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 60 : 24,
                      vertical: 30,
                    ),
                    child: Column(
                      children: [
                        _topBar(
                          textColor,
                          primary,
                          accent,
                        ),
                        const SizedBox(height: 45),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: _welcomeSection(
                                  textColor,
                                  secondaryText,
                                  primary,
                                  accent,
                                ),
                              ),
                              const SizedBox(width: 55),
                              Expanded(
                                child: _loginCard(
                                  context,
                                  cardColor,
                                  textColor,
                                  secondaryText,
                                  dark,
                                  primary,
                                  accent,
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _welcomeSection(
                                textColor,
                                secondaryText,
                                primary,
                                accent,
                              ),
                              const SizedBox(height: 30),
                              _loginCard(
                                context,
                                cardColor,
                                textColor,
                                secondaryText,
                                dark,
                                primary,
                                accent,
                              ),
                            ],
                          ),
                        const SizedBox(height: 35),
                        Text(
                          'SpeakWise • AI Presentation Coach',
                          style: GoogleFonts.poppins(
                            color: secondaryText,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // =========================================================
  // TOP BAR
  // =========================================================

  Widget _topBar(
    Color textColor,
    Color primary,
    Color accent,
  ) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: primary.withOpacity(.12),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: accent.withOpacity(.35),
            ),
          ),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'SpeakWise',
          style: GoogleFonts.poppins(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        ThemeToggle(
          isDark: ThemeController.isDark,
          onTap: _busy ? () {} : ThemeController.toggleTheme,
        ),
      ],
    );
  }

  // =========================================================
  // WELCOME SECTION
  // =========================================================

  Widget _welcomeSection(
    Color textColor,
    Color secondaryText,
    Color primary,
    Color accent,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 125,
          height: 125,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: primary.withOpacity(.14),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: accent.withOpacity(.35),
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(.08),
                blurRadius: 25,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 30),
        Text(
          'Welcome back.',
          style: GoogleFonts.poppins(
            color: textColor,
            fontSize: 34,
            fontWeight: FontWeight.bold,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Practice smarter.\nPresent with confidence.',
          style: GoogleFonts.poppins(
            color: accent,
            fontSize: 21,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Improve your communication and speech skills '
          'with AI-powered presentation practice and feedback.',
          style: GoogleFonts.poppins(
            color: secondaryText,
            fontSize: 13,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 25),
        Row(
          children: [
            _feature(
              Icons.mic_none_rounded,
              'Speech',
              secondaryText,
              accent,
            ),
            const SizedBox(width: 18),
            _feature(
              Icons.psychology_outlined,
              'AI Practice',
              secondaryText,
              accent,
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================
  // FEATURE
  // =========================================================

  Widget _feature(
    IconData icon,
    String title,
    Color secondaryText,
    Color accent,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: accent,
          size: 20,
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.poppins(
            color: secondaryText,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // LOGIN CARD
  // =========================================================

  Widget _loginCard(
    BuildContext context,
    Color cardColor,
    Color textColor,
    Color secondaryText,
    bool dark,
    Color primary,
    Color accent,
  ) {
    return MouseRegion(
      onEnter: (_) {
        if (!mounted) return;
        setState(() {
          isCardHovered = true;
        });
      },
      onExit: (_) {
        if (!mounted) return;
        setState(() {
          isCardHovered = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.all(25),
        transform: Matrix4.identity()
          ..translate(
            0.0,
            isCardHovered ? -5.0 : 0.0,
          ),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isCardHovered
                ? accent
                : dark
                    ? primary.withOpacity(.65)
                    : darkPrimary.withOpacity(.15),
            width: isCardHovered ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(
                isCardHovered ? .25 : .07,
              ),
              blurRadius: isCardHovered ? 40 : 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sign in',
              style: GoogleFonts.poppins(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Enter your account details to continue.',
              style: GoogleFonts.poppins(
                color: secondaryText,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 25),

            _fieldLabel('Email', textColor),
            const SizedBox(height: 8),

            _textField(
              controller: emailController,
              hint: 'Enter your email',
              icon: Icons.email_outlined,
              textColor: textColor,
              dark: dark,
              accent: accent,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 18),

            _fieldLabel('Password', textColor),
            const SizedBox(height: 8),

            _textField(
              controller: passwordController,
              hint: 'Enter your password',
              icon: Icons.lock_outline_rounded,
              textColor: textColor,
              dark: dark,
              accent: accent,
              enabled: !_busy,
              obscureText: obscurePassword,
              onSubmitted: (_) {
                if (!_busy) {
                  _login();
                }
              },
              suffix: IconButton(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: secondaryText,
                  size: 20,
                ),
              ),
            ),

            const SizedBox(height: 8),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : _forgotPassword,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Forgot Password?',
                  style: GoogleFonts.poppins(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            _hoverButton(
              text: 'LOGIN',
              icon: Icons.login_rounded,
              isHovered: isLoginHovered,
              primary: primary,
              dark: dark,
              loading: isLoading,
              disabled: _busy,
              onHoverChanged: (value) {
                if (!mounted) return;
                setState(() {
                  isLoginHovered = value;
                });
              },
              onPressed: _login,
            ),

            const SizedBox(height: 22),

            _divider(
              secondaryText,
            ),

            const SizedBox(height: 22),

            // GOOGLE SIGN-IN
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: _busy ? null : _signInWithGoogle,
                style: OutlinedButton.styleFrom(
                  foregroundColor: textColor,
                  side: BorderSide(
                    color: dark ? Colors.white24 : Colors.black12,
                  ),
                  backgroundColor:
                      dark ? const Color(0xFF101812) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isGoogleLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: accent,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                12,
                              ),
                            ),
                            child: const Text(
                              'G',
                              style: TextStyle(
                                color: Color(0xFF4285F4),
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 11),
                          Text(
                            'Continue with Google',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 22),

            Center(
              child: Column(
                children: [
                  Text(
                    "Don't have an account?",
                    style: GoogleFonts.poppins(
                      color: secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  MouseRegion(
                    onEnter: (_) {
                      if (!mounted) return;
                      setState(() {
                        isRegisterHovered = true;
                      });
                    },
                    onExit: (_) {
                      if (!mounted) return;
                      setState(() {
                        isRegisterHovered = false;
                      });
                    },
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              );
                            },
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(
                          milliseconds: 200,
                        ),
                        style: GoogleFonts.poppins(
                          color: accent,
                          fontWeight: FontWeight.bold,
                          fontSize: isRegisterHovered ? 14 : 13,
                        ),
                        child: const Text(
                          'Create New Account',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // DIVIDER
  // =========================================================

  Widget _divider(
    Color secondaryText,
  ) {
    return Row(
      children: [
        const Expanded(
          child: Divider(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          child: Text(
            'OR',
            style: GoogleFonts.poppins(
              color: secondaryText,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Expanded(
          child: Divider(),
        ),
      ],
    );
  }

  // =========================================================
  // HOVER BUTTON
  // =========================================================

  Widget _hoverButton({
    required String text,
    required IconData icon,
    required bool isHovered,
    required Color primary,
    required bool dark,
    required bool loading,
    required bool disabled,
    required ValueChanged<bool> onHoverChanged,
    required VoidCallback onPressed,
  }) {
    final Color buttonTextColor = dark ? Colors.white : darkPrimary;

    return MouseRegion(
      onEnter: (_) {
        if (!disabled) {
          onHoverChanged(true);
        }
      },
      onExit: (_) => onHoverChanged(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (isHovered && !disabled)
              BoxShadow(
                color: primary.withOpacity(.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: ElevatedButton(
          onPressed: disabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: isHovered ? primary.withOpacity(.82) : primary,
            disabledBackgroundColor: primary.withOpacity(.55),
            foregroundColor: buttonTextColor,
            elevation: isHovered ? 5 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: loading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      buttonTextColor,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: buttonTextColor,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      text,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        letterSpacing: .5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // =========================================================
  // FIELD LABEL
  // =========================================================

  Widget _fieldLabel(
    String text,
    Color color,
  ) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // =========================================================
  // TEXT FIELD
  // =========================================================

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color textColor,
    required bool dark,
    required Color accent,
    required bool enabled,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      style: TextStyle(
        color: textColor,
      ),
      decoration: _inputDecoration(
        hint: hint,
        icon: icon,
        dark: dark,
        accent: accent,
        suffix: suffix,
      ),
    );
  }

  // =========================================================
  // INPUT DECORATION
  // =========================================================

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required bool dark,
    required Color accent,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: dark ? Colors.white38 : Colors.black38,
      ),
      prefixIcon: Icon(
        icon,
        color: accent,
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: dark ? const Color(0xFF101812) : const Color(0xFFF3F8F5),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: dark ? Colors.white12 : darkPrimary.withOpacity(.15),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: accent,
          width: 1.5,
        ),
      ),
    );
  }
}
