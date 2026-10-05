import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/gradient_button.dart';
import 'assessment_screen.dart';

class SpeechUploadScreen extends StatefulWidget {
  // These are still accepted so UploadScreen does not break,
  // but they are NOT displayed on this page.
  final String? assessmentType;
  final bool presentationIsFile;
  final List<PlatformFile> presentationFiles;
  final String? presentationLink;

  const SpeechUploadScreen({
    super.key,
    this.assessmentType,
    this.presentationIsFile = true,
    this.presentationFiles = const <PlatformFile>[],
    this.presentationLink,
  });

  @override
  State<SpeechUploadScreen> createState() => _SpeechUploadScreenState();
}

class _SpeechUploadScreenState extends State<SpeechUploadScreen> {
  // =========================================================
  // COLOURS
  // =========================================================

  static const Color darkGreen = Color(0xFF01411C);
  static const Color lightGreen = Color(0xFF9AF0BF);

  // =========================================================
  // FILE DATA
  // =========================================================

  PlatformFile? selectedSpeechFile;

  String? fileError;

  bool isVideo = true;
  bool isPickingFile = false;

  // =========================================================
  // FILE EXTENSIONS
  // =========================================================

  final List<String> videoExtensions = const [
    'mp4',
    'mov',
    'avi',
    'mkv',
  ];

  final List<String> audioExtensions = const [
    'mp3',
    'wav',
    'm4a',
    'aac',
    'ogg',
  ];

  // =========================================================
  // THEME HELPERS
  // =========================================================

  bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  Color greenColor(BuildContext context) {
    return isDark(context) ? lightGreen : darkGreen;
  }

  Color textColor(BuildContext context) {
    return isDark(context) ? Colors.white : const Color(0xFF17221A);
  }

  Color secondaryTextColor(BuildContext context) {
    return isDark(context) ? Colors.white70 : const Color(0xFF5F6B63);
  }

  Color cardColor(BuildContext context) {
    return isDark(context) ? const Color(0xFF0B1510) : Colors.white;
  }

  // =========================================================
  // PICK SPEECH FILE
  // =========================================================

  Future<void> pickSpeechFile() async {
    if (isPickingFile) {
      return;
    }

    setState(() {
      isPickingFile = true;
      fileError = null;
    });

    try {
      final List<String> allowedExtensions =
          isVideo ? videoExtensions : audioExtensions;

      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        withData: true,
        allowMultiple: false,
        dialogTitle: 'Choose ${isVideo ? 'Video' : 'Audio'} Recording',
      );

      if (!mounted) {
        return;
      }

      if (result == null || result.files.isEmpty) {
        setState(() {
          isPickingFile = false;
        });

        return;
      }

      final PlatformFile originalFile = result.files.single;

      final String extension = originalFile.extension?.toLowerCase() ?? '';

      final bool videoFile = videoExtensions.contains(extension);

      final bool audioFile = audioExtensions.contains(extension);

      // =====================================================
      // TYPE VALIDATION
      // =====================================================

      if (isVideo && !videoFile) {
        setState(() {
          fileError = 'Please select a video file: MP4, MOV, AVI or MKV.';
          isPickingFile = false;
          selectedSpeechFile = null;
        });

        return;
      }

      if (!isVideo && !audioFile) {
        setState(() {
          fileError = 'Please select an audio file: MP3, WAV, M4A, AAC or OGG.';
          isPickingFile = false;
          selectedSpeechFile = null;
        });

        return;
      }

      // =====================================================
      // GET FILE BYTES
      // =====================================================

      Uint8List? actualBytes;

      if (originalFile.bytes != null && originalFile.bytes!.isNotEmpty) {
        actualBytes = originalFile.bytes;
      }

      // Windows/Desktop fallback.
      if ((actualBytes == null || actualBytes.isEmpty) &&
          originalFile.path != null &&
          originalFile.path!.isNotEmpty) {
        try {
          final File actualFile = File(
            originalFile.path!,
          );

          if (await actualFile.exists()) {
            final Uint8List bytes = await actualFile.readAsBytes();

            if (bytes.isNotEmpty) {
              actualBytes = bytes;
            }
          }
        } catch (e) {
          debugPrint(
            'Unable to read speech file from path: $e',
          );
        }
      }

      if (!mounted) {
        return;
      }

      if (actualBytes == null || actualBytes.isEmpty) {
        setState(() {
          fileError = 'The selected file is empty or could not be read. '
              'Please select the recording again.';
          isPickingFile = false;
          selectedSpeechFile = null;
        });

        return;
      }

      // =====================================================
      // REBUILD PLATFORM FILE
      // =====================================================

      final PlatformFile readableFile = PlatformFile(
        name: originalFile.name,
        size: actualBytes.length,
        bytes: actualBytes,
        path: originalFile.path,
      );

      if (readableFile.size <= 0 ||
          readableFile.bytes == null ||
          readableFile.bytes!.isEmpty) {
        setState(() {
          fileError = 'The selected file contains no readable data.';
          isPickingFile = false;
          selectedSpeechFile = null;
        });

        return;
      }

      // =====================================================
      // SUCCESS
      // =====================================================

      setState(() {
        selectedSpeechFile = readableFile;
        fileError = null;
        isPickingFile = false;
      });

      debugPrint(
        'Selected speech file: ${readableFile.name}',
      );

      debugPrint(
        'Extension: ${readableFile.extension}',
      );

      debugPrint(
        'Actual size: ${readableFile.size} bytes',
      );

      debugPrint(
        'Actual bytes: ${readableFile.bytes?.length ?? 0}',
      );
    } catch (e) {
      debugPrint(
        'Speech file picker error: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        fileError = 'Unable to select the file. Please try again.';
        isPickingFile = false;
      });
    }
  }

  // =========================================================
  // VALIDATE SPEECH
  // =========================================================

  bool validateSpeech() {
    if (selectedSpeechFile == null) {
      setState(() {
        fileError = 'Please upload your speech recording.';
      });

      return false;
    }

    final PlatformFile file = selectedSpeechFile!;

    if (file.bytes == null || file.bytes!.isEmpty) {
      setState(() {
        fileError = 'The selected file cannot be read. '
            'Please select it again.';
      });

      return false;
    }

    if (file.size <= 0) {
      setState(() {
        fileError = 'The selected file is empty. '
            'Please select another recording.';
      });

      return false;
    }

    final String extension = file.extension?.toLowerCase() ?? '';

    if (isVideo && !videoExtensions.contains(extension)) {
      setState(() {
        fileError = 'Please select a video file: MP4, MOV, AVI or MKV.';
      });

      return false;
    }

    if (!isVideo && !audioExtensions.contains(extension)) {
      setState(() {
        fileError = 'Please select an audio file: '
            'MP3, WAV, M4A, AAC or OGG.';
      });

      return false;
    }

    setState(() {
      fileError = null;
    });

    return true;
  }

  // =========================================================
  // CONTINUE TO ASSESSMENT
  // =========================================================

  void continueToAssessment() {
    if (isPickingFile) {
      return;
    }

    if (!validateSpeech()) {
      return;
    }

    final PlatformFile file = selectedSpeechFile!;

    if (file.bytes == null || file.bytes!.isEmpty || file.size <= 0) {
      setState(() {
        fileError = 'The selected recording has no readable data. '
            'Please select it again.';
      });

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssessmentScreen(
          speechFile: file,
          isVideo: isVideo,
        ),
      ),
    );
  }

  // =========================================================
  // FORMAT FILE SIZE
  // =========================================================

  String formatFileSize(int bytes) {
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
  // CLEAR SELECTED FILE
  // =========================================================

  void clearSelectedFile() {
    setState(() {
      selectedSpeechFile = null;
      fileError = null;
    });
  }

  // =========================================================
  // CHANGE SPEECH TYPE
  // =========================================================

  void changeSpeechType(bool video) {
    if (isPickingFile) {
      return;
    }

    if (isVideo == video) {
      return;
    }

    setState(() {
      isVideo = video;
      selectedSpeechFile = null;
      fileError = null;
    });
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final bool dark = isDark(context);

    final Color primary = dark ? darkGreen : lightGreen;

    final Color green = dark ? lightGreen : darkGreen;

    final Color text = textColor(context);

    final Color secondary = secondaryTextColor(context);

    final Color card = cardColor(context);

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
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(
            Icons.arrow_back_rounded,
            color: text,
          ),
        ),
        title: Text(
          'Speech Assessment',
          style: GoogleFonts.poppins(
            color: text,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // =====================================================
      // BODY
      // =====================================================

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            35,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1050,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // =========================================
                  // HEADER
                  // =========================================

                  Text(
                    'Upload Your Presentation Speech',
                    style: GoogleFonts.poppins(
                      color: text,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'SpeakWise will analyse your communication '
                    'and speaking performance.',
                    style: GoogleFonts.poppins(
                      color: secondary,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // =========================================
                  // SPEECH RECORDING
                  // =========================================

                  Text(
                    'Speech Recording',
                    style: GoogleFonts.poppins(
                      color: text,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    'Choose whether your presentation recording '
                    'is a video or audio file.',
                    style: GoogleFonts.poppins(
                      color: secondary,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 15),

                  // =========================================
                  // VIDEO / AUDIO
                  // =========================================

                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: isPickingFile
                              ? null
                              : () {
                                  changeSpeechType(true);
                                },
                          child: _typeCard(
                            context,
                            icon: Icons.videocam_outlined,
                            title: 'Video',
                            selected: isVideo,
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: GestureDetector(
                          onTap: isPickingFile
                              ? null
                              : () {
                                  changeSpeechType(false);
                                },
                          child: _typeCard(
                            context,
                            icon: Icons.mic_none_rounded,
                            title: 'Audio',
                            selected: !isVideo,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  // =========================================
                  // RECORDING UPLOAD
                  // =========================================

                  GestureDetector(
                    onTap: isPickingFile ? null : pickSpeechFile,
                    child: AnimatedContainer(
                      duration: const Duration(
                        milliseconds: 200,
                      ),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 35,
                      ),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: fileError != null
                              ? Colors.redAccent
                              : selectedSpeechFile != null
                                  ? green
                                  : primary.withOpacity(.45),
                          width: selectedSpeechFile != null ? 1.5 : 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withOpacity(.06),
                            blurRadius: 18,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 75,
                            height: 75,
                            decoration: BoxDecoration(
                              color: green.withOpacity(.10),
                              shape: BoxShape.circle,
                            ),
                            child: isPickingFile
                                ? Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: green,
                                    ),
                                  )
                                : Icon(
                                    selectedSpeechFile != null
                                        ? Icons.check_circle_outline_rounded
                                        : isVideo
                                            ? Icons.cloud_upload_rounded
                                            : Icons.audio_file_rounded,
                                    size: 40,
                                    color: green,
                                  ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            selectedSpeechFile != null
                                ? selectedSpeechFile!.name
                                : isPickingFile
                                    ? 'Opening File Picker...'
                                    : 'Choose ${isVideo ? 'Video' : 'Audio'} Recording',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: text,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (selectedSpeechFile != null)
                            Text(
                              '${selectedSpeechFile!.extension?.toUpperCase() ?? ''} • '
                              '${formatFileSize(selectedSpeechFile!.size)}',
                              style: GoogleFonts.poppins(
                                color: secondary,
                                fontSize: 11,
                              ),
                            )
                          else
                            Text(
                              isVideo
                                  ? 'MP4, MOV, AVI or MKV'
                                  : 'MP3, WAV, M4A, AAC or OGG',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: secondary,
                                fontSize: 12,
                              ),
                            ),
                          const SizedBox(height: 12),
                          if (!isPickingFile)
                            Text(
                              selectedSpeechFile != null
                                  ? 'Tap to choose another file'
                                  : 'Tap to browse files',
                              style: GoogleFonts.poppins(
                                color: green,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (selectedSpeechFile != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 12,
                              ),
                              child: TextButton.icon(
                                onPressed: clearSelectedFile,
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: Colors.redAccent,
                                ),
                                label: Text(
                                  'Remove File',
                                  style: GoogleFonts.poppins(
                                    color: Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          if (fileError != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              fileError!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // =========================================
                  // AI ANALYSIS
                  // =========================================

                  Text(
                    'What will AI evaluate?',
                    style: GoogleFonts.poppins(
                      color: text,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 15),

                  _analysisItem(
                    context,
                    Icons.record_voice_over_outlined,
                    'Pronunciation',
                    'How clearly you pronounce words.',
                  ),

                  _analysisItem(
                    context,
                    Icons.speed_outlined,
                    'Fluency',
                    'Speaking flow, pauses and hesitation.',
                  ),

                  _analysisItem(
                    context,
                    Icons.auto_awesome_outlined,
                    'Vocabulary',
                    'The vocabulary used during your speech.',
                  ),

                  _analysisItem(
                    context,
                    Icons.spellcheck_outlined,
                    'Grammar',
                    'Grammar accuracy in your speech.',
                  ),

                  _analysisItem(
                    context,
                    Icons.volume_up_outlined,
                    'Speech Clarity',
                    'How clearly your speech can be understood.',
                  ),

                  _analysisItem(
                    context,
                    Icons.timer_outlined,
                    'Pacing',
                    'Whether your speaking speed is appropriate.',
                  ),

                  const SizedBox(height: 25),

                  GradientButton(
                    text: isPickingFile
                        ? 'PLEASE WAIT...'
                        : 'START AI ASSESSMENT',
                    icon: Icons.auto_awesome_rounded,
                    onPressed: isPickingFile ? () {} : continueToAssessment,
                  ),

                  const SizedBox(height: 20),

                  // =========================================
                  // INFORMATION
                  // =========================================

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: dark
                          ? darkGreen.withOpacity(.16)
                          : lightGreen.withOpacity(.55),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: dark
                            ? lightGreen.withOpacity(.30)
                            : darkGreen.withOpacity(.18),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: green,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your selected recording will be '
                            'sent to SpeakWise for speech assessment.',
                            style: GoogleFonts.poppins(
                              color: secondary,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // VIDEO / AUDIO TYPE CARD
  // =========================================================

  Widget _typeCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool selected,
  }) {
    final bool dark = isDark(context);

    final Color green = greenColor(context);
    final Color text = textColor(context);
    final Color card = cardColor(context);

    return AnimatedContainer(
      duration: const Duration(
        milliseconds: 200,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: selected ? green.withOpacity(.12) : card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? green
              : dark
                  ? Colors.white12
                  : const Color(0xFFD7E5DB),
          width: selected ? 1.5 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: green.withOpacity(.08),
                  blurRadius: 15,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: green,
            size: 38,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            selected ? 'Selected' : 'Tap to select',
            style: GoogleFonts.poppins(
              color: green,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ANALYSIS ITEM
  // =========================================================

  Widget _analysisItem(
    BuildContext context,
    IconData icon,
    String title,
    String descriptionText,
  ) {
    final bool dark = isDark(context);

    final Color green = greenColor(context);
    final Color text = textColor(context);
    final Color secondary = secondaryTextColor(context);
    final Color card = cardColor(context);

    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dark ? Colors.white12 : const Color(0xFFD7E5DB),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: green.withOpacity(.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: green,
              size: 22,
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
                    color: text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  descriptionText,
                  style: GoogleFonts.poppins(
                    color: secondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
