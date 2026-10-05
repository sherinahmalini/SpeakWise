import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../services/assessment_service.dart';
import 'result_screen.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen>
    with SingleTickerProviderStateMixin {
  // ============================================================
  // COLOURS
  // ============================================================

  static const Color darkPrimary = Color(0xFF01411C);
  static const Color lightPrimary = Color(0xFF9AF0BF);
  static const Color jellyfishGreen = Color(0xFF003314);

  static const Color darkBackground = Color(0xFF050805);
  static const Color darkCard = Color(0xFF09120D);

  // ============================================================
  // TTS
  // ============================================================

  final FlutterTts _tts = FlutterTts();

  bool isSpeaking = false;
  bool ttsReady = false;

  String selectedVoiceName = '';

  // ============================================================
  // AUDIO RECORDING
  // ============================================================

  final AudioRecorder _audioRecorder = AudioRecorder();

  String? recordingPath;

  bool isRecording = false;
  bool isProcessing = false;

  Timer? _recordingTimer;

  Duration recordingDuration = Duration.zero;

  // ============================================================
  // AI SERVICE
  // ============================================================

  final AssessmentService _assessmentService = AssessmentService();

  // ============================================================
  // PRESENTATION
  // ============================================================

  String? presentationName;
  String? presentationPath;

  bool presentationUploaded = false;
  bool isPresentationProcessing = false;
  bool isGeneratingSpeech = false;

  String? presentationContext;
  String? suggestedSpeech;

  final List<PlatformFile> uploadedImages = [];

  // ============================================================
  // AI FEEDBACK
  // ============================================================

  String? aiFeedback;

  String practiceStatus = 'Upload your presentation to begin.';

  // ============================================================
  // JELLYFISH ANIMATION
  // ============================================================

  late AnimationController _jellyfishController;

  late Animation<double> _jellyfishFloat;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _jellyfishController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _jellyfishFloat = Tween<double>(
      begin: -8,
      end: 8,
    ).animate(
      CurvedAnimation(
        parent: _jellyfishController,
        curve: Curves.easeInOut,
      ),
    );

    _jellyfishController.repeat(reverse: true);

    _setupTts();
  }

  // ============================================================
  // TTS SETUP
  // ============================================================

  Future<void> _setupTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.12);

      _tts.setStartHandler(() {
        if (!mounted) return;

        setState(() {
          isSpeaking = true;
        });
      });

      _tts.setCompletionHandler(() {
        if (!mounted) return;

        setState(() {
          isSpeaking = false;
        });
      });

      _tts.setCancelHandler(() {
        if (!mounted) return;

        setState(() {
          isSpeaking = false;
        });
      });

      _tts.setErrorHandler((message) {
        if (!mounted) return;

        setState(() {
          isSpeaking = false;
        });

        debugPrint('TTS error: $message');
      });

      await _selectFemaleVoice();

      if (!mounted) return;

      setState(() {
        ttsReady = true;
      });
    } catch (e) {
      debugPrint('TTS setup error: $e');
    }
  }

  // ============================================================
  // SELECT FEMALE VOICE
  // ============================================================

  Future<void> _selectFemaleVoice() async {
    try {
      final voices = await _tts.getVoices;

      if (voices is! List) {
        return;
      }

      // Prefer Microsoft Zira
      for (final voice in voices) {
        if (voice is! Map) continue;

        final String name = voice['name']?.toString() ?? '';

        final String locale = voice['locale']?.toString() ?? '';

        if (name.toLowerCase().contains('zira') &&
            locale.toLowerCase().contains('en')) {
          await _tts.setVoice({
            'name': name,
            'locale': locale,
          });

          selectedVoiceName = name;
          return;
        }
      }

      // Female voice fallback
      const List<String> femaleNames = [
        'female',
        'samantha',
        'karen',
        'susan',
        'hazel',
        'aria',
        'jenny',
      ];

      for (final voice in voices) {
        if (voice is! Map) continue;

        final String name = voice['name']?.toString() ?? '';

        final String locale = voice['locale']?.toString() ?? '';

        if (locale.toLowerCase().contains('en') &&
            femaleNames.any(
              (item) => name.toLowerCase().contains(item),
            )) {
          await _tts.setVoice({
            'name': name,
            'locale': locale,
          });

          selectedVoiceName = name;
          return;
        }
      }

      // Any English voice
      for (final voice in voices) {
        if (voice is! Map) continue;

        final String name = voice['name']?.toString() ?? '';

        final String locale = voice['locale']?.toString() ?? '';

        if (locale.toLowerCase().contains('en')) {
          await _tts.setVoice({
            'name': name,
            'locale': locale,
          });

          selectedVoiceName = name;
          return;
        }
      }
    } catch (e) {
      debugPrint('Voice selection error: $e');
    }
  }

  // ============================================================
  // SPEAK
  // ============================================================

  Future<void> _speak(String text) async {
    try {
      if (!ttsReady) {
        await _setupTts();
      }

      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('Speech error: $e');
    }
  }

  // ============================================================
  // STOP SPEAKING
  // ============================================================

  Future<void> _stopSpeaking() async {
    await _tts.stop();

    if (!mounted) return;

    setState(() {
      isSpeaking = false;
    });
  }

  // ============================================================
  // UPLOAD PRESENTATION
  // ============================================================

  Future<void> _uploadPresentation() async {
    if (isRecording || isProcessing || isPresentationProcessing) {
      return;
    }

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: true,
        withData: false,
        dialogTitle: 'Choose Presentation File',
        allowedExtensions: [
          'pdf',
          'ppt',
          'pptx',
          'doc',
          'docx',
          'png',
          'jpg',
          'jpeg',
          'webp',
        ],
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      const Set<String> imageExtensions = {
        'png',
        'jpg',
        'jpeg',
        'webp',
      };

      const Set<String> presentationExtensions = {
        'pdf',
        'ppt',
        'pptx',
        'doc',
        'docx',
      };

      PlatformFile? mainPresentation;
      final List<PlatformFile> newImages = [];

      for (final PlatformFile file in result.files) {
        final String extension = (file.extension ?? '').toLowerCase();

        if (imageExtensions.contains(extension)) {
          newImages.add(file);
        } else if (presentationExtensions.contains(extension)) {
          mainPresentation ??= file;
        }
      }

      // If the user selected only images, use the first image as
      // the main presentation and process the remaining images too.
      if (mainPresentation == null && newImages.isNotEmpty) {
        mainPresentation = newImages.removeAt(0);
      }

      if (mainPresentation == null) {
        _showMessage(
          'Please select a supported presentation or image file.',
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        isPresentationProcessing = true;
        presentationUploaded = false;
        presentationContext = null;
        suggestedSpeech = null;
        aiFeedback = null;

        presentationName = mainPresentation!.name;
        presentationPath = mainPresentation.path;

        uploadedImages
          ..clear()
          ..addAll(newImages);

        practiceStatus = 'Processing your presentation with SpeakWise AI...';
      });

      final Uint8List mainBytes = await _readPlatformFile(
        mainPresentation,
      );

      final Map<String, dynamic> mainResult =
          await _assessmentService.processPresentation(
        fileBytes: mainBytes,
        fileName: mainPresentation.name,
      );

      final List<String> contextParts = [];

      final String mainContext =
          (mainResult['presentationContext'] ?? '').toString().trim();

      if (mainContext.isNotEmpty) {
        contextParts.add(
          'Main presentation (${mainPresentation.name}):\n$mainContext',
        );
      }

      // The Laravel presentation endpoint accepts one file per request.
      // Extra images are therefore processed one-by-one and their AI
      // contexts are combined here before practice analysis.
      for (int i = 0; i < newImages.length; i++) {
        final PlatformFile image = newImages[i];

        if (!mounted) return;

        setState(() {
          practiceStatus =
              'Processing supporting image ${i + 1} of ${newImages.length}...';
        });

        final Uint8List imageBytes = await _readPlatformFile(
          image,
        );

        final Map<String, dynamic> imageResult =
            await _assessmentService.processPresentation(
          fileBytes: imageBytes,
          fileName: image.name,
        );

        final String imageContext =
            (imageResult['presentationContext'] ?? '').toString().trim();

        if (imageContext.isNotEmpty) {
          contextParts.add(
            'Supporting image ${i + 1} (${image.name}):\n$imageContext',
          );
        }
      }

      String combinedContext = contextParts.join('\n\n');

      // Laravel validates presentationContext at 50,000 characters.
      if (combinedContext.length > 50000) {
        combinedContext = combinedContext.substring(0, 50000);
      }

      if (combinedContext.trim().isEmpty) {
        throw Exception(
          'No readable presentation context was returned by the AI.',
        );
      }

      if (!mounted) return;

      setState(() {
        presentationContext = combinedContext.trim();
        presentationUploaded = true;
        isPresentationProcessing = false;

        if (uploadedImages.isEmpty) {
          practiceStatus =
              'Presentation processed. Ready to practise with AI context.';
        } else {
          practiceStatus =
              'Presentation and ${uploadedImages.length} image(s) processed. '
              'Ready to practise.';
        }
      });

      await _speak(
        'Your presentation has been processed. '
        'You are ready to practise.',
      );
    } catch (e) {
      debugPrint(
        'Presentation processing error: $e',
      );

      if (!mounted) return;

      setState(() {
        presentationUploaded = false;
        isPresentationProcessing = false;
        presentationContext = null;
        suggestedSpeech = null;
        practiceStatus = 'Presentation processing failed. Please try again.';
      });

      _showMessage(
        'Presentation processing failed: '
        '${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<Uint8List> _readPlatformFile(
    PlatformFile file,
  ) async {
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return file.bytes!;
    }

    final String? path = file.path;

    if (path == null || path.trim().isEmpty) {
      throw Exception(
        'Unable to access ${file.name}.',
      );
    }

    final File selectedFile = File(path);

    if (!await selectedFile.exists()) {
      throw Exception(
        '${file.name} could not be found.',
      );
    }

    final Uint8List bytes = await selectedFile.readAsBytes();

    if (bytes.isEmpty) {
      throw Exception(
        '${file.name} is empty.',
      );
    }

    return bytes;
  }

  // ============================================================
  // REMOVE PRESENTATION
  // ============================================================

  void _removePresentation() {
    if (isRecording || isProcessing || isPresentationProcessing) {
      return;
    }

    _tts.stop();

    setState(() {
      presentationName = null;
      presentationPath = null;
      presentationUploaded = false;
      presentationContext = null;
      suggestedSpeech = null;

      uploadedImages.clear();

      practiceStatus = 'Upload your presentation to begin.';

      aiFeedback = null;
    });
  }

  // ============================================================
  // START PRACTICE
  // ============================================================

  Future<void> _startPractice() async {
    if (!presentationUploaded ||
        presentationContext == null ||
        presentationContext!.trim().isEmpty) {
      _showMessage(
        'Please upload and process your presentation first.',
      );
      return;
    }

    if (isRecording || isProcessing || isPresentationProcessing) {
      return;
    }

    try {
      await _tts.stop();

      // ----------------------------------------------------------
      // MICROPHONE PERMISSION
      // ----------------------------------------------------------

      final bool hasPermission = await _audioRecorder.hasPermission();

      if (!hasPermission) {
        _showMessage(
          'Microphone permission is required to start practice.',
        );
        return;
      }

      // ----------------------------------------------------------
      // CREATE RECORDING FILE
      // ----------------------------------------------------------

      final Directory tempDirectory = await getTemporaryDirectory();

      final String fileName =
          'speakwise_practice_${DateTime.now().millisecondsSinceEpoch}.wav';

      final String path =
          '${tempDirectory.path}${Platform.pathSeparator}$fileName';

      // ----------------------------------------------------------
      // START RECORDING
      // ----------------------------------------------------------

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );

      recordingPath = path;

      recordingDuration = Duration.zero;

      _recordingTimer?.cancel();

      _recordingTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) {
          if (!mounted || !isRecording) {
            return;
          }

          setState(() {
            recordingDuration += const Duration(seconds: 1);
          });
        },
      );

      if (!mounted) return;

      setState(() {
        isRecording = true;

        practiceStatus = 'Live practice is recording. Start speaking now.';

        aiFeedback = null;
      });

      await _speak(
        'Your practice session has started. '
        'Start speaking when you are ready.',
      );
    } catch (e) {
      debugPrint(
        'Start recording error: $e',
      );

      _recordingTimer?.cancel();

      if (!mounted) return;

      setState(() {
        isRecording = false;

        practiceStatus =
            'Unable to start recording. Please check your microphone.';
      });

      _showMessage(
        'Unable to start microphone recording.',
      );
    }
  }

  // ============================================================
  // STOP PRACTICE + AI ANALYSIS
  // ============================================================

  Future<void> _stopPractice() async {
    if (!isRecording) {
      return;
    }

    File? recordingFile;

    try {
      await _tts.stop();

      _recordingTimer?.cancel();

      // ----------------------------------------------------------
      // STOP RECORDER
      // ----------------------------------------------------------

      final String? stoppedPath = await _audioRecorder.stop();

      if (!mounted) return;

      setState(() {
        isRecording = false;
        isProcessing = true;

        practiceStatus = 'Recording stopped. AI is analysing your speech...';
      });

      final String? finalPath = stoppedPath ?? recordingPath;

      if (finalPath == null || finalPath.isEmpty) {
        throw Exception(
          'Recording file was not created.',
        );
      }

      // ----------------------------------------------------------
      // CHECK FILE
      // ----------------------------------------------------------

      recordingFile = File(finalPath);

      if (!await recordingFile.exists()) {
        throw Exception(
          'Recording file does not exist.',
        );
      }

      final Uint8List bytes = await recordingFile.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception(
          'Recording file is empty.',
        );
      }

      debugPrint(
        'Practice recording path: $finalPath',
      );

      debugPrint(
        'Practice recording size: ${bytes.length} bytes',
      );

      // ----------------------------------------------------------
      // SEND TO BACKEND
      // ----------------------------------------------------------

      final Map<String, dynamic> result =
          await _assessmentService.analysePractice(
        fileBytes: bytes,
        fileName: 'speakwise_practice.wav',
        presentationContext: presentationContext!,
      );

      if (!mounted) return;

      // ----------------------------------------------------------
      // READ SCORES
      // ----------------------------------------------------------

      final double overallScore = _getScore(
        result['overallScore'] ?? result['score'] ?? result['overall'],
        fallback: 0,
      );

      final double pronunciation = _getScore(
        result['pronunciation'],
        fallback: 0,
      );

      final double fluency = _getScore(
        result['fluency'],
        fallback: 0,
      );

      final double grammar = _getScore(
        result['grammar'],
        fallback: 0,
      );

      final double vocabulary = _getScore(
        result['vocabulary'],
        fallback: 0,
      );

      final double speechClarity = _getScore(
        result['speechClarity'] ?? result['clarity'],
        fallback: 0,
      );

      final double pacing = _getScore(
        result['pacing'],
        fallback: 0,
      );

      final String feedback = result['feedback']?.toString() ??
          result['message']?.toString() ??
          'AI analysis completed successfully.';

      setState(() {
        isProcessing = false;

        practiceStatus = 'AI analysis completed.';

        aiFeedback = feedback;
      });

      // ----------------------------------------------------------
      // OPEN RESULT
      // ----------------------------------------------------------

      await Future.delayed(
        const Duration(milliseconds: 350),
      );

      if (!mounted) return;

      Navigator.push(
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

      // ----------------------------------------------------------
      // DELETE TEMP FILE
      // ----------------------------------------------------------

      try {
        if (await recordingFile.exists()) {
          await recordingFile.delete();
        }
      } catch (_) {}
    } catch (e) {
      debugPrint(
        'Practice AI error: $e',
      );

      if (!mounted) return;

      setState(() {
        isRecording = false;
        isProcessing = false;

        practiceStatus = 'AI analysis failed. Please try again.';
      });

      _showMessage(
        'AI analysis failed: '
        '${e.toString().replaceFirst('Exception: ', '')}',
      );

      try {
        if (recordingFile != null && await recordingFile.exists()) {
          await recordingFile.delete();
        }
      } catch (_) {}
    }
  }

  // ============================================================
  // SCORE PARSER
  // ============================================================

  double _getScore(
    dynamic value, {
    double fallback = 0,
  }) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        fallback;
  }

  // ============================================================
  // FORMAT TIMER
  // ============================================================

  String _formatDuration(
    Duration duration,
  ) {
    final int minutes = duration.inMinutes;

    final int seconds = duration.inSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // SUGGESTED SPEECH
  // ============================================================

  Future<void> _showSuggestedSpeech() async {
    if (!presentationUploaded ||
        presentationContext == null ||
        presentationContext!.trim().isEmpty) {
      _showMessage(
        'Upload and process a presentation first.',
      );
      return;
    }

    if (isGeneratingSpeech || isPresentationProcessing) {
      return;
    }

    try {
      if (suggestedSpeech == null || suggestedSpeech!.trim().isEmpty) {
        setState(() {
          isGeneratingSpeech = true;
          practiceStatus = 'Generating a suggested speech...';
        });

        final String generated =
            await _assessmentService.generateSuggestedSpeech(
          presentationContext: presentationContext!,
        );

        if (!mounted) return;

        setState(() {
          suggestedSpeech = generated.trim();
          isGeneratingSpeech = false;
          practiceStatus = 'Suggested speech is ready.';
        });
      }

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: darkCard,
            title: const Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: lightPrimary,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Suggested Speech',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 650,
              child: SingleChildScrollView(
                child: SelectableText(
                  suggestedSpeech!,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.6,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () {
                  if (isSpeaking) {
                    _stopSpeaking();
                  } else {
                    _speak(suggestedSpeech!);
                  }
                },
                icon: Icon(
                  isSpeaking
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  color: lightPrimary,
                ),
                label: Text(
                  isSpeaking ? 'STOP' : 'LISTEN',
                  style: const TextStyle(
                    color: lightPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  _stopSpeaking();
                  Navigator.pop(dialogContext);
                },
                child: const Text(
                  'CLOSE',
                  style: TextStyle(
                    color: lightPrimary,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint(
        'Suggested speech error: $e',
      );

      if (!mounted) return;

      setState(() {
        isGeneratingSpeech = false;
        practiceStatus = 'Unable to generate suggested speech.';
      });

      _showMessage(
        'Suggested speech failed: '
        '${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  // ============================================================
  // AI FEEDBACK
  // ============================================================

  void _showFeedback() {
    if (aiFeedback == null || aiFeedback!.trim().isEmpty) {
      _showMessage(
        isRecording
            ? 'Stop practice first so AI can analyse your speech.'
            : 'Complete a practice session to see AI feedback.',
      );

      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: darkCard,
          title: const Row(
            children: [
              Icon(
                Icons.psychology_alt_rounded,
                color: lightPrimary,
              ),
              SizedBox(width: 10),
              Text(
                'AI Feedback',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              aiFeedback!,
              style: const TextStyle(
                color: Colors.white70,
                height: 1.6,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'CLOSE',
                style: TextStyle(
                  color: lightPrimary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _recordingTimer?.cancel();

    _audioRecorder.dispose();

    _tts.stop();

    _jellyfishController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color background = isDark ? darkBackground : const Color(0xFFF4FFF8);

    final Color card = isDark ? darkCard : Colors.white;

    final Color text = isDark ? Colors.white : const Color(0xFF17231C);

    final Color secondary = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: background,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
          ),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'AI Practice',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (isSpeaking)
            IconButton(
              tooltip: 'Stop speaking',
              onPressed: _stopSpeaking,
              icon: const Icon(
                Icons.volume_off_rounded,
              ),
            ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1250,
              ),
              child: _buildDesktopLayout(
                context,
                isDark,
                card,
                text,
                secondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MAIN DESKTOP LAYOUT
  // ============================================================

  Widget _buildDesktopLayout(
    BuildContext context,
    bool isDark,
    Color card,
    Color text,
    Color secondary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --------------------------------------------------------
        // HEADER
        // --------------------------------------------------------

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: lightPrimary.withOpacity(.12),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: darkPrimary.withOpacity(.5),
                      ),
                    ),
                    child: const Text(
                      'SpeakWise AI',
                      style: TextStyle(
                        color: lightPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Improve Your Speaking',
                    style: TextStyle(
                      color: text,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Practise your presentation '
                    'with SpeakWise AI.',
                    style: TextStyle(
                      color: secondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            const Padding(
              padding: EdgeInsets.only(
                top: 15,
              ),
              child: Text(
                '“Small steps\nmake big progress!”',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: lightPrimary,
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 30),

        // --------------------------------------------------------
        // MAIN ROW
        // --------------------------------------------------------

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ====================================================
            // LEFT JELLYFISH PANEL
            // ====================================================

            SizedBox(
              width: 350,
              child: _buildJellyfishPanel(
                context,
                isDark,
                card,
                text,
                secondary,
              ),
            ),

            const SizedBox(width: 24),

            // ====================================================
            // RIGHT CONTENT
            // ====================================================

            Expanded(
              child: Column(
                children: [
                  _buildPresentationCard(
                    context,
                    isDark,
                    card,
                    text,
                    secondary,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFeatureCard(
                          context,
                          Icons.auto_awesome_rounded,
                          'Suggested Speech',
                          'Get ideas for what to say.',
                          _showSuggestedSpeech,
                          isDark,
                          card,
                          text,
                          secondary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildFeatureCard(
                          context,
                          Icons.psychology_alt_rounded,
                          'AI Feedback',
                          'See feedback from your practice.',
                          _showFeedback,
                          isDark,
                          card,
                          text,
                          secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildLivePracticeCard(
                    context,
                    isDark,
                    card,
                    text,
                    secondary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // JELLYFISH PANEL
  // ============================================================

  Widget _buildJellyfishPanel(
    BuildContext context,
    bool isDark,
    Color card,
    Color text,
    Color secondary,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        22,
      ),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: lightPrimary.withOpacity(.18),
        ),
        boxShadow: [
          BoxShadow(
            color: lightPrimary.withOpacity(.04),
            blurRadius: 30,
          ),
        ],
      ),
      child: Column(
        children: [
          // ------------------------------------------------------
          // JELLYFISH
          // ------------------------------------------------------

          AnimatedBuilder(
            animation: _jellyfishController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  0,
                  _jellyfishFloat.value,
                ),
                child: child,
              );
            },
            child: Container(
              height: 230,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: RadialGradient(
                  colors: [
                    lightPrimary.withOpacity(.10),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Image.asset(
                'assets/images/jellyfish.png',
                fit: BoxFit.contain,
              ),
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Joy',
            style: TextStyle(
              color: text,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 7),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: darkPrimary.withOpacity(.35),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Positive',
              style: TextStyle(
                color: lightPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(height: 18),

          // ------------------------------------------------------
          // SPEECH BUBBLE
          // ------------------------------------------------------

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: lightPrimary.withOpacity(.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: lightPrimary.withOpacity(.16),
              ),
            ),
            child: Text(
              'Hi! I’m Joy!\n'
              'I’m here to help you practise.\n'
              'You can do it!',
              style: TextStyle(
                color: secondary,
                fontSize: 14,
                height: 1.55,
              ),
            ),
          ),

          const SizedBox(height: 25),

          // ------------------------------------------------------
          // MICROPHONE
          // ------------------------------------------------------

          AnimatedContainer(
            duration: const Duration(
              milliseconds: 250,
            ),
            width: 125,
            height: 125,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: darkPrimary.withOpacity(.25),
              border: Border.all(
                color:
                    isRecording ? lightPrimary : lightPrimary.withOpacity(.55),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: lightPrimary.withOpacity(
                    isRecording ? .25 : .08,
                  ),
                  blurRadius: isRecording ? 35 : 20,
                  spreadRadius: isRecording ? 8 : 2,
                ),
              ],
            ),
            child: Icon(
              isRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
              color: lightPrimary,
              size: 52,
            ),
          ),

          const SizedBox(height: 15),

          Text(
            _formatDuration(
              recordingDuration,
            ),
            style: const TextStyle(
              color: lightPrimary,
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            isRecording ? 'I’m listening...' : 'Ready when you are!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: secondary,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 18),

          // ------------------------------------------------------
          // START BUTTON
          // ------------------------------------------------------

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isProcessing || isPresentationProcessing
                  ? null
                  : isRecording
                      ? _stopPractice
                      : _startPractice,
              icon: isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    ),
              label: Text(
                isProcessing
                    ? 'AI IS ANALYSING...'
                    : isRecording
                        ? 'STOP PRACTICE'
                        : 'START LIVE PRACTICE',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isRecording ? Colors.redAccent : darkPrimary,
                foregroundColor: lightPrimary,
                padding: const EdgeInsets.symmetric(
                  vertical: 17,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    15,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ------------------------------------------------------
          // HOW IT WORKS
          // ------------------------------------------------------

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: lightPrimary.withOpacity(.05),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: lightPrimary.withOpacity(.12),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: lightPrimary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Speak naturally. The AI will listen '
                    'to your speech and give you feedback '
                    'to help you improve.',
                    style: TextStyle(
                      color: secondary,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PRESENTATION CARD
  // ============================================================

  Widget _buildPresentationCard(
    BuildContext context,
    bool isDark,
    Color card,
    Color text,
    Color secondary,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: lightPrimary.withOpacity(.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: lightPrimary.withOpacity(.10),
                  borderRadius: BorderRadius.circular(
                    14,
                  ),
                ),
                child: Icon(
                  Icons.description_outlined,
                  color: lightPrimary,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Presentation',
                      style: TextStyle(
                        color: text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Upload your presentation.',
                      style: TextStyle(
                        color: secondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ------------------------------------------------------
          // UPLOAD AREA
          // ------------------------------------------------------

          InkWell(
            onTap: isRecording || isProcessing || isPresentationProcessing
                ? null
                : _uploadPresentation,
            borderRadius: BorderRadius.circular(
              18,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: 28,
                horizontal: 20,
              ),
              decoration: BoxDecoration(
                color: lightPrimary.withOpacity(.035),
                borderRadius: BorderRadius.circular(
                  18,
                ),
                border: Border.all(
                  color: lightPrimary.withOpacity(.35),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    isPresentationProcessing
                        ? Icons.hourglass_top_rounded
                        : presentationUploaded
                            ? Icons.check_circle_outline_rounded
                            : Icons.upload_file_rounded,
                    color: lightPrimary,
                    size: 42,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isPresentationProcessing
                        ? 'Processing presentation...'
                        : presentationUploaded
                            ? presentationName ?? 'Presentation processed'
                            : 'Add your presentation',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'PDF, PPT, PPTX, DOC, DOCX, '
                    'PNG, JPG, JPEG, WEBP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: secondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (presentationUploaded)
            Padding(
              padding: const EdgeInsets.only(
                top: 12,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: lightPrimary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Presentation ready as AI context.',
                      style: TextStyle(
                        color: secondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        isRecording || isProcessing || isPresentationProcessing
                            ? null
                            : _removePresentation,
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 19,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // FEATURE CARD
  // ============================================================

  Widget _buildFeatureCard(
    BuildContext context,
    IconData icon,
    String title,
    String description,
    VoidCallback onPressed,
    bool isDark,
    Color card,
    Color text,
    Color secondary,
  ) {
    return InkWell(
      onTap: isPresentationProcessing ? null : onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 155,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: lightPrimary.withOpacity(.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: lightPrimary.withOpacity(.10),
                borderRadius: BorderRadius.circular(
                  13,
                ),
              ),
              child: Icon(
                icon,
                color: lightPrimary,
              ),
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                color: text,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              description,
              style: TextStyle(
                color: secondary,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LIVE PRACTICE CARD
  // ============================================================

  Widget _buildLivePracticeCard(
    BuildContext context,
    bool isDark,
    Color card,
    Color text,
    Color secondary,
  ) {
    return InkWell(
      onTap: isProcessing || isPresentationProcessing
          ? null
          : isRecording
              ? _stopPractice
              : _startPractice,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 250,
        ),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isRecording ? lightPrimary : lightPrimary.withOpacity(.22),
            width: isRecording ? 1.5 : 1,
          ),
          boxShadow: isRecording
              ? [
                  BoxShadow(
                    color: lightPrimary.withOpacity(.12),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // ----------------------------------------------------
            // MIC ICON
            // ----------------------------------------------------

            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: darkPrimary.withOpacity(.28),
                borderRadius: BorderRadius.circular(
                  22,
                ),
                border: Border.all(
                  color: lightPrimary.withOpacity(.30),
                ),
              ),
              child: Icon(
                isRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: lightPrimary,
                size: 42,
              ),
            ),

            const SizedBox(width: 20),

            // ----------------------------------------------------
            // TEXT
            // ----------------------------------------------------

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isProcessing
                        ? 'AI is analysing...'
                        : isRecording
                            ? 'Live Practice'
                            : 'Start Live Practice',
                    style: TextStyle(
                      color: text,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    isRecording
                        ? _formatDuration(
                            recordingDuration,
                          )
                        : 'Practise with your AI character.',
                    style: TextStyle(
                      color: secondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    practiceStatus,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 15),

            // ----------------------------------------------------
            // ARROW
            // ----------------------------------------------------

            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: lightPrimary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isRecording ? Icons.stop_rounded : Icons.arrow_forward_rounded,
                color: darkPrimary,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
