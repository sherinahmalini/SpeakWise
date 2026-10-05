import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/assessment_service.dart';
import 'result_screen.dart';

class AssessmentScreen extends StatefulWidget {
  final PlatformFile speechFile;
  final bool isVideo;

  const AssessmentScreen({
    super.key,
    required this.speechFile,
    required this.isVideo,
  });

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  // =========================================================
  // SERVICE
  // =========================================================

  final AssessmentService _assessmentService = AssessmentService();

  // =========================================================
  // TIMER
  // =========================================================

  Timer? _timer;

  int elapsedSeconds = 0;

  // This is only the visual processing timer.
  // The actual assessment finishes when the backend responds.
  final int totalSeconds = 10;

  // =========================================================
  // STATE
  // =========================================================

  bool isProcessing = true;

  bool isLoading = false;

  bool hasFinished = false;

  String? errorMessage;

  // =========================================================
  // COLOURS
  // =========================================================

  static const Color darkGreen = Color(0xFF01411C);

  static const Color lightGreen = Color(0xFF9AF0BF);

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {
    super.initState();

    startAssessment();
  }

  // =========================================================
  // START ASSESSMENT
  // =========================================================

  void startAssessment() {
    isLoading = true;

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (!isProcessing) {
          timer.cancel();
          return;
        }

        setState(() {
          elapsedSeconds++;

          // Keep the visual progress below 100%
          // until the backend actually responds.
          if (elapsedSeconds >= totalSeconds) {
            elapsedSeconds = totalSeconds - 1;
          }
        });
      },
    );

    analyseSpeech();
  }

  // =========================================================
  // ANALYSE SPEECH
  // =========================================================

  Future<void> analyseSpeech() async {
    try {
      final PlatformFile file = widget.speechFile;

      // -------------------------------------------------------
      // CHECK FILE BYTES
      // -------------------------------------------------------

      if (file.bytes == null) {
        throw Exception(
          'The selected file could not be read.',
        );
      }

      // -------------------------------------------------------
      // SEND FILE TO LARAVEL BACKEND
      // -------------------------------------------------------

      final Map<String, dynamic> result =
          await _assessmentService.analyseSpeech(
        fileBytes: file.bytes!,
        fileName: file.name,
        isVideo: widget.isVideo,
      );

      if (!mounted) {
        return;
      }

      // -------------------------------------------------------
      // STOP TIMER
      // -------------------------------------------------------

      _timer?.cancel();

      setState(() {
        elapsedSeconds = totalSeconds;

        isProcessing = false;

        isLoading = false;

        hasFinished = true;
      });

      // -------------------------------------------------------
      // OPEN RESULT SCREEN
      // -------------------------------------------------------

      await Future.delayed(
        const Duration(
          milliseconds: 500,
        ),
      );

      if (!mounted) {
        return;
      }

      openResult(result);
    } catch (e) {
      if (!mounted) {
        return;
      }

      _timer?.cancel();

      setState(() {
        isProcessing = false;

        isLoading = false;

        errorMessage = e.toString().replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  // =========================================================
  // OPEN RESULT
  // =========================================================

  void openResult(
    Map<String, dynamic> result,
  ) {
    if (!mounted) {
      return;
    }

    // -------------------------------------------------------
    // GET BACKEND VALUES
    // -------------------------------------------------------

    final double pronunciation = _toDouble(
      result['pronunciation'],
    );

    final double fluency = _toDouble(
      result['fluency'],
    );

    final double grammar = _toDouble(
      result['grammar'],
    );

    final double vocabulary = _toDouble(
      result['vocabulary'],
    );

    final double speechClarity = _toDouble(
      result['speechClarity'],
    );

    final double pacing = _toDouble(
      result['pacing'],
    );

    final double overallScore = _toDouble(
      result['overallScore'],
    );

    final String feedback = result['feedback']?.toString() ??
        'No feedback was returned by the assessment backend.';

    // -------------------------------------------------------
    // NAVIGATE TO RESULT
    // -------------------------------------------------------

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          overallScore: overallScore,
          pronunciation: pronunciation,
          fluency: fluency,
          grammar: grammar,
          vocabulary: vocabulary,
          speechClarity: speechClarity,
          pacing: pacing,
          feedback: feedback,
        ),
      ),
    );
  }

  // =========================================================
  // CONVERT VALUE TO DOUBLE
  // =========================================================

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value) ?? 0;
    }

    return 0;
  }

  // =========================================================
  // RETRY
  // =========================================================

  void retryAssessment() {
    setState(() {
      elapsedSeconds = 0;

      isProcessing = true;

      isLoading = true;

      hasFinished = false;

      errorMessage = null;
    });

    startAssessment();
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _timer?.cancel();

    super.dispose();
  }

  // =========================================================
  // FILE SIZE
  // =========================================================

  String formatFileSize(
    int bytes,
  ) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // =========================================================
  // TIME
  // =========================================================

  String formatTime(
    int seconds,
  ) {
    final int minutes = seconds ~/ 60;

    final int remainingSeconds = seconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    final Color green = dark ? lightGreen : darkGreen;

    final Color textColor = dark ? Colors.white : const Color(0xFF17221A);

    final Color secondaryText = dark ? Colors.white70 : const Color(0xFF5F6B63);

    final Color cardColor = dark ? const Color(0xFF0B1510) : Colors.white;

    final double progress = isProcessing
        ? (elapsedSeconds / totalSeconds).clamp(
            0.0,
            0.95,
          )
        : 1.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      // =======================================================
      // APP BAR
      // =======================================================

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          'AI Speech Assessment',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),

      // =======================================================
      // BODY
      // =======================================================

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(
              20,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 750,
              ),
              child: Column(
                children: [
                  const SizedBox(
                    height: 20,
                  ),

                  // =================================================
                  // AI ICON
                  // =================================================

                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: green.withOpacity(
                        .10,
                      ),
                      border: Border.all(
                        color: green.withOpacity(
                          .35,
                        ),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: green.withOpacity(
                            .12,
                          ),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: isProcessing
                        ? SizedBox(
                            width: 45,
                            height: 45,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: green,
                            ),
                          )
                        : Icon(
                            hasFinished
                                ? Icons.check_circle_outline_rounded
                                : Icons.error_outline_rounded,
                            size: 45,
                            color: hasFinished ? green : Colors.redAccent,
                          ),
                  ),

                  const SizedBox(
                    height: 25,
                  ),

                  // =================================================
                  // TITLE
                  // =================================================

                  Text(
                    isProcessing
                        ? 'Analysing Your Speech'
                        : hasFinished
                            ? 'Assessment Complete'
                            : 'Assessment Failed',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: textColor,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  Text(
                    isProcessing
                        ? 'SpeakWise is processing your ${widget.isVideo ? 'video' : 'audio'} recording.'
                        : hasFinished
                            ? 'Your speech has been analysed successfully.'
                            : 'SpeakWise could not complete the assessment.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: secondaryText,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(
                    height: 30,
                  ),

                  // =================================================
                  // FILE INFORMATION
                  // =================================================

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(
                      18,
                    ),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(
                        20,
                      ),
                      border: Border.all(
                        color: dark
                            ? Colors.white12
                            : const Color(
                                0xFFD7E5DB,
                              ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: green.withOpacity(
                              .10,
                            ),
                            borderRadius: BorderRadius.circular(
                              14,
                            ),
                          ),
                          child: Icon(
                            widget.isVideo
                                ? Icons.video_file_outlined
                                : Icons.audio_file_outlined,
                            color: green,
                            size: 25,
                          ),
                        ),
                        const SizedBox(
                          width: 14,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selected Recording',
                                style: GoogleFonts.poppins(
                                  color: secondaryText,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(
                                height: 3,
                              ),
                              Text(
                                widget.speechFile.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(
                                height: 3,
                              ),
                              Text(
                                '${widget.speechFile.extension?.toUpperCase() ?? ''} • '
                                '${formatFileSize(widget.speechFile.size)}',
                                style: GoogleFonts.poppins(
                                  color: secondaryText,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 25,
                  ),

                  // =================================================
                  // ERROR CARD
                  // =================================================

                  if (errorMessage != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(
                        bottom: 25,
                      ),
                      padding: const EdgeInsets.all(
                        18,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(
                          .08,
                        ),
                        borderRadius: BorderRadius.circular(
                          18,
                        ),
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(
                            .35,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            color: Colors.redAccent,
                            size: 30,
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Text(
                            'Backend Connection Error',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(
                            height: 6,
                          ),
                          Text(
                            errorMessage!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: secondaryText,
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(
                            height: 15,
                          ),
                          ElevatedButton.icon(
                            onPressed: retryAssessment,
                            icon: const Icon(
                              Icons.refresh_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'TRY AGAIN',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: green,
                              foregroundColor:
                                  dark ? Colors.black : Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // =================================================
                  // PROGRESS CARD
                  // =================================================

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(
                      25,
                    ),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(
                        24,
                      ),
                      border: Border.all(
                        color: green.withOpacity(
                          .20,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: green.withOpacity(
                            .05,
                          ),
                          blurRadius: 20,
                          offset: const Offset(
                            0,
                            8,
                          ),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          formatTime(
                            elapsedSeconds,
                          ),
                          style: GoogleFonts.poppins(
                            color: textColor,
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            20,
                          ),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            backgroundColor: green.withOpacity(
                              .10,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              green,
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 12,
                        ),
                        Text(
                          '${(progress * 100).round()}%',
                          style: GoogleFonts.poppins(
                            color: green,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        Text(
                          isProcessing
                              ? 'Sending your recording to the SpeakWise backend...'
                              : hasFinished
                                  ? 'Assessment results are ready.'
                                  : 'Assessment could not be completed.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: secondaryText,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 25,
                  ),

                  // =================================================
                  // ANALYSIS STATUS
                  // =================================================

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(
                      18,
                    ),
                    decoration: BoxDecoration(
                      color: green.withOpacity(
                        .08,
                      ),
                      borderRadius: BorderRadius.circular(
                        18,
                      ),
                      border: Border.all(
                        color: green.withOpacity(
                          .20,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        _statusItem(
                          context,
                          icon: Icons.record_voice_over_outlined,
                          title: 'Pronunciation',
                        ),
                        _statusItem(
                          context,
                          icon: Icons.speed_outlined,
                          title: 'Fluency',
                        ),
                        _statusItem(
                          context,
                          icon: Icons.spellcheck_outlined,
                          title: 'Grammar',
                        ),
                        _statusItem(
                          context,
                          icon: Icons.menu_book_outlined,
                          title: 'Vocabulary',
                        ),
                        _statusItem(
                          context,
                          icon: Icons.volume_up_outlined,
                          title: 'Speech Clarity',
                        ),
                        _statusItem(
                          context,
                          icon: Icons.timer_outlined,
                          title: 'Pacing',
                          last: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 25,
                  ),

                  // =================================================
                  // STATUS
                  // =================================================

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: isProcessing
                              ? green
                              : hasFinished
                                  ? Colors.green
                                  : Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(
                        width: 9,
                      ),
                      Text(
                        isProcessing
                            ? 'Assessment in progress'
                            : hasFinished
                                ? 'Assessment completed'
                                : 'Assessment failed',
                        style: GoogleFonts.poppins(
                          color: secondaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 25,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // STATUS ITEM
  // =========================================================

  Widget _statusItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    bool last = false,
  }) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    final Color green = dark ? lightGreen : darkGreen;

    final Color textColor = dark ? Colors.white : const Color(0xFF17221A);

    final Color secondaryText = dark ? Colors.white70 : const Color(0xFF5F6B63);

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 10,
      ),
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: dark
                      ? Colors.white10
                      : const Color(
                          0xFFE3ECE6,
                        ),
                ),
              ),
            ),
      child: Row(
        children: [
          Icon(
            icon,
            color: green,
            size: 20,
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Icon(
            isProcessing
                ? Icons.hourglass_empty_rounded
                : hasFinished
                    ? Icons.check_circle_outline_rounded
                    : Icons.error_outline_rounded,
            color: isProcessing
                ? secondaryText
                : hasFinished
                    ? green
                    : Colors.redAccent,
            size: 18,
          ),
        ],
      ),
    );
  }
}
