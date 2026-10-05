import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'dashboard.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';
import '../widgets/theme_toggle.dart';
import '../theme/theme_controller.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController matricController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  final AuthService _authService = AuthService();

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  bool isLoading = false;
  bool isGoogleLoading = false;

  bool isCardHovered = false;
  bool isRegisterHovered = false;

  static const Color darkPrimary = Color(0xFF01411C);
  static const Color lightPrimary = Color(0xFF9AF0BF);

  bool get _busy => isLoading || isGoogleLoading;

  @override
  void dispose() {
    fullNameController.dispose();
    matricController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // =========================================================
  // VALIDATION
  // =========================================================

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email);
  }

  bool _hasUppercase(String value) {
    return value.contains(RegExp(r'[A-Z]'));
  }

  bool _hasLowercase(String value) {
    return value.contains(RegExp(r'[a-z]'));
  }

  bool _hasNumber(String value) {
    return value.contains(RegExp(r'[0-9]'));
  }

  bool _hasSpecialCharacter(String value) {
    // Any character that is not a letter, number, or whitespace
    // counts as a special character (for example: @, !, #, $, %, _).
    return RegExp(r'[^A-Za-z0-9\s]').hasMatch(value);
  }

  bool _isStrongPassword(String value) {
    return value.length >= 8 &&
        _hasUppercase(value) &&
        _hasLowercase(value) &&
        _hasNumber(value) &&
        _hasSpecialCharacter(value);
  }

  // =========================================================
  // EMAIL REGISTRATION
  // =========================================================

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    final String fullName = fullNameController.text.trim();

    final String matricNumber = matricController.text.trim();

    final String email = emailController.text.trim();

    final String password = passwordController.text;

    final String confirmPassword = confirmPasswordController.text;

    if (fullName.isEmpty) {
      _showError('Please enter your full name.');
      return;
    }

    if (matricNumber.isEmpty) {
      _showError('Please enter your matric number.');
      return;
    }

    if (email.isEmpty) {
      _showError('Please enter your email.');
      return;
    }

    if (!_isValidEmail(email)) {
      _showError('Please enter a valid email address.');
      return;
    }

    if (password.isEmpty) {
      _showError('Please enter a password.');
      return;
    }

    if (!_isStrongPassword(password)) {
      _showError(
        'Password must be at least 8 characters and include '
        'uppercase, lowercase, number and special character.',
      );
      return;
    }

    if (confirmPassword.isEmpty) {
      _showError('Please confirm your password.');
      return;
    }

    if (password != confirmPassword) {
      _showError('Passwords do not match.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final UserCredential? credential = await _authService.register(
        fullName: fullName,
        matricNumber: matricNumber,
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (credential?.user == null) {
        _showError(
          'Unable to create your account. Please try again.',
        );
        return;
      }

      // Registration sends the verification email in AuthService.
      // Keep the account authenticated temporarily so the user
      // can resend/check verification from the dialog.
      setState(() {
        isLoading = false;
      });

      await _showVerificationDialog(
        email: credential!.user!.email ?? email,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      _showError(
        _firebaseErrorMessage(e),
      );
    } catch (_) {
      if (!mounted) return;

      _showError(
        'Unable to create your account. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // =========================================================
  // GOOGLE REGISTRATION
  // =========================================================

  Future<void> _continueWithGoogle() async {
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

      _showSuccess(
        'Google account connected successfully.',
      );

      _openDashboard();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      _showError(
        _firebaseErrorMessage(e),
      );
    } catch (e) {
      if (!mounted) return;

      final String message =
          e.toString().replaceFirst('Exception: ', '').trim();

      final String lower = message.toLowerCase();

      if (lower.contains('cancelled') || lower.contains('canceled')) {
        return;
      }

      _showError(
        message.isEmpty ? 'Google Sign-In failed. Please try again.' : message,
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
  // GOOGLE MATRIC DIALOG
  // =========================================================

  Future<bool> _showGoogleMatricNumberDialog() async {
    final TextEditingController controller = TextEditingController();

    bool saving = false;
    String? errorText;

    final bool? completed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final bool dark = Theme.of(dialogContext).brightness == Brightness.dark;

        final Color accent = dark ? lightPrimary : darkPrimary;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              final String matric = controller.text.trim();

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

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop(true);
              } catch (_) {
                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  saving = false;
                  errorText = 'Unable to save your matric number. '
                      'Please try again.';
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
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(.10),
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 410,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Google has verified your account. '
                      'SpeakWise only needs your matric number '
                      'to complete your student profile.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: controller,
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

    controller.dispose();

    return completed == true;
  }

  // =========================================================
  // VERIFICATION DIALOG
  // =========================================================

  Future<void> _showVerificationDialog({
    required String email,
  }) async {
    bool checking = false;
    bool sending = false;

    bool statusIsError = false;
    String? statusMessage;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final bool dark = Theme.of(dialogContext).brightness == Brightness.dark;

        final Color accent = dark ? lightPrimary : darkPrimary;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> resend() async {
              setDialogState(() {
                sending = true;
                statusMessage = null;
              });

              try {
                await _authService.sendEmailVerification();

                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  sending = false;
                  statusIsError = false;
                  statusMessage = 'Verification email sent again. '
                      'Please check your inbox and spam folder.';
                });
              } on FirebaseAuthException catch (e) {
                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  sending = false;
                  statusIsError = true;
                  statusMessage = _firebaseErrorMessage(e);
                });
              } catch (_) {
                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  sending = false;
                  statusIsError = true;
                  statusMessage = 'Unable to resend the verification email.';
                });
              }
            }

            Future<void> checkVerification() async {
              setDialogState(() {
                checking = true;
                statusMessage = null;
              });

              try {
                final bool verified = await _authService.isEmailVerified();

                if (!dialogContext.mounted) {
                  return;
                }

                if (verified) {
                  Navigator.of(dialogContext).pop();

                  if (!mounted) return;

                  _showSuccess(
                    'Email verified. Welcome to SpeakWise!',
                  );

                  _openDashboard();
                  return;
                }

                setDialogState(() {
                  checking = false;
                  statusIsError = true;
                  statusMessage = 'Your email is not verified yet. '
                      'Click the verification link in your email, '
                      'then try again.';
                });
              } catch (_) {
                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  checking = false;
                  statusIsError = true;
                  statusMessage = 'Unable to check verification right now.';
                });
              }
            }

            Future<void> backToLogin() async {
              Navigator.of(dialogContext).pop();

              try {
                await _authService.logout();
              } catch (_) {
                // Navigation should still continue.
              }

              if (!mounted) return;

              _openLogin();
            }

            return AlertDialog(
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
                      Icons.mark_email_unread_outlined,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Check your email',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your SpeakWise account has been created. '
                      'A verification link was sent to:',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 13),
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
                    const SizedBox(height: 16),
                    Text(
                      'Open the email and click the verification '
                      'link. Then return to SpeakWise and press '
                      '"I Verified My Email".',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        height: 1.6,
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
                  onPressed: checking || sending ? null : backToLogin,
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
  // NAVIGATION
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

  void _openLogin() {
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  // =========================================================
  // FIREBASE ERRORS
  // =========================================================

  String _firebaseErrorMessage(
    FirebaseAuthException e,
  ) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists with this email.';

      case 'invalid-email':
        return 'Please enter a valid email address.';

      case 'weak-password':
        return 'Your password is too weak.';

      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase.';

      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';

      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';

      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using another sign-in method.';

      case 'credential-already-in-use':
        return 'This Google account is already connected to another account.';

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
          style: GoogleFonts.poppins(
            fontSize: 12,
          ),
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
          style: GoogleFonts.poppins(
            fontSize: 12,
          ),
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
            final bool wide = constraints.maxWidth >= 900;

            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 1100,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 60 : 24,
                      vertical: 28,
                    ),
                    child: Column(
                      children: [
                        _topBar(
                          textColor,
                          primary,
                          accent,
                        ),
                        const SizedBox(height: 38),
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
                                child: _registerCard(
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
                              _registerCard(
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
          ),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Create your account.',
          style: GoogleFonts.poppins(
            color: textColor,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          'Build confidence.\nSpeak with impact.',
          style: GoogleFonts.poppins(
            color: accent,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Join SpeakWise and improve your presentation '
          'skills through AI-powered practice, feedback '
          'and personalized assessment.',
          style: GoogleFonts.poppins(
            color: secondaryText,
            fontSize: 13,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // REGISTER CARD
  // =========================================================

  Widget _registerCard(
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
            isCardHovered ? -4.0 : 0.0,
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
                isCardHovered ? .22 : .07,
              ),
              blurRadius: isCardHovered ? 38 : 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create account',
              style: GoogleFonts.poppins(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Enter your student details to get started.',
              style: GoogleFonts.poppins(
                color: secondaryText,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
            _fieldLabel(
              'Full Name',
              textColor,
            ),
            const SizedBox(height: 7),
            _textField(
              controller: fullNameController,
              hint: 'Enter your full name',
              icon: Icons.person_outline,
              textColor: textColor,
              dark: dark,
              accent: accent,
              enabled: !_busy,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 15),
            _fieldLabel(
              'Matric Number',
              textColor,
            ),
            const SizedBox(height: 7),
            _textField(
              controller: matricController,
              hint: 'Enter your matric number',
              icon: Icons.badge_outlined,
              textColor: textColor,
              dark: dark,
              accent: accent,
              enabled: !_busy,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 15),
            _fieldLabel(
              'Email',
              textColor,
            ),
            const SizedBox(height: 7),
            _textField(
              controller: emailController,
              hint: 'Enter your email',
              icon: Icons.email_outlined,
              textColor: textColor,
              dark: dark,
              accent: accent,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 15),
            _fieldLabel(
              'Password',
              textColor,
            ),
            const SizedBox(height: 7),
            _textField(
              controller: passwordController,
              hint: 'Create a strong password',
              icon: Icons.lock_outline_rounded,
              textColor: textColor,
              dark: dark,
              accent: accent,
              enabled: !_busy,
              obscureText: obscurePassword,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                setState(() {});
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
            const SizedBox(height: 10),
            _passwordRequirements(
              passwordController.text,
              secondaryText,
              accent,
            ),
            const SizedBox(height: 15),
            _fieldLabel(
              'Confirm Password',
              textColor,
            ),
            const SizedBox(height: 7),
            _textField(
              controller: confirmPasswordController,
              hint: 'Confirm your password',
              icon: Icons.lock_reset_outlined,
              textColor: textColor,
              dark: dark,
              accent: accent,
              enabled: !_busy,
              obscureText: obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!_busy) {
                  _register();
                }
              },
              suffix: IconButton(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() {
                          obscureConfirmPassword = !obscureConfirmPassword;
                        });
                      },
                icon: Icon(
                  obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: secondaryText,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _busy ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: dark ? Colors.white : darkPrimary,
                  disabledBackgroundColor: primary.withOpacity(.55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: isLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: dark ? Colors.white : darkPrimary,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 20,
                          ),
                          const SizedBox(width: 9),
                          Text(
                            'CREATE ACCOUNT',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              letterSpacing: .4,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 22),
            _divider(
              secondaryText,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: _busy ? null : _continueWithGoogle,
                style: OutlinedButton.styleFrom(
                  foregroundColor: textColor,
                  backgroundColor:
                      dark ? const Color(0xFF101812) : Colors.white,
                  side: BorderSide(
                    color: dark ? Colors.white24 : Colors.black12,
                  ),
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
            const SizedBox(height: 18),
            Center(
              child: Column(
                children: [
                  Text(
                    'Already have an account?',
                    style: GoogleFonts.poppins(
                      color: secondaryText,
                      fontSize: 12,
                    ),
                  ),
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
                              Navigator.pop(
                                context,
                              );
                            },
                      child: Text(
                        'Back to Login',
                        style: GoogleFonts.poppins(
                          color: accent,
                          fontWeight: FontWeight.bold,
                          fontSize: isRegisterHovered ? 14 : 13,
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
  // PASSWORD REQUIREMENTS
  // =========================================================

  Widget _passwordRequirements(
    String password,
    Color secondaryText,
    Color accent,
  ) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        _requirementChip(
          '8+ characters',
          password.length >= 8,
          secondaryText,
          accent,
        ),
        _requirementChip(
          'Uppercase',
          _hasUppercase(password),
          secondaryText,
          accent,
        ),
        _requirementChip(
          'Lowercase',
          _hasLowercase(password),
          secondaryText,
          accent,
        ),
        _requirementChip(
          'Number',
          _hasNumber(password),
          secondaryText,
          accent,
        ),
        _requirementChip(
          'Special',
          _hasSpecialCharacter(password),
          secondaryText,
          accent,
        ),
      ],
    );
  }

  Widget _requirementChip(
    String label,
    bool passed,
    Color secondaryText,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: passed ? accent.withOpacity(.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              passed ? accent.withOpacity(.45) : secondaryText.withOpacity(.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            passed ? Icons.check_circle_outline : Icons.circle_outlined,
            size: 13,
            color: passed ? accent : secondaryText,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: passed ? accent : secondaryText,
              fontSize: 9,
              fontWeight: passed ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
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
    TextInputAction? textInputAction,
    Widget? suffix,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: TextStyle(
        color: textColor,
      ),
      decoration: InputDecoration(
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
      ),
    );
  }
}
