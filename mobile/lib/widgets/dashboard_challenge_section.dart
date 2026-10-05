import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../screens/history_screen.dart';
import '../screens/result_screen.dart';
import '../services/assessment_service.dart';

class DashboardChallengeSection extends StatefulWidget {
  const DashboardChallengeSection({
    super.key,
    this.onAssessmentSaved,
  });

  final Future<void> Function()? onAssessmentSaved;

  @override
  State<DashboardChallengeSection> createState() =>
      _DashboardChallengeSectionState();
}

class _DashboardChallengeSectionState extends State<DashboardChallengeSection> {
  static const Color _darkGreen = Color(0xFF01411C);
  static const Color _mint = Color(0xFF9AF0BF);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AssessmentService _assessmentService = AssessmentService();
  final AudioRecorder _recorder = AudioRecorder();
  final math.Random _random = math.Random();

  final List<_ChallengeTopic> _topics = const [
    _ChallengeTopic(
      question: 'Would AI make students smarter or lazier?',
      category: 'Education',
      difficulty: 'Medium',
    ),
    _ChallengeTopic(
      question: 'What skill should every student learn before graduating?',
      category: 'Education',
      difficulty: 'Easy',
    ),
    _ChallengeTopic(
      question: 'Should people rely on AI for everyday decisions?',
      category: 'Technology',
      difficulty: 'Medium',
    ),
    _ChallengeTopic(
      question: 'Has social media improved the way we communicate?',
      category: 'Social Issues',
      difficulty: 'Hard',
    ),
    _ChallengeTopic(
      question: 'What small habit can make someone more productive?',
      category: 'Lifestyle',
      difficulty: 'Easy',
    ),
    _ChallengeTopic(
      question: 'Should cities do more to reduce single-use plastics?',
      category: 'Environment',
      difficulty: 'Medium',
    ),
    _ChallengeTopic(
      question: 'Is passion more important than salary when choosing a career?',
      category: 'Career',
      difficulty: 'Hard',
    ),
    _ChallengeTopic(
      question: 'What invention has changed everyday life the most?',
      category: 'General',
      difficulty: 'Easy',
    ),
    _ChallengeTopic(
      question: 'Should remote work become the normal way of working?',
      category: 'Career',
      difficulty: 'Medium',
    ),
    _ChallengeTopic(
      question: 'Can technology help solve climate change?',
      category: 'Environment',
      difficulty: 'Hard',
    ),
  ];

  late _ChallengeTopic _topic;
  Timer? _timer;
  bool _isRecording = false;
  bool _isAnalysing = false;
  int _secondsLeft = 60;
  String? _recordingPath;

  bool _loadingSkills = true;
  int _assessmentCount = 0;
  Map<String, double> _skills = {};

  @override
  void initState() {
    super.initState();
    _topic = _topics[_random.nextInt(_topics.length)];
    _loadSkills();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Color _textColor(BuildContext context) =>
      _isDark(context) ? Colors.white : const Color(0xFF17221A);

  Color _secondaryText(BuildContext context) =>
      _isDark(context) ? Colors.white70 : const Color(0xFF52635A);

  void _anotherTopic() {
    if (_isRecording || _isAnalysing) return;
    if (_topics.length < 2) return;

    _ChallengeTopic next = _topic;
    while (next == _topic) {
      next = _topics[_random.nextInt(_topics.length)];
    }

    setState(() => _topic = next);
  }

  Future<void> _loadSkills() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _loadingSkills = false;
          _assessmentCount = 0;
          _skills = {};
        });
      }
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('assessments')
          .where('userId', isEqualTo: user.uid)
          .get();

      final totals = <String, double>{};
      final counts = <String, int>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        _collectMetric(totals, counts, 'Pronunciation', data, [
          'pronunciation',
        ]);
        _collectMetric(totals, counts, 'Fluency', data, ['fluency']);
        _collectMetric(totals, counts, 'Grammar', data, ['grammar']);
        _collectMetric(totals, counts, 'Vocabulary', data, ['vocabulary']);
        _collectMetric(totals, counts, 'Clarity', data, [
          'speechClarity',
          'speech_clarity',
          'clarity',
        ]);
        _collectMetric(totals, counts, 'Pacing', data, ['pacing', 'pace']);
      }

      final averages = <String, double>{};
      for (final entry in totals.entries) {
        final count = counts[entry.key] ?? 0;
        if (count > 0) {
          averages[entry.key] = (entry.value / count).clamp(0, 100);
        }
      }

      if (!mounted) return;
      setState(() {
        _assessmentCount = snapshot.docs.length;
        _skills = averages;
        _loadingSkills = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSkills = false;
        _assessmentCount = 0;
        _skills = {};
      });
    }
  }

  void _collectMetric(
    Map<String, double> totals,
    Map<String, int> counts,
    String label,
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = _toDouble(data[key]);
      if (value != null) {
        totals[label] = (totals[label] ?? 0) + value;
        counts[label] = (counts[label] ?? 0) + 1;
        return;
      }
    }
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  double _score(Map<String, dynamic> result, String key) {
    return (_toDouble(result[key]) ?? 0).clamp(0, 100);
  }

  Future<void> _startChallenge() async {
    if (_isRecording || _isAnalysing) return;

    try {
      final allowed = await _recorder.hasPermission();
      if (!allowed) {
        _showMessage(
            'Microphone permission is required to start the challenge.');
        return;
      }

      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}${Platform.pathSeparator}speakwise_challenge_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );

      if (!mounted) return;
      setState(() {
        _recordingPath = path;
        _secondsLeft = 60;
        _isRecording = true;
      });

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_secondsLeft <= 1) {
          timer.cancel();
          _finishChallenge();
        } else {
          setState(() => _secondsLeft--);
        }
      });
    } catch (e) {
      _showMessage('Could not start recording. Please try again.');
    }
  }

  Future<void> _finishChallenge() async {
    if (!_isRecording || _isAnalysing) return;

    _timer?.cancel();

    try {
      final stoppedPath = await _recorder.stop();
      final path = stoppedPath ?? _recordingPath;

      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isAnalysing = true;
      });

      if (path == null || !File(path).existsSync()) {
        throw Exception('The recording could not be found.');
      }

      final Uint8List bytes = await File(path).readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('The recording is empty.');
      }

      final result = await _assessmentService.analyseSpeech(
        fileBytes: bytes,
        fileName: 'speakwise_daily_challenge.wav',
        isVideo: false,
      );

      final overall = _score(result, 'overallScore');
      final pronunciation = _score(result, 'pronunciation');
      final fluency = _score(result, 'fluency');
      final grammar = _score(result, 'grammar');
      final vocabulary = _score(result, 'vocabulary');
      final clarity = _score(result, 'speechClarity');
      final pacing = _score(result, 'pacing');
      final feedback = result['feedback']?.toString().trim();

      await _saveChallengeResult(
        overallScore: overall,
        pronunciation: pronunciation,
        fluency: fluency,
        grammar: grammar,
        vocabulary: vocabulary,
        speechClarity: clarity,
        pacing: pacing,
        feedback: feedback == null || feedback.isEmpty
            ? 'Keep practising to strengthen your speaking skills.'
            : feedback,
      );

      try {
        if (File(path).existsSync()) File(path).deleteSync();
      } catch (_) {}

      await _loadSkills();
      if (widget.onAssessmentSaved != null) {
        await widget.onAssessmentSaved!();
      }

      if (!mounted) return;
      setState(() => _isAnalysing = false);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            overallScore: overall,
            pronunciation: pronunciation,
            fluency: fluency,
            grammar: grammar,
            vocabulary: vocabulary,
            speechClarity: clarity,
            pacing: pacing,
            feedback: feedback == null || feedback.isEmpty
                ? 'Keep practising to strengthen your speaking skills.'
                : feedback,
          ),
        ),
      );

      await _loadSkills();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isAnalysing = false;
        _secondsLeft = 60;
      });
      _showMessage(_friendlyError(e));
    }
  }

  Future<void> _saveChallengeResult({
    required double overallScore,
    required double pronunciation,
    required double fluency,
    required double grammar,
    required double vocabulary,
    required double speechClarity,
    required double pacing,
    required String feedback,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('assessments').add({
      'userId': user.uid,
      'title': 'AI Challenge • ${_topic.category}',
      'assessmentType': 'dailyChallenge',
      'challengeTopic': _topic.question,
      'challengeCategory': _topic.category,
      'challengeDifficulty': _topic.difficulty,
      'overallScore': overallScore,
      'score': overallScore,
      'pronunciation': pronunciation,
      'fluency': fluency,
      'grammar': grammar,
      'vocabulary': vocabulary,
      'speechClarity': speechClarity,
      'pacing': pacing,
      'feedback': feedback,
      'createdAt': FieldValue.serverTimestamp(),
      'date': FieldValue.serverTimestamp(),
    });
  }

  String _friendlyError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    if (text.isEmpty) return 'Challenge analysis failed. Please try again.';
    return text;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _insight() {
    if (_assessmentCount == 0 || _skills.isEmpty) {
      return 'Complete your first assessment to unlock personalised speaking insights.';
    }

    final entries = _skills.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final weakest = entries.first;
    final strongest = entries.last;

    if (weakest.value >= 85) {
      return 'Strong work across your speaking skills. Keep practising consistently to maintain your ${strongest.key.toLowerCase()} strength.';
    }

    switch (weakest.key) {
      case 'Pronunciation':
        return 'Your ${strongest.key.toLowerCase()} is a strength. Slow down on difficult words and focus on clean pronunciation.';
      case 'Fluency':
        return 'Your ${strongest.key.toLowerCase()} is a strength. Practise linking ideas smoothly to improve fluency.';
      case 'Grammar':
        return 'Your ${strongest.key.toLowerCase()} is a strength. Use shorter, complete sentences to strengthen grammar while speaking.';
      case 'Vocabulary':
        return 'Your ${strongest.key.toLowerCase()} is a strength. Add a few precise topic-specific words to strengthen vocabulary.';
      case 'Clarity':
        return 'Your ${strongest.key.toLowerCase()} is a strength. Emphasise key words and finish each sentence clearly.';
      case 'Pacing':
        return 'Your ${strongest.key.toLowerCase()} is a strength. Use deliberate pauses to make your pacing more natural.';
      default:
        return 'Keep practising consistently and focus on your lowest-scoring speaking skill next.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 760;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 18 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: dark
              ? const [Color(0xFF04150C), Color(0xFF062817), Color(0xFF031109)]
              : const [Color(0xFFF4FFF8), Color(0xFFE5F8EC), Color(0xFFF8FFFA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: dark ? _mint.withOpacity(.28) : _darkGreen.withOpacity(.18),
        ),
        boxShadow: [
          BoxShadow(
            color: _darkGreen.withOpacity(dark ? .20 : .10),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(top: 12, right: 30, child: _particle(5, .45)),
          Positioned(top: 70, left: 12, child: _particle(3, .25)),
          Positioned(bottom: 25, right: 8, child: _particle(4, .30)),
          compact
              ? Column(
                  children: [
                    _challengePanel(context),
                    const SizedBox(height: 18),
                    _mascot(compact: true),
                    const SizedBox(height: 18),
                    _skillsPanel(context),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 10, child: _challengePanel(context)),
                    SizedBox(width: 120, child: _mascot(compact: false)),
                    Expanded(flex: 9, child: _skillsPanel(context)),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _particle(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _mint.withOpacity(opacity),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: _mint.withOpacity(opacity), blurRadius: 10),
          ],
        ),
      );

  Widget _challengePanel(BuildContext context) {
    final dark = _isDark(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _innerDecoration(dark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBadge(Icons.bolt_rounded, dark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'AI CHALLENGE OF THE DAY',
                  style: GoogleFonts.poppins(
                    color: dark ? _mint : _darkGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _isRecording
                ? 'Speak now — you have $_secondsLeft seconds'
                : 'Speak for 60 seconds about...',
            style: GoogleFonts.poppins(
              color: _secondaryText(context),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            '“${_topic.question}”',
            style: GoogleFonts.poppins(
              color: _textColor(context),
              fontSize: 19,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaChip(context, Icons.timer_outlined, '60 seconds'),
              _metaChip(context, Icons.bolt_outlined, _topic.difficulty),
              _metaChip(context, Icons.school_outlined, _topic.category),
            ],
          ),
          const SizedBox(height: 22),
          if (_isRecording)
            Column(
              children: [
                LinearProgressIndicator(
                  value: (60 - _secondsLeft) / 60,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(20),
                  backgroundColor:
                      dark ? Colors.white10 : _darkGreen.withOpacity(.08),
                  valueColor: const AlwaysStoppedAnimation(_mint),
                ),
                const SizedBox(height: 12),
              ],
            ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _isAnalysing
                    ? null
                    : _isRecording
                        ? _finishChallenge
                        : _startChallenge,
                icon:
                    Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded),
                label: Text(
                  _isAnalysing
                      ? 'Analysing...'
                      : _isRecording
                          ? 'Finish Challenge'
                          : 'Start Challenge',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: dark ? _mint : _darkGreen,
                  foregroundColor: dark ? _darkGreen : Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13)),
                  textStyle: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed:
                    (_isRecording || _isAnalysing) ? null : _anotherTopic,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Give me another topic'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: dark ? _mint : _darkGreen,
                  side: BorderSide(
                      color: dark
                          ? _mint.withOpacity(.45)
                          : _darkGreen.withOpacity(.30)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13)),
                  textStyle: GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _skillsPanel(BuildContext context) {
    final dark = _isDark(context);
    final hasData = _assessmentCount > 0 && _skills.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _innerDecoration(dark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBadge(Icons.radar_rounded, dark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your Speaking Skills',
                  style: GoogleFonts.poppins(
                    color: _textColor(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (hasData)
                Text(
                  '$_assessmentCount result${_assessmentCount == 1 ? '' : 's'}',
                  style: GoogleFonts.poppins(
                      color: _secondaryText(context), fontSize: 9),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loadingSkills)
            const SizedBox(
              height: 190,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!hasData)
            SizedBox(
              height: 190,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Text(
                    'Complete your first assessment to discover your speaking strengths.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: _secondaryText(context),
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 210,
              child: _RadarChart(
                values: _skills,
                dark: dark,
              ),
            ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color:
                  dark ? _mint.withOpacity(.06) : _darkGreen.withOpacity(.045),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    dark ? _mint.withOpacity(.14) : _darkGreen.withOpacity(.10),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline_rounded,
                    color: dark ? _mint : _darkGreen, size: 18),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Insight',
                        style: GoogleFonts.poppins(
                          color: dark ? _mint : _darkGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _insight(),
                        style: GoogleFonts.poppins(
                          color: _secondaryText(context),
                          fontSize: 10,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              ),
              label: const Text('View Details'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              iconAlignment: IconAlignment.end,
              style: TextButton.styleFrom(
                foregroundColor: dark ? _mint : _darkGreen,
                textStyle: GoogleFonts.poppins(
                    fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _innerDecoration(bool dark) => BoxDecoration(
        color: dark
            ? Colors.black.withOpacity(.18)
            : Colors.white.withOpacity(.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dark ? _mint.withOpacity(.16) : _darkGreen.withOpacity(.11),
        ),
      );

  Widget _iconBadge(IconData icon, bool dark) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: dark ? _mint.withOpacity(.10) : _darkGreen.withOpacity(.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: dark ? _mint.withOpacity(.18) : _darkGreen.withOpacity(.12),
          ),
        ),
        child: Icon(icon, color: dark ? _mint : _darkGreen, size: 19),
      );

  Widget _metaChip(BuildContext context, IconData icon, String text) {
    final dark = _isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withOpacity(.04)
            : Colors.white.withOpacity(.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dark ? _mint.withOpacity(.12) : _darkGreen.withOpacity(.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: dark ? _mint : _darkGreen),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: _secondaryText(context),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mascot({required bool compact}) => Center(
        child: Container(
          width: compact ? 86 : 108,
          height: compact ? 86 : 108,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: _mint.withOpacity(.18),
                  blurRadius: 34,
                  spreadRadius: 4),
            ],
          ),
          child: Image.asset(
            'assets/images/jellyfish.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      );
}

class _ChallengeTopic {
  const _ChallengeTopic({
    required this.question,
    required this.category,
    required this.difficulty,
  });

  final String question;
  final String category;
  final String difficulty;
}

class _RadarChart extends StatelessWidget {
  const _RadarChart({required this.values, required this.dark});

  final Map<String, double> values;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Pronunciation',
      'Fluency',
      'Grammar',
      'Vocabulary',
      'Clarity',
      'Pacing',
    ];

    final scores = labels.map((label) => values[label] ?? 0).toList();

    return CustomPaint(
      painter: _RadarPainter(
        labels: labels,
        scores: scores,
        dark: dark,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.labels,
    required this.scores,
    required this.dark,
  });

  final List<String> labels;
  final List<double> scores;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    const mint = Color(0xFF9AF0BF);
    const darkGreen = Color(0xFF01411C);
    final accent = dark ? mint : darkGreen;
    final grid = accent.withOpacity(dark ? .20 : .14);
    final center = Offset(size.width / 2, size.height / 2 + 2);
    final radius = math.min(size.width, size.height) * .31;
    final count = labels.length;

    final gridPaint = Paint()
      ..color = grid
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var level = 1; level <= 4; level++) {
      final path = Path();
      for (var i = 0; i < count; i++) {
        final angle = -math.pi / 2 + (2 * math.pi * i / count);
        final r = radius * level / 4;
        final point = Offset(
          center.dx + math.cos(angle) * r,
          center.dy + math.sin(angle) * r,
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / count);
      final edge = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      canvas.drawLine(center, edge, gridPaint);
    }

    final dataPath = Path();
    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / count);
      final r = radius * (scores[i].clamp(0, 100) / 100);
      final point = Offset(
        center.dx + math.cos(angle) * r,
        center.dy + math.sin(angle) * r,
      );
      if (i == 0) {
        dataPath.moveTo(point.dx, point.dy);
      } else {
        dataPath.lineTo(point.dx, point.dy);
      }
    }
    dataPath.close();

    canvas.drawPath(
      dataPath,
      Paint()
        ..color = accent.withOpacity(.16)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / count);
      final r = radius * (scores[i].clamp(0, 100) / 100);
      final point = Offset(
        center.dx + math.cos(angle) * r,
        center.dy + math.sin(angle) * r,
      );
      canvas.drawCircle(point, 3.2, Paint()..color = accent);
    }

    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / count);
      final labelRadius = radius + 25;
      final anchor = Offset(
        center.dx + math.cos(angle) * labelRadius,
        center.dy + math.sin(angle) * labelRadius,
      );
      final text = '${labels[i]} ${scores[i].round()}%';
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: GoogleFonts.poppins(
            color: dark ? Colors.white70 : const Color(0xFF52635A),
            fontSize: 8,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final dx = anchor.dx - painter.width / 2;
      final dy = anchor.dy - painter.height / 2;
      painter.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.scores != scores || oldDelegate.dark != dark;
}
