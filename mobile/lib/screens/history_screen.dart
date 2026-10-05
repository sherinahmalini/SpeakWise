import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'result_screen.dart';
import '../services/auth_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final AuthService _authService = AuthService();

  static const Color darkPrimary = Color(0xFF01411C);
  static const Color lightPrimary = Color(0xFF9AF0BF);

  final TextEditingController _searchController = TextEditingController();

  String searchQuery = '';
  String selectedFilter = 'All Assessments';

  bool isLoading = true;
  bool _dialogOpen = false;

  List<Map<String, dynamic>> history = [];

  // =========================================================
  // INIT / DISPOSE
  // =========================================================

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // =========================================================
  // LOAD HISTORY
  // =========================================================

  Future<void> _loadHistory() async {
    try {
      final user = _authService.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          history = [];
          isLoading = false;
        });

        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('assessments')
          .where(
            'userId',
            isEqualTo: user.uid,
          )
          .get();

      final List<Map<String, dynamic>> loadedHistory = [];

      for (final doc in snapshot.docs) {
        final Map<String, dynamic> data = doc.data();

        final dynamic scoreValue = data['overallScore'] ?? data['score'];

        final int score = scoreValue is num
            ? scoreValue.round()
            : double.tryParse(
                  scoreValue?.toString() ?? '0',
                )?.round() ??
                0;

        final dynamic timestampValue = data['createdAt'] ?? data['date'];

        DateTime date;

        if (timestampValue is Timestamp) {
          date = timestampValue.toDate();
        } else if (timestampValue is DateTime) {
          date = timestampValue;
        } else if (timestampValue is String) {
          date = DateTime.tryParse(timestampValue) ?? DateTime.now();
        } else {
          date = DateTime.now();
        }

        loadedHistory.add({
          'id': doc.id,
          'score': score,
          'date': date,
          'level': _getLevel(score),
          'title': _getTitle(data),
          'data': data,
        });
      }

      loadedHistory.sort(
        (a, b) => (b['date'] as DateTime).compareTo(
          a['date'] as DateTime,
        ),
      );

      if (!mounted) return;

      setState(() {
        history = loadedHistory;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('History loading error: $e');

      if (!mounted) return;

      setState(() {
        history = [];
        isLoading = false;
      });

      _showMessage(
        'Unable to load assessment history.',
        isError: true,
      );
    }
  }

  // =========================================================
  // DATA HELPERS
  // =========================================================

  String _getTitle(
    Map<String, dynamic> data,
  ) {
    final dynamic title =
        data['title'] ?? data['presentationTitle'] ?? data['name'];

    if (title != null && title.toString().trim().isNotEmpty) {
      return title.toString().trim();
    }

    return 'Speech Assessment';
  }

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

  double _getScore(
    Map<String, dynamic> data,
    String key,
  ) {
    final dynamic value = data[key];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '0',
        ) ??
        0;
  }

  double _getOverallScore(
    Map<String, dynamic> data,
  ) {
    final dynamic value = data['overallScore'] ?? data['score'];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '0',
        ) ??
        0;
  }

  String _formatDate(DateTime date) {
    const List<String> months = [
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
        '${months[date.month - 1]} ${date.year}';
  }

  // =========================================================
  // FILTERED HISTORY
  // =========================================================

  List<Map<String, dynamic>> get filteredHistory {
    return history.where((item) {
      final String level = item['level'].toString().toLowerCase();

      final String title = item['title'].toString().toLowerCase();

      final String date = _formatDate(
        item['date'] as DateTime,
      ).toLowerCase();

      final String score = item['score'].toString().toLowerCase();

      final String search = searchQuery.toLowerCase().trim();

      final bool matchesSearch = search.isEmpty ||
          level.contains(search) ||
          title.contains(search) ||
          date.contains(search) ||
          score.contains(search);

      final bool matchesFilter = selectedFilter == 'All Assessments' ||
          level == selectedFilter.toLowerCase();

      return matchesSearch && matchesFilter;
    }).toList();
  }

  // =========================================================
  // RESET FILTERS
  // =========================================================

  void _resetFilters() {
    _searchController.clear();

    if (!mounted) return;

    setState(() {
      searchQuery = '';
      selectedFilter = 'All Assessments';
    });
  }

  // =========================================================
  // MESSAGE
  // =========================================================

  void _showMessage(
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
  // DELETE ASSESSMENT
  // =========================================================

  Future<void> _deleteAssessment(
    String documentId,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('assessments')
          .doc(documentId)
          .delete();

      if (!mounted) return;

      setState(() {
        history.removeWhere(
          (item) => item['id'] == documentId,
        );
      });

      _showMessage(
        'Assessment deleted successfully.',
      );
    } catch (e) {
      debugPrint(
        'Delete assessment error: $e',
      );

      if (!mounted) return;

      _showMessage(
        'Unable to delete assessment.',
        isError: true,
      );
    }
  }

  // =========================================================
  // CONFIRM DELETE
  // =========================================================

  Future<void> _confirmDelete(
    String documentId,
  ) async {
    if (!mounted || _dialogOpen) {
      return;
    }

    final bool dark = Theme.of(context).brightness == Brightness.dark;

    final Color textColor = dark ? Colors.white : const Color(0xFF17221A);

    final Color secondaryTextColor =
        dark ? Colors.white70 : const Color(0xFF5F6B63);

    final Color accent = dark ? lightPrimary : darkPrimary;

    _dialogOpen = true;

    bool? confirmed;

    try {
      confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
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
                    color: Colors.redAccent.withOpacity(.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Delete Assessment?',
                    style: GoogleFonts.poppins(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'Are you sure you want to delete this assessment? '
              'This action cannot be undone.',
              style: GoogleFonts.poppins(
                color: secondaryTextColor,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: Text(
                  'CANCEL',
                  style: GoogleFonts.poppins(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                child: Text(
                  'DELETE',
                  style: GoogleFonts.poppins(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } finally {
      _dialogOpen = false;
    }

    if (!mounted || confirmed != true) {
      return;
    }

    await _deleteAssessment(documentId);
  }

  // =========================================================
  // RENAME ASSESSMENT
  // =========================================================

  Future<void> _renameAssessment(
    String documentId,
    String currentTitle,
  ) async {
    if (!mounted || _dialogOpen) {
      return;
    }

    final bool dark = Theme.of(context).brightness == Brightness.dark;

    final Color accent = dark ? lightPrimary : darkPrimary;

    final Color dialogTextColor = dark ? Colors.white : const Color(0xFF17221A);

    final Color secondary = dark ? Colors.white70 : Colors.black54;

    String assessmentName = currentTitle;

    _dialogOpen = true;

    String? newTitle;

    try {
      newTitle = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
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
                    color: accent.withOpacity(.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    color: accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Rename Assessment',
                    style: GoogleFonts.poppins(
                      color: dialogTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: TextFormField(
              initialValue: currentTitle,
              autofocus: true,
              maxLength: 50,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              style: GoogleFonts.poppins(
                color: dialogTextColor,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                labelText: 'Assessment Name',
                counterText: '',
                labelStyle: GoogleFonts.poppins(
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
                    color: accent.withOpacity(.30),
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
                final String title = value.trim();

                if (title.isEmpty) {
                  return;
                }

                Navigator.of(dialogContext).pop(title);
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: Text(
                  'CANCEL',
                  style: GoogleFonts.poppins(
                    color: accent,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  final String title = assessmentName.trim();

                  if (title.isEmpty) {
                    return;
                  }

                  Navigator.of(dialogContext).pop(title);
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
    } finally {
      _dialogOpen = false;
    }

    if (!mounted) {
      return;
    }

    final String cleanedTitle = newTitle?.trim() ?? '';

    if (cleanedTitle.isEmpty || cleanedTitle == currentTitle.trim()) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('assessments')
          .doc(documentId)
          .update({
        'title': cleanedTitle,
      });

      if (!mounted) return;

      setState(() {
        final int index = history.indexWhere(
          (item) => item['id'] == documentId,
        );

        if (index != -1) {
          history[index]['title'] = cleanedTitle;

          final Map<String, dynamic> data = Map<String, dynamic>.from(
            history[index]['data'] as Map,
          );

          data['title'] = cleanedTitle;

          history[index]['data'] = data;
        }
      });

      _showMessage(
        'Assessment renamed successfully.',
      );
    } catch (e) {
      debugPrint(
        'Rename assessment error: $e',
      );

      if (!mounted) return;

      _showMessage(
        'Unable to rename assessment.',
        isError: true,
      );
    }
  }

  // =========================================================
  // OPEN RESULT
  // =========================================================

  void _openResult(
    Map<String, dynamic> item,
  ) {
    if (!mounted || _dialogOpen) {
      return;
    }

    final Map<String, dynamic> data = Map<String, dynamic>.from(
      item['data'] as Map,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          overallScore: _getOverallScore(data),
          pronunciation: _getScore(data, 'pronunciation'),
          fluency: _getScore(data, 'fluency'),
          grammar: _getScore(data, 'grammar'),
          vocabulary: _getScore(data, 'vocabulary'),
          speechClarity: _getScore(data, 'speechClarity'),
          pacing: _getScore(data, 'pacing'),
          feedback: data['feedback']?.toString().trim().isNotEmpty == true
              ? data['feedback'].toString()
              : 'No feedback available for this assessment.',
        ),
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

    final Color textColor = dark ? Colors.white : const Color(0xFF17221A);

    final Color secondaryTextColor =
        dark ? Colors.white70 : const Color(0xFF5F6B63);

    final Color cardColor = dark ? const Color(0xFF0B1510) : Colors.white;

    final Color borderColor =
        dark ? lightPrimary.withOpacity(.18) : darkPrimary.withOpacity(.18);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: Icon(
            Icons.arrow_back_rounded,
            color: accent,
          ),
        ),
        title: Text(
          'My Assessments',
          style: GoogleFonts.poppins(
            color: textColor,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: isLoading
                ? null
                : () async {
                    setState(() {
                      isLoading = true;
                    });

                    await _loadHistory();
                  },
            icon: Icon(
              Icons.refresh_rounded,
              color: isLoading ? secondaryTextColor : accent,
            ),
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              5,
              20,
              15,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Assessments',
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Review your previous AI speech assessments and feedback.',
                  style: GoogleFonts.poppins(
                    color: secondaryTextColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // =================================================
          // SEARCH
          // =================================================

          Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              0,
              20,
              10,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (String value) {
                if (!mounted) return;

                setState(() {
                  searchQuery = value;
                });
              },
              style: GoogleFonts.poppins(
                color: textColor,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: 'Search assessments...',
                hintStyle: GoogleFonts.poppins(
                  color: secondaryTextColor,
                  fontSize: 12,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: accent,
                ),
                suffixIcon: searchQuery.trim().isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();

                          setState(() {
                            searchQuery = '';
                          });
                        },
                        icon: Icon(
                          Icons.close_rounded,
                          color: accent,
                        ),
                      )
                    : null,
                filled: true,
                fillColor: dark
                    ? Colors.white.withOpacity(.05)
                    : const Color(0xFFF0F5F2),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: BorderSide(
                    color: borderColor,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: BorderSide(
                    color: borderColor,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: BorderSide(
                    color: accent,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          // =================================================
          // ACTIVE FILTER
          // =================================================

          if (selectedFilter != 'All Assessments')
            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                0,
                20,
                12,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: accent.withOpacity(.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.filter_list_rounded,
                        size: 15,
                        color: accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        selectedFilter,
                        style: GoogleFonts.poppins(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 7),
                      InkWell(
                        onTap: () {
                          setState(() {
                            selectedFilter = 'All Assessments';
                          });
                        },
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // =================================================
          // RESULTS
          // =================================================

          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: accent,
                    ),
                  )
                : filteredHistory.isEmpty
                    ? _emptyHistory(
                        textColor,
                        secondaryTextColor,
                        accent,
                      )
                    : RefreshIndicator(
                        color: accent,
                        onRefresh: _loadHistory,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            0,
                            20,
                            100,
                          ),
                          itemCount: filteredHistory.length,
                          itemBuilder: (
                            BuildContext context,
                            int index,
                          ) {
                            final item = filteredHistory[index];

                            return _historyCard(
                              dark: dark,
                              primary: primary,
                              accent: accent,
                              textColor: textColor,
                              secondaryTextColor: secondaryTextColor,
                              cardColor: cardColor,
                              borderColor: borderColor,
                              score: item['score'] as int,
                              level: item['level'].toString(),
                              title: item['title'].toString(),
                              date: _formatDate(
                                item['date'] as DateTime,
                              ),
                              documentId: item['id'].toString(),
                              item: item,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Filter assessments',
        backgroundColor: primary,
        foregroundColor: dark ? Colors.white : darkPrimary,
        onPressed: _dialogOpen
            ? null
            : () {
                _showFilterDialog();
              },
        child: const Icon(
          Icons.filter_list_rounded,
        ),
      ),
    );
  }

  // =========================================================
  // HISTORY CARD
  // =========================================================

  Widget _historyCard({
    required bool dark,
    required Color primary,
    required Color accent,
    required Color textColor,
    required Color secondaryTextColor,
    required Color cardColor,
    required Color borderColor,
    required int score,
    required String level,
    required String title,
    required String date,
    required String documentId,
    required Map<String, dynamic> item,
  }) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 13,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              dark ? .15 : .04,
            ),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            _openResult(item);
          },
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primary.withOpacity(
                      dark ? .35 : .45,
                    ),
                    border: Border.all(
                      color: accent.withOpacity(.6),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$score',
                      style: GoogleFonts.poppins(
                        color: dark ? Colors.white : darkPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        level,
                        style: GoogleFonts.poppins(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 13,
                            color: secondaryTextColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            date,
                            style: GoogleFonts.poppins(
                              color: secondaryTextColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(
                            dark ? .25 : .35,
                          ),
                          borderRadius: BorderRadius.circular(
                            20,
                          ),
                        ),
                        child: Text(
                          'Speech Assessment',
                          style: GoogleFonts.poppins(
                            color: accent,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    PopupMenuButton<String>(
                      tooltip: 'Assessment options',
                      color: dark ? const Color(0xFF0B1510) : Colors.white,
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: accent,
                      ),
                      onSelected: (String value) {
                        if (value == 'view') {
                          _openResult(item);
                        } else if (value == 'rename') {
                          _renameAssessment(
                            documentId,
                            title,
                          );
                        } else if (value == 'delete') {
                          _confirmDelete(
                            documentId,
                          );
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem<String>(
                          value: 'view',
                          child: _menuItem(
                            Icons.visibility_outlined,
                            'View Result',
                            accent,
                            textColor,
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'rename',
                          child: _menuItem(
                            Icons.edit_outlined,
                            'Rename',
                            accent,
                            textColor,
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: _menuItem(
                            Icons.delete_outline,
                            'Delete',
                            Colors.redAccent,
                            Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: dark ? Colors.white38 : Colors.black38,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // MENU ITEM
  // =========================================================

  Widget _menuItem(
    IconData icon,
    String title,
    Color iconColor,
    Color itemTextColor,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: iconColor,
          size: 19,
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.poppins(
            color: itemTextColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // EMPTY HISTORY
  // =========================================================

  Widget _emptyHistory(
    Color textColor,
    Color secondaryTextColor,
    Color accent,
  ) {
    final bool filtered =
        searchQuery.trim().isNotEmpty || selectedFilter != 'All Assessments';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 85,
              height: 85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withOpacity(.12),
              ),
              child: Icon(
                filtered ? Icons.search_off_rounded : Icons.assessment_outlined,
                size: 42,
                color: accent,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              filtered ? 'No Matching Assessments' : 'No Assessments Yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              filtered
                  ? 'Try changing your search or filter.'
                  : 'Complete your first speech assessment to see your results here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: secondaryTextColor,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            if (filtered) ...[
              const SizedBox(height: 18),
              TextButton.icon(
                onPressed: _resetFilters,
                icon: Icon(
                  Icons.restart_alt_rounded,
                  color: accent,
                ),
                label: Text(
                  'RESET FILTER',
                  style: GoogleFonts.poppins(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================
  // FILTER DIALOG
  // =========================================================

  Future<void> _showFilterDialog() async {
    if (!mounted || _dialogOpen) {
      return;
    }

    final bool dark = Theme.of(context).brightness == Brightness.dark;

    final Color accent = dark ? lightPrimary : darkPrimary;

    final Color dialogTextColor = dark ? Colors.white : const Color(0xFF17221A);

    _dialogOpen = true;

    String? selected;

    try {
      selected = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            backgroundColor: dark ? const Color(0xFF0B1510) : Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(
              'Filter Assessments',
              style: GoogleFonts.poppins(
                color: dialogTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _filterOption(
                  dialogContext,
                  'All Assessments',
                  Icons.all_inclusive,
                  accent,
                  dialogTextColor,
                ),
                _filterOption(
                  dialogContext,
                  'Excellent',
                  Icons.star_outline_rounded,
                  accent,
                  dialogTextColor,
                ),
                _filterOption(
                  dialogContext,
                  'Very Good',
                  Icons.trending_up_rounded,
                  accent,
                  dialogTextColor,
                ),
                _filterOption(
                  dialogContext,
                  'Good',
                  Icons.thumb_up_outlined,
                  accent,
                  dialogTextColor,
                ),
                _filterOption(
                  dialogContext,
                  'Average',
                  Icons.show_chart_rounded,
                  accent,
                  dialogTextColor,
                ),
                _filterOption(
                  dialogContext,
                  'Needs Improvement',
                  Icons.warning_amber_rounded,
                  accent,
                  dialogTextColor,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: Text(
                  'CLOSE',
                  style: GoogleFonts.poppins(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } finally {
      _dialogOpen = false;
    }

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      selectedFilter = selected!;
    });
  }

  // =========================================================
  // FILTER OPTION
  // =========================================================

  Widget _filterOption(
    BuildContext dialogContext,
    String title,
    IconData icon,
    Color accent,
    Color itemTextColor,
  ) {
    final bool selected = selectedFilter == title;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: accent,
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: itemTextColor,
          fontSize: 13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: selected
          ? Icon(
              Icons.check_circle_rounded,
              color: accent,
              size: 20,
            )
          : null,
      onTap: () {
        Navigator.of(dialogContext).pop(title);
      },
    );
  }
}
