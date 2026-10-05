import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'upload_screen.dart';
import 'speech_upload_screen.dart';
import 'practice_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'help_screen.dart';
import 'login_screen.dart';

import '../widgets/theme_toggle.dart';
import '../theme/theme_controller.dart';
import '../widgets/dashboard_challenge_section.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  // =========================================================
  // COLOURS
  // =========================================================

  static const Color darkPrimary = Color(0xFF01411C);
  static const Color lightPrimary = Color(0xFF9AF0BF);

  // =========================================================
  // FIREBASE
  // =========================================================

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // =========================================================
  // USER DATA
  // =========================================================

  String userName = 'Student';

  bool isLoadingUser = true;

  List<Map<String, dynamic>> recentAssessments = [];
  List<Map<String, dynamic>> allAssessments = [];
  final TextEditingController _searchController = TextEditingController();

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {
    super.initState();

    _loadDashboardData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // =========================================================
  // LOAD DASHBOARD DATA
  // =========================================================

  Future<void> _loadDashboardData() async {
    await _loadUserName();

    await _loadRecentAssessments();

    if (!mounted) return;

    setState(() {
      isLoadingUser = false;
    });
  }

  // =========================================================
  // LOAD USER NAME
  // =========================================================

  Future<void> _loadUserName() async {
    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        return;
      }

      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _firestore.collection('users').doc(user.uid).get();

      if (snapshot.exists) {
        final Map<String, dynamic>? data = snapshot.data();

        final String? fullName = data?['fullName']?.toString();

        if (fullName != null && fullName.trim().isNotEmpty) {
          if (!mounted) return;

          setState(() {
            userName = fullName.trim();
          });
        }
      }
    } catch (e) {
      // Keep default "Student" if user data
      // cannot be loaded.
    }
  }

  // =========================================================
  // LOAD RECENT ASSESSMENTS
  // =========================================================

  Future<void> _loadRecentAssessments() async {
    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        return;
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('assessments')
          .where(
            'userId',
            isEqualTo: user.uid,
          )
          .get();

      final List<Map<String, dynamic>> loaded = [];

      for (final doc in snapshot.docs) {
        final Map<String, dynamic> data = doc.data();

        final dynamic scoreValue = data['overallScore'] ?? data['score'];

        final int score = scoreValue is num
            ? scoreValue.round()
            : int.tryParse(
                  scoreValue?.toString() ?? '0',
                ) ??
                0;

        final dynamic timestampValue = data['createdAt'] ?? data['date'];

        DateTime date;

        if (timestampValue is Timestamp) {
          date = timestampValue.toDate();
        } else if (timestampValue is DateTime) {
          date = timestampValue;
        } else {
          date = DateTime.now();
        }

        loaded.add({
          'id': doc.id,
          'score': score,
          'date': date,
          'data': data,
        });
      }

      // Newest first
      loaded.sort(
        (a, b) => (b['date'] as DateTime).compareTo(
          a['date'] as DateTime,
        ),
      );

      if (!mounted) return;

      setState(() {
        allAssessments = loaded;
        recentAssessments = loaded.take(3).toList();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        allAssessments = [];
        recentAssessments = [];
      });
    }
  }

  // =========================================================
  // SEARCH + NOTIFICATIONS
  // =========================================================

  String _assessmentTitle(Map<String, dynamic> assessment) {
    final data = Map<String, dynamic>.from(assessment['data'] as Map? ?? {});
    final candidates = [
      data['title'],
      data['name'],
      data['assessmentName'],
      data['presentationName'],
      data['fileName'],
      data['topic'],
      data['challengeTopic']
    ];
    for (final value in candidates) {
      final title = value?.toString().trim() ?? '';
      if (title.isNotEmpty) return title;
    }
    return 'Speech Assessment';
  }

  void _performSearch(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    FocusScope.of(context).unfocus();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Enter a presentation or assessment name to search.',
              style: GoogleFonts.poppins()),
          behavior: SnackBarBehavior.floating));
      return;
    }
    final results = allAssessments.where((assessment) {
      final data = Map<String, dynamic>.from(assessment['data'] as Map? ?? {});
      final searchable = [
        _assessmentTitle(assessment),
        ...data.values.map((v) => v?.toString() ?? '')
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
    _showAssessmentDialog(
        title: 'Search Results',
        subtitle: '"${rawQuery.trim()}"',
        assessments: results,
        emptyIcon: Icons.search_off_rounded,
        emptyTitle: 'No matching assessments found',
        emptyMessage:
            'Try another presentation name, topic, or assessment keyword.');
  }

  Future<void> _showNotifications() async {
    await _showAssessmentDialog(
        title: 'Notifications',
        subtitle: 'Recent SpeakWise activity',
        assessments: allAssessments.take(6).toList(),
        emptyIcon: Icons.notifications_none_rounded,
        emptyTitle: 'You’re all caught up',
        emptyMessage: 'Your completed assessment updates will appear here.',
        notificationMode: true);
  }

  Future<void> _showAssessmentDialog(
      {required String title,
      required String subtitle,
      required List<Map<String, dynamic>> assessments,
      required IconData emptyIcon,
      required String emptyTitle,
      required String emptyMessage,
      bool notificationMode = false}) async {
    final accent = accentColor(context);
    await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: cardColor(context),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: Row(children: [
              Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: accent.withOpacity(.10),
                      borderRadius: BorderRadius.circular(13)),
                  child: Icon(
                      notificationMode
                          ? Icons.notifications_none_rounded
                          : Icons.search_rounded,
                      color: accent)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: GoogleFonts.poppins(
                            color: textColor(context),
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            color: secondaryTextColor(context), fontSize: 10.5))
                  ])),
            ]),
            content: SizedBox(
                width: 520,
                child: assessments.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(emptyIcon,
                              color: secondaryTextColor(context), size: 48),
                          const SizedBox(height: 12),
                          Text(emptyTitle,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                  color: textColor(context),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 5),
                          Text(emptyMessage,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                  color: secondaryTextColor(context),
                                  fontSize: 11))
                        ]))
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 430),
                        child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: assessments.length,
                            separatorBuilder: (_, __) =>
                                Divider(color: borderColor(context)),
                            itemBuilder: (context, index) {
                              final assessment = assessments[index];
                              final score = assessment['score'] as int;
                              final date = assessment['date'] as DateTime;
                              final assessmentTitle =
                                  _assessmentTitle(assessment);
                              return ListTile(
                                leading: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                        color: accent.withOpacity(.10),
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: Icon(
                                        notificationMode
                                            ? Icons.check_circle_outline
                                            : Icons.assessment_outlined,
                                        color: accent)),
                                title: Text(
                                    notificationMode
                                        ? 'Assessment completed'
                                        : assessmentTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                        color: textColor(context),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    notificationMode
                                        ? '$assessmentTitle\n$score/100 • ${_formatDate(date)}'
                                        : '$score/100 • ${_getLevel(score)} • ${_formatDate(date)}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                        color: secondaryTextColor(context),
                                        fontSize: 10,
                                        height: 1.5)),
                                trailing: Icon(Icons.chevron_right,
                                    color: secondaryTextColor(context)),
                                onTap: () {
                                  Navigator.of(dialogContext).pop();
                                  Navigator.push(
                                      this.context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const HistoryScreen()));
                                },
                              );
                            }))),
            actions: [
              if (notificationMode && assessments.isNotEmpty)
                TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      Navigator.push(
                          this.context,
                          MaterialPageRoute(
                              builder: (_) => const HistoryScreen()));
                    },
                    child: Text('View All Assessments',
                        style: GoogleFonts.poppins(
                            color: accent, fontWeight: FontWeight.w600))),
              TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text('Close',
                      style: GoogleFonts.poppins(
                          color: accent, fontWeight: FontWeight.w600))),
            ],
          );
        });
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> _logout() async {
    try {
      await _auth.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logout failed. Please try again.'),
        ),
      );
    }
  }

  // =========================================================
  // LEVEL
  // =========================================================

  String _getLevel(int score) {
    if (score >= 90) {
      return 'Excellent';
    }

    if (score >= 80) {
      return 'Very Good';
    }

    if (score >= 60) {
      return 'Good';
    }

    if (score >= 40) {
      return 'Average';
    }

    return 'Needs Improvement';
  }

  // =========================================================
  // DATE FORMAT
  // =========================================================

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

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
    return isDark(context) ? Colors.white70 : const Color(0xFF52635A);
  }

  Color cardColor(BuildContext context) {
    return isDark(context) ? const Color(0xFF07150D) : Colors.white;
  }

  Color borderColor(BuildContext context) {
    final bool dark = isDark(context);

    return dark ? lightPrimary.withOpacity(.25) : darkPrimary.withOpacity(.18);
  }

  // =========================================================
  // GLASS CARD
  // =========================================================

  Widget glassCard({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    final bool dark = isDark(context);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: borderColor(context),
        ),
        boxShadow: [
          BoxShadow(
            color: dark
                ? Colors.black.withOpacity(.25)
                : darkPrimary.withOpacity(.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  // =========================================================
  // QUICK CARD
  // =========================================================

  Widget quickCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final Color accent = accentColor(context);
    bool isHovered = false;

    return StatefulBuilder(
      builder: (context, setCardState) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setCardState(() => isHovered = true),
          onExit: (_) => setCardState(() => isHovered = false),
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(
                0,
                isHovered ? -6 : 0,
                0,
              ),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isHovered ? accent.withOpacity(.12) : cardColor(context),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isHovered ? accent : borderColor(context),
                  width: isHovered ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isHovered
                        ? accent.withOpacity(.20)
                        : Colors.black.withOpacity(.05),
                    blurRadius: isHovered ? 25 : 10,
                    offset: Offset(0, isHovered ? 12 : 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isHovered
                          ? accent.withOpacity(.22)
                          : accent.withOpacity(.10),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      icon,
                      color: accent,
                      size: isHovered ? 29 : 26,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: textColor(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: secondaryTextColor(context),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isHovered ? 1 : .45,
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: accent,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // ACTION BUTTON
  // =========================================================

  Widget actionButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final bool dark = isDark(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withOpacity(.08)
              : darkPrimary.withOpacity(.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: dark
                ? Colors.white.withOpacity(.20)
                : darkPrimary.withOpacity(.20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: dark ? lightPrimary : darkPrimary,
              size: 19,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                color: dark ? Colors.white : darkPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // RECENT CARD
  // =========================================================

  Widget recentCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final Color accent = accentColor(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(
          bottom: 12,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: borderColor(context),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withOpacity(.10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                color: accent,
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
                      color: textColor(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: secondaryTextColor(
                        context,
                      ),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark(context) ? Colors.white38 : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // SIDEBAR ITEM
  // =========================================================

  Widget sidebarItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final bool dark = isDark(context);

    return Container(
      margin: const EdgeInsets.only(
        bottom: 6,
      ),
      child: Material(
        color: selected ? darkPrimary : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 13,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: selected
                      ? Colors.white
                      : dark
                          ? Colors.white70
                          : Colors.black54,
                ),
                const SizedBox(
                  width: 14,
                ),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: selected
                          ? Colors.white
                          : textColor(
                              context,
                            ),
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 19,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // SIDEBAR
  // =========================================================

  Widget sidebar(
    BuildContext context,
  ) {
    final bool dark = isDark(context);

    return Container(
      width: 245,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF020804) : const Color(0xFFF5FFF8),
        border: Border(
          right: BorderSide(
            color: dark
                ? lightPrimary.withOpacity(.15)
                : darkPrimary.withOpacity(.12),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =====================================================
          // LOGO
          // =====================================================

          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: primaryColor(context).withOpacity(.12),
                  borderRadius: BorderRadius.circular(
                    13,
                  ),
                  border: Border.all(
                    color: primaryColor(context).withOpacity(.40),
                  ),
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SpeakWise',
                    style: GoogleFonts.poppins(
                      color: textColor(context),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'AI Speech Assistant',
                    style: GoogleFonts.poppins(
                      color: secondaryTextColor(
                        context,
                      ),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(
            height: 35,
          ),

          sidebarItem(
            context,
            icon: Icons.home_outlined,
            title: 'Home',
            selected: true,
            onTap: () {},
          ),

          sidebarItem(
            context,
            icon: Icons.upload_file_outlined,
            title: 'Upload Presentation',
            selected: false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UploadScreen(),
                ),
              );
            },
          ),

          sidebarItem(
            context,
            icon: Icons.mic_none,
            title: 'Speech Assessment',
            selected: false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SpeechUploadScreen(),
                ),
              );
            },
          ),

          sidebarItem(
            context,
            icon: Icons.psychology_outlined,
            title: 'AI Practice',
            selected: false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PracticeScreen(),
                ),
              );
            },
          ),

          sidebarItem(
            context,
            icon: Icons.assessment_outlined,
            title: 'My Assessments',
            selected: false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HistoryScreen(),
                ),
              );
            },
          ),

          sidebarItem(
            context,
            icon: Icons.auto_awesome,
            title: 'Help',
            selected: false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HelpScreen(),
                ),
              );
            },
          ),

          const Spacer(),

          Divider(
            color: dark ? Colors.white12 : darkPrimary.withOpacity(.15),
          ),

          const SizedBox(
            height: 12,
          ),

          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: primaryColor(context).withOpacity(.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person,
                      color: dark ? lightPrimary : darkPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: textColor(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: secondaryTextColor(context),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(
                Icons.logout_rounded,
                color: Colors.redAccent,
                size: 19,
              ),
              label: Text(
                'Logout',
                style: GoogleFonts.poppins(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                  color: Colors.redAccent,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // MOBILE NAVIGATION
  // =========================================================

  Widget mobileNavigation(
    BuildContext context,
  ) {
    final bool dark = isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF020804) : Colors.white,
        border: Border(
          top: BorderSide(
            color: dark
                ? lightPrimary.withOpacity(.15)
                : darkPrimary.withOpacity(.12),
          ),
        ),
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        currentIndex: 0,
        selectedItemColor: dark ? lightPrimary : darkPrimary,
        unselectedItemColor: dark ? Colors.white54 : Colors.black45,
        onTap: (index) {
          switch (index) {
            case 0:
              break;

            case 1:
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PracticeScreen(),
                ),
              );
              break;

            case 2:
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HelpScreen(),
                ),
              );
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.psychology_outlined),
            label: 'Practice',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome),
            label: 'Help',
          ),
        ],
      ),
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool desktop = constraints.maxWidth >= 900;

          return Row(
            children: [
              if (desktop) sidebar(context),
              Expanded(
                child: SafeArea(
                  child: Column(
                    children: [
                      // =========================================
                      // TOP HEADER
                      // =========================================

                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          25,
                          18,
                          25,
                          10,
                        ),
                        child: Row(
                          children: [
                            if (!desktop)
                              Container(
                                width: 40,
                                height: 40,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: primaryColor(
                                    context,
                                  ).withOpacity(
                                    .10,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    12,
                                  ),
                                ),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                ),
                              ),
                            if (!desktop)
                              const SizedBox(
                                width: 12,
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // =================================
                                  // WELCOME NAME
                                  // =================================

                                  Text(
                                    'Welcome, $userName 👋',
                                    style: GoogleFonts.poppins(
                                      color: textColor(
                                        context,
                                      ),
                                      fontSize: desktop ? 28 : 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  Text(
                                    'What will you practise today?',
                                    style: GoogleFonts.poppins(
                                      color: secondaryTextColor(
                                        context,
                                      ),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (desktop)
                              SizedBox(
                                width: 250,
                                height: 44,
                                child: TextField(
                                  controller: _searchController,
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: _performSearch,
                                  style: TextStyle(
                                    color: textColor(
                                      context,
                                    ),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Search presentations...',
                                    hintStyle: TextStyle(
                                      color: secondaryTextColor(
                                        context,
                                      ),
                                      fontSize: 12,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: secondaryTextColor(
                                        context,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: dark
                                        ? Colors.white.withOpacity(
                                            .04,
                                          )
                                        : darkPrimary.withOpacity(
                                            .04,
                                          ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        14,
                                      ),
                                      borderSide: BorderSide(
                                        color: dark
                                            ? Colors.white12
                                            : darkPrimary.withOpacity(
                                                .15,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(
                              width: 12,
                            ),
                            IconButton(
                              tooltip: 'Notifications',
                              onPressed: _showNotifications,
                              icon: Icon(
                                Icons.notifications_none,
                                color: textColor(
                                  context,
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            ThemeToggle(
                              isDark: ThemeController.isDark,
                              onTap: ThemeController.toggleTheme,
                            ),
                          ],
                        ),
                      ),

                      // =========================================
                      // MAIN CONTENT
                      // =========================================

                      Expanded(
                        child: RefreshIndicator(
                          color: accentColor(
                            context,
                          ),
                          onRefresh: _loadDashboardData,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(
                              25,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // =================================
                                // AI CHALLENGE + SPEAKING SKILLS
                                // =================================

                                DashboardChallengeSection(
                                  onAssessmentSaved: _loadDashboardData,
                                ),

                                const SizedBox(
                                  height: 32,
                                ),

                                // =================================
                                // QUICK START
                                // =================================

                                Row(
                                  children: [
                                    Text(
                                      'Quick Start',
                                      style: GoogleFonts.poppins(
                                        color: textColor(
                                          context,
                                        ),
                                        fontSize: 21,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '4 tools',
                                      style: GoogleFonts.poppins(
                                        color: accentColor(
                                          context,
                                        ),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(
                                  height: 15,
                                ),

                                GridView.count(
                                  crossAxisCount: desktop ? 4 : 2,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisSpacing: 15,
                                  mainAxisSpacing: 15,
                                  childAspectRatio: desktop ? 1.15 : .92,
                                  children: [
                                    quickCard(
                                      context,
                                      icon: Icons.upload_file_outlined,
                                      title: 'Upload Presentation',
                                      subtitle: 'PDF, PPTX or DOCX',
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const UploadScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                    quickCard(
                                      context,
                                      icon: Icons.mic_none,
                                      title: 'Speech Assessment',
                                      subtitle: 'Upload your speech',
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const SpeechUploadScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                    quickCard(
                                      context,
                                      icon: Icons.psychology_outlined,
                                      title: 'AI Practice',
                                      subtitle: 'Practise with AI',
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const PracticeScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                    quickCard(
                                      context,
                                      icon: Icons.assessment_outlined,
                                      title: 'My Assessments',
                                      subtitle: 'View your results',
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const HistoryScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),

                                const SizedBox(
                                  height: 32,
                                ),

                                // =================================
                                // RECENT ASSESSMENTS
                                // =================================

                                Row(
                                  children: [
                                    Text(
                                      'Recent Assessments',
                                      style: GoogleFonts.poppins(
                                        color: textColor(
                                          context,
                                        ),
                                        fontSize: 21,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const HistoryScreen(),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'View all',
                                        style: GoogleFonts.poppins(
                                          color: accentColor(
                                            context,
                                          ),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(
                                  height: 10,
                                ),

                                // =================================
                                // REAL ASSESSMENTS
                                // =================================

                                if (recentAssessments.isEmpty)
                                  recentCard(
                                    context,
                                    title: 'No assessments yet',
                                    subtitle:
                                        'Upload your first speech to begin',
                                    icon: Icons.mic_none,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const SpeechUploadScreen(),
                                        ),
                                      );
                                    },
                                  )
                                else
                                  ...recentAssessments.map(
                                    (
                                      assessment,
                                    ) {
                                      final int score = assessment['score'];

                                      final DateTime date = assessment['date'];

                                      final String level = _getLevel(
                                        score,
                                      );

                                      return recentCard(
                                        context,
                                        title: '$score/100 • $level',
                                        subtitle: _formatDate(
                                          date,
                                        ),
                                        icon: Icons.mic_none,
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const HistoryScreen(),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),

                                const SizedBox(
                                  height: 15,
                                ),

                                // =================================
                                // AI INFORMATION
                                // =================================

                                glassCard(
                                  context: context,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: primaryColor(
                                            context,
                                          ).withOpacity(
                                            .12,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.auto_awesome,
                                          color: accentColor(
                                            context,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 14,
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'SpeakWise AI',
                                              style: GoogleFonts.poppins(
                                                color: textColor(
                                                  context,
                                                ),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(
                                              height: 4,
                                            ),
                                            Text(
                                              'Your speech is evaluated based on communication and speaking performance — not slide design.',
                                              style: GoogleFonts.poppins(
                                                color: secondaryTextColor(
                                                  context,
                                                ),
                                                fontSize: 11,
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(
                                  height: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      if (!desktop)
                        mobileNavigation(
                          context,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
