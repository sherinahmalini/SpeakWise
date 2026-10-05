import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/gradient_button.dart';
import 'speech_upload_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  static const Color darkGreen = Color(0xFF01411C);
  static const Color lightGreen = Color(0xFF9AF0BF);

  // =========================================================
  // STATE
  // =========================================================

  final TextEditingController linkController = TextEditingController();

  bool isFile = true;
  bool isPickingFile = false;

  final List<PlatformFile> selectedFiles = [];

  String assessment = 'Individual';

  String? fileError;
  String? linkError;

  // =========================================================
  // THEME HELPERS
  // =========================================================

  bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  Color primaryColor(BuildContext context) {
    return isDark(context) ? darkGreen : lightGreen;
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
  // INPUT DECORATION
  // =========================================================

  InputDecoration input(
    BuildContext context,
    String label, {
    String? hint,
    String? errorText,
    IconData? icon,
  }) {
    final bool dark = isDark(context);
    final Color green = greenColor(context);

    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      labelStyle: GoogleFonts.poppins(
        color: secondaryTextColor(context),
        fontSize: 13,
      ),
      hintStyle: GoogleFonts.poppins(
        color: secondaryTextColor(context).withOpacity(.70),
        fontSize: 12,
      ),
      errorStyle: GoogleFonts.poppins(
        color: Colors.redAccent,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: icon == null
          ? null
          : Icon(
              icon,
              color: green,
              size: 20,
            ),
      filled: true,
      fillColor: dark ? const Color(0xFF101812) : const Color(0xFFF5F9F6),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: errorText != null
              ? Colors.redAccent
              : dark
                  ? Colors.white12
                  : darkGreen.withOpacity(.18),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: errorText != null ? Colors.redAccent : green,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.5,
        ),
      ),
    );
  }

  // =========================================================
  // PICK PRESENTATION FILES
  // =========================================================

  Future<void> pickFile() async {
    if (isPickingFile) {
      return;
    }

    setState(() {
      isPickingFile = true;
      fileError = null;
    });

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: true,
        withData: true,
        dialogTitle: 'Choose Presentation Files',
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

      if (!mounted) {
        return;
      }

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          for (final PlatformFile file in result.files) {
            final bool alreadyAdded = selectedFiles.any(
              (existingFile) =>
                  existingFile.name == file.name &&
                  existingFile.size == file.size,
            );

            if (!alreadyAdded) {
              selectedFiles.add(file);
            }
          }

          fileError = null;
        });
      }
    } catch (e) {
      debugPrint(
        'Presentation file picker error: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        fileError = 'Unable to select the presentation file.';
      });
    } finally {
      if (mounted) {
        setState(() {
          isPickingFile = false;
        });
      }
    }
  }

  // =========================================================
  // REMOVE FILE
  // =========================================================

  void removeFile(int index) {
    if (index < 0 || index >= selectedFiles.length) {
      return;
    }

    setState(() {
      selectedFiles.removeAt(index);
      fileError = null;
    });
  }

  // =========================================================
  // FILE ICON
  // =========================================================

  IconData getFileIcon(String? extension) {
    switch ((extension ?? '').toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;

      case 'ppt':
      case 'pptx':
        return Icons.slideshow_outlined;

      case 'doc':
      case 'docx':
        return Icons.description_outlined;

      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'webp':
        return Icons.image_outlined;

      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  // =========================================================
  // FILE TYPE
  // =========================================================

  String getFileTypeName(String? extension) {
    switch ((extension ?? '').toLowerCase()) {
      case 'pdf':
        return 'PDF document';

      case 'ppt':
      case 'pptx':
        return 'PowerPoint presentation';

      case 'doc':
      case 'docx':
        return 'Word document';

      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'webp':
        return 'Presentation image';

      default:
        return 'File';
    }
  }

  // =========================================================
  // FILE SIZE
  // =========================================================

  String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    final double kb = bytes / 1024;

    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }

    final double mb = kb / 1024;

    return '${mb.toStringAsFixed(1)} MB';
  }

  // =========================================================
  // URL VALIDATION
  // =========================================================

  bool isValidUrl(String value) {
    final Uri? uri = Uri.tryParse(
      value.trim(),
    );

    if (uri == null) {
      return false;
    }

    return (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  // =========================================================
  // VALIDATE PRESENTATION MATERIAL
  // =========================================================

  bool validateMaterial() {
    bool valid = true;

    setState(() {
      fileError = null;
      linkError = null;

      if (isFile && selectedFiles.isEmpty) {
        fileError = 'Please select your presentation file.';
        valid = false;
      }

      if (!isFile) {
        final String value = linkController.text.trim();

        if (value.isEmpty) {
          linkError = 'Please enter your presentation URL.';
          valid = false;
        } else if (!isValidUrl(value)) {
          linkError = 'Please enter a valid http:// or https:// URL.';
          valid = false;
        }
      }
    });

    return valid;
  }

  // =========================================================
  // CONTINUE
  // =========================================================

  void submitPresentation() {
    FocusScope.of(context).unfocus();

    if (isPickingFile) {
      return;
    }

    if (!validateMaterial()) {
      return;
    }

    final List<PlatformFile> files = List<PlatformFile>.from(
      selectedFiles,
    );

    final String presentationLink = isFile ? '' : linkController.text.trim();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpeechUploadScreen(
          assessmentType: assessment,
          presentationIsFile: isFile,
          presentationFiles: files,
          presentationLink: presentationLink,
        ),
      ),
    );
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    linkController.dispose();
    super.dispose();
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final bool dark = isDark(context);

    final Color text = textColor(context);
    final Color secondary = secondaryTextColor(context);
    final Color green = greenColor(context);
    final Color primary = primaryColor(context);

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
          color: green,
        ),
        title: Text(
          'Upload Presentation',
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
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            35,
          ),
          child: Center(
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(
                maxWidth: 900,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // =========================================
                  // HEADER
                  // =========================================

                  Text(
                    'Upload Your Presentation',
                    style: GoogleFonts.poppins(
                      color: text,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Upload your presentation material so '
                    'SpeakWise can use it as context during '
                    'your speech assessment.',
                    style: GoogleFonts.poppins(
                      color: secondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // =========================================
                  // PRESENTATION MATERIAL
                  // =========================================

                  _sectionTitle(
                    context,
                    'Presentation Material',
                    Icons.upload_file_rounded,
                  ),

                  const SizedBox(height: 14),

                  // =========================================
                  // FILE / LINK SELECTOR
                  // =========================================

                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            setState(() {
                              isFile = true;
                              linkError = null;
                            });
                          },
                          child: _modeCard(
                            context,
                            selected: isFile,
                            icon: Icons.folder_outlined,
                            title: 'Upload File',
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            setState(() {
                              isFile = false;
                              fileError = null;
                            });
                          },
                          child: _modeCard(
                            context,
                            selected: !isFile,
                            icon: Icons.link_rounded,
                            title: 'Paste Link',
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  if (isFile) _filePicker(context) else _linkField(context),

                  const SizedBox(height: 28),

                  // =========================================
                  // ASSESSMENT TYPE
                  // =========================================

                  _sectionTitle(
                    context,
                    'Assessment Type',
                    Icons.assessment_outlined,
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: [
                        ButtonSegment<String>(
                          value: 'Individual',
                          label: const Text(
                            'Individual',
                          ),
                          icon: Icon(
                            Icons.person_outline,
                            color: green,
                          ),
                        ),
                        ButtonSegment<String>(
                          value: 'Group',
                          label: const Text(
                            'Group',
                          ),
                          icon: Icon(
                            Icons.groups_outlined,
                            color: green,
                          ),
                        ),
                      ],
                      selected: {
                        assessment,
                      },
                      onSelectionChanged: (selection) {
                        setState(() {
                          assessment = selection.first;
                        });
                      },
                      style: ButtonStyle(
                        foregroundColor: WidgetStatePropertyAll(
                          text,
                        ),
                        side: WidgetStateProperty.resolveWith<BorderSide?>(
                          (states) {
                            return BorderSide(
                              color: states.contains(
                                WidgetState.selected,
                              )
                                  ? green
                                  : dark
                                      ? Colors.white12
                                      : darkGreen.withOpacity(
                                          .18,
                                        ),
                            );
                          },
                        ),
                        backgroundColor:
                            WidgetStateProperty.resolveWith<Color?>(
                          (states) {
                            return states.contains(
                              WidgetState.selected,
                            )
                                ? primary.withOpacity(
                                    .18,
                                  )
                                : cardColor(
                                    context,
                                  );
                          },
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // =========================================
                  // CONTINUE
                  // =========================================

                  GradientButton(
                    text: 'CONTINUE TO SPEECH ASSESSMENT',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: submitPresentation,
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
                          ? darkGreen.withOpacity(.30)
                          : lightGreen.withOpacity(.55),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: dark
                            ? lightGreen.withOpacity(
                                .25,
                              )
                            : darkGreen.withOpacity(
                                .18,
                              ),
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
                            'Your presentation material will '
                            'be carried into the speech '
                            'assessment so SpeakWise can use '
                            'it as assessment context.',
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
  // SECTION TITLE
  // =========================================================

  Widget _sectionTitle(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final Color green = greenColor(context);

    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: green.withOpacity(.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            color: green,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              color: textColor(context),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // MODE CARD
  // =========================================================

  Widget _modeCard(
    BuildContext context, {
    required bool selected,
    required IconData icon,
    required String title,
  }) {
    final bool dark = isDark(context);

    final Color green = greenColor(context);

    final Color primary = primaryColor(context);

    return AnimatedContainer(
      duration: const Duration(
        milliseconds: 200,
      ),
      decoration: BoxDecoration(
        color: selected ? primary.withOpacity(.12) : cardColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: selected
              ? green
              : dark
                  ? darkGreen.withOpacity(.55)
                  : darkGreen.withOpacity(.15),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              icon,
              color: green,
              size: 42,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: textColor(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // LINK FIELD
  // =========================================================

  Widget _linkField(
    BuildContext context,
  ) {
    return TextField(
      controller: linkController,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.done,
      autocorrect: false,
      style: GoogleFonts.poppins(
        color: textColor(context),
        fontSize: 13,
      ),
      onChanged: (_) {
        if (linkError != null) {
          setState(() {
            linkError = null;
          });
        }
      },
      decoration: input(
        context,
        'Presentation URL',
        hint: 'https://...',
        errorText: linkError,
        icon: Icons.link_rounded,
      ),
    );
  }

  // =========================================================
  // FILE PICKER
  // =========================================================

  Widget _filePicker(
    BuildContext context,
  ) {
    final bool dark = isDark(context);

    final Color text = textColor(context);

    final Color secondary = secondaryTextColor(context);

    final Color green = greenColor(context);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: isPickingFile ? null : pickFile,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: cardColor(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: fileError != null
                ? Colors.redAccent
                : dark
                    ? lightGreen.withOpacity(
                        .35,
                      )
                    : darkGreen.withOpacity(
                        .25,
                      ),
            width: 1.2,
          ),
        ),
        child: Column(
          children: [
            if (isPickingFile)
              SizedBox(
                width: 55,
                height: 55,
                child: CircularProgressIndicator(
                  color: green,
                  strokeWidth: 3,
                ),
              )
            else
              Icon(
                Icons.cloud_upload_rounded,
                size: 65,
                color: green,
              ),
            const SizedBox(height: 12),
            Text(
              isPickingFile
                  ? 'Opening File Picker...'
                  : selectedFiles.isEmpty
                      ? 'Choose Presentation Files'
                      : '${selectedFiles.length} '
                          'File${selectedFiles.length == 1 ? '' : 's'} Selected',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'PDF, PPT, PPTX, DOC, DOCX, '
              'PNG, JPG, JPEG, WEBP',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: secondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'You can select multiple files',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: secondary.withOpacity(.75),
                fontSize: 11,
              ),
            ),
            if (selectedFiles.isNotEmpty) ...[
              const SizedBox(height: 20),
              ...List.generate(
                selectedFiles.length,
                (index) {
                  final PlatformFile file = selectedFiles[index];

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(
                      bottom: 8,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: dark
                          ? Colors.white.withOpacity(.04)
                          : const Color(
                              0xFFF5F9F6,
                            ),
                      borderRadius: BorderRadius.circular(
                        14,
                      ),
                      border: Border.all(
                        color: dark
                            ? Colors.white12
                            : darkGreen.withOpacity(
                                .12,
                              ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: primaryColor(
                              context,
                            ).withOpacity(.15),
                            borderRadius: BorderRadius.circular(
                              10,
                            ),
                          ),
                          child: Icon(
                            getFileIcon(
                              file.extension,
                            ),
                            color: green,
                            size: 20,
                          ),
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                file.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(
                                height: 2,
                              ),
                              Text(
                                '${getFileTypeName(file.extension)} • '
                                '${formatFileSize(file.size)}',
                                style: GoogleFonts.poppins(
                                  color: secondary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove file',
                          onPressed: () {
                            removeFile(index);
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 20,
                          ),
                          color: secondary,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            if (fileError != null) ...[
              const SizedBox(height: 10),
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
    );
  }
}
