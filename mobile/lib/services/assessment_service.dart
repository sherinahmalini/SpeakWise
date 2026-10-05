import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class AssessmentService {
  // ============================================================
  // BACKEND
  // ============================================================

  static const String _baseUrl = 'http://127.0.0.1:8000';

  static const Duration _requestTimeout = Duration(minutes: 5);

  // ============================================================
  // SUPPORTED PRESENTATION FORMATS
  // ============================================================

  static const Set<String> _supportedPresentationExtensions = {
    'pdf',
    'ppt',
    'pptx',
    'doc',
    'docx',
    'png',
    'jpg',
    'jpeg',
    'webp',
  };

  // ============================================================
  // NORMAL SPEECH ASSESSMENT
  // ============================================================

  /// Existing SpeakWise speech/video assessment.
  ///
  /// POST /api/analyze
  Future<Map<String, dynamic>> analyseSpeech({
    required Uint8List fileBytes,
    required String fileName,
    required bool isVideo,
  }) async {
    _validateBytes(
      fileBytes,
      'The selected speech file is empty.',
    );

    final String cleanFileName = _validateFileName(
      fileName,
      'The selected speech file has no valid name.',
    );

    final Uri uri = Uri.parse(
      '$_baseUrl/api/analyze',
    );

    final http.MultipartRequest request = http.MultipartRequest(
      'POST',
      uri,
    );

    request.headers['Accept'] = 'application/json';

    request.fields['mediaType'] = isVideo ? 'video' : 'audio';

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: cleanFileName,
      ),
    );

    debugLog(
      'Normal assessment request: $uri',
    );

    final Map<String, dynamic> response = await _sendMultipart(
      request,
    );

    return _normalizeAssessmentResult(
      response,
    );
  }

  // ============================================================
  // AI PRACTICE - PROCESS PRESENTATION
  // ============================================================

  /// Uploads presentation material to Laravel.
  ///
  /// Supported:
  ///
  /// PDF
  /// PPT
  /// PPTX
  /// DOC
  /// DOCX
  /// PNG
  /// JPG
  /// JPEG
  /// WEBP
  ///
  /// POST /api/practice/presentation
  Future<Map<String, dynamic>> processPresentation({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    _validateBytes(
      fileBytes,
      'The selected presentation file is empty.',
    );

    final String cleanFileName = _validateFileName(
      fileName,
      'The selected presentation has no valid file name.',
    );

    final String extension = _extensionOf(
      cleanFileName,
    );

    if (extension.isEmpty) {
      throw Exception(
        'The selected presentation has no file extension.',
      );
    }

    if (!_supportedPresentationExtensions.contains(extension)) {
      throw Exception(
        'Unsupported presentation format. '
        'Please upload PDF, PPT, PPTX, DOC, DOCX, '
        'PNG, JPG, JPEG, or WEBP.',
      );
    }

    final Uri uri = Uri.parse(
      '$_baseUrl/api/practice/presentation',
    );

    final http.MultipartRequest request = http.MultipartRequest(
      'POST',
      uri,
    );

    request.headers['Accept'] = 'application/json';

    request.files.add(
      http.MultipartFile.fromBytes(
        'presentation',
        fileBytes,
        filename: cleanFileName,
      ),
    );

    debugLog(
      'Presentation processing request: $uri',
    );

    final Map<String, dynamic> response = await _sendMultipart(
      request,
    );

    final String context = _firstText(
      response,
      [
        'presentationContext',
        'context',
        'text',
      ],
    );

    if (context.isEmpty) {
      throw Exception(
        _extractErrorMessage(
          response,
          fallback: 'The backend did not return readable presentation content.',
        ),
      );
    }

    return {
      ...response,
      'success': true,
      'presentationContext': context,
      'fileName': _firstText(
        response,
        ['fileName'],
      ).isNotEmpty
          ? _firstText(
              response,
              ['fileName'],
            )
          : cleanFileName,
      'extension': _firstText(
        response,
        ['extension'],
      ).isNotEmpty
          ? _firstText(
              response,
              ['extension'],
            )
          : extension,
      'presentationType': _firstText(
        response,
        ['presentationType'],
      ),
      'processedExtension': _firstText(
        response,
        ['processedExtension'],
      ),
      'converted': response['converted'] == true,
      'visionProcessed': response['visionProcessed'] == true,
    };
  }

  // ============================================================
  // AI PRACTICE - SUGGESTED SPEECH
  // ============================================================

  /// Generates a suggested speech using the processed
  /// presentation context.
  ///
  /// POST /api/practice/suggested-speech
  Future<String> generateSuggestedSpeech({
    required String presentationContext,
  }) async {
    final String context = presentationContext.trim();

    if (context.isEmpty) {
      throw Exception(
        'Presentation content is empty. '
        'Please upload your presentation first.',
      );
    }

    final Uri uri = Uri.parse(
      '$_baseUrl/api/practice/suggested-speech',
    );

    debugLog(
      'Suggested speech request: $uri',
    );

    http.Response response;

    try {
      response = await http
          .post(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'presentationContext': context,
            }),
          )
          .timeout(
            _requestTimeout,
          );
    } on TimeoutException {
      throw Exception(
        'Suggested speech generation timed out. '
        'Please try again.',
      );
    } on http.ClientException catch (e) {
      throw Exception(
        'Unable to connect to the SpeakWise server: '
        '${e.message}',
      );
    } catch (e) {
      throw Exception(
        'Unable to generate suggested speech: '
        '${_cleanException(e)}',
      );
    }

    final Map<String, dynamic> data = _decodeResponse(
      response,
    );

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['success'] == false) {
      throw Exception(
        _extractErrorMessage(
          data,
          fallback: _statusMessage(
            response.statusCode,
          ),
        ),
      );
    }

    final String speech = _firstText(
      data,
      [
        'suggestedSpeech',
        'speech',
        'text',
      ],
    );

    if (speech.isEmpty) {
      throw Exception(
        'The AI returned an empty suggested speech.',
      );
    }

    return speech;
  }

  // ============================================================
  // AI PRACTICE - ANALYSE PRACTICE
  // ============================================================

  /// Analyses a recorded practice speech while using the
  /// uploaded presentation as AI context.
  ///
  /// POST /api/practice/analyze
  Future<Map<String, dynamic>> analysePractice({
    required Uint8List fileBytes,
    required String fileName,
    required String presentationContext,
  }) async {
    _validateBytes(
      fileBytes,
      'The practice recording is empty.',
    );

    final String cleanFileName = _validateFileName(
      fileName,
      'The practice recording has no valid file name.',
    );

    final String context = presentationContext.trim();

    if (context.isEmpty) {
      throw Exception(
        'Presentation content is missing. '
        'Please upload the presentation again.',
      );
    }

    final Uri uri = Uri.parse(
      '$_baseUrl/api/practice/analyze',
    );

    final http.MultipartRequest request = http.MultipartRequest(
      'POST',
      uri,
    );

    request.headers['Accept'] = 'application/json';

    request.fields['presentationContext'] = context;

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: cleanFileName,
      ),
    );

    debugLog(
      'Practice analysis request: $uri',
    );

    final Map<String, dynamic> response = await _sendMultipart(
      request,
    );

    return _normalizeAssessmentResult(
      response,
    );
  }

  // ============================================================
  // SEND MULTIPART
  // ============================================================

  Future<Map<String, dynamic>> _sendMultipart(
    http.MultipartRequest request,
  ) async {
    http.StreamedResponse streamedResponse;

    try {
      streamedResponse = await request.send().timeout(
            _requestTimeout,
          );
    } on TimeoutException {
      throw Exception(
        'The request timed out. '
        'Please check that the SpeakWise server is running '
        'and try again.',
      );
    } on http.ClientException catch (e) {
      throw Exception(
        'Unable to connect to the SpeakWise server: '
        '${e.message}',
      );
    } catch (e) {
      throw Exception(
        'Unable to connect to the SpeakWise server: '
        '${_cleanException(e)}',
      );
    }

    String body;

    try {
      body = await streamedResponse.stream.bytesToString();
    } catch (_) {
      throw Exception(
        'Unable to read the server response.',
      );
    }

    debugLog(
      'Response status: ${streamedResponse.statusCode}',
    );

    Map<String, dynamic> data;

    try {
      data = _decodeBody(
        body,
      );
    } catch (_) {
      if (streamedResponse.statusCode < 200 ||
          streamedResponse.statusCode >= 300) {
        throw Exception(
          _statusMessage(
            streamedResponse.statusCode,
          ),
        );
      }

      rethrow;
    }

    if (streamedResponse.statusCode < 200 ||
        streamedResponse.statusCode >= 300 ||
        data['success'] == false) {
      throw Exception(
        _extractErrorMessage(
          data,
          fallback: _statusMessage(
            streamedResponse.statusCode,
          ),
        ),
      );
    }

    return _unwrapData(
      data,
    );
  }

  // ============================================================
  // NORMALIZE ASSESSMENT RESULT
  // ============================================================

  Map<String, dynamic> _normalizeAssessmentResult(
    Map<String, dynamic> raw,
  ) {
    final Map<String, dynamic> data = _unwrapData(
      raw,
    );

    if (data['success'] == false) {
      throw Exception(
        _extractErrorMessage(
          data,
          fallback: 'Assessment failed.',
        ),
      );
    }

    final double pronunciation = _requiredScore(
      data,
      [
        'pronunciation',
        'pronunciationScore',
      ],
      'pronunciation',
    );

    final double fluency = _requiredScore(
      data,
      [
        'fluency',
        'fluencyScore',
      ],
      'fluency',
    );

    final double grammar = _requiredScore(
      data,
      [
        'grammar',
        'grammarScore',
      ],
      'grammar',
    );

    final double vocabulary = _requiredScore(
      data,
      [
        'vocabulary',
        'vocabularyScore',
      ],
      'vocabulary',
    );

    final double speechClarity = _requiredScore(
      data,
      [
        'speechClarity',
        'speech_clarity',
        'clarity',
        'clarityScore',
      ],
      'speech clarity',
    );

    final double pacing = _requiredScore(
      data,
      [
        'pacing',
        'pace',
        'pacingScore',
      ],
      'pacing',
    );

    final double overallScore = _requiredScore(
      data,
      [
        'overallScore',
        'overall_score',
        'overall',
        'score',
      ],
      'overall',
    );

    final String feedback = _firstText(
      data,
      [
        'feedback',
        'message',
        'analysis',
      ],
    );

    final String level = _firstText(
      data,
      [
        'level',
      ],
    );

    final String strongestArea = _firstText(
      data,
      [
        'strongestArea',
        'strongest_area',
      ],
    );

    final String weakestArea = _firstText(
      data,
      [
        'weakestArea',
        'weakest_area',
      ],
    );

    final String transcript = _firstText(
      data,
      [
        'transcript',
      ],
    );

    return {
      ...data,
      'success': true,
      'pronunciation': pronunciation,
      'fluency': fluency,
      'grammar': grammar,
      'vocabulary': vocabulary,
      'speechClarity': speechClarity,
      'pacing': pacing,
      'overallScore': overallScore,
      'feedback':
          feedback.isEmpty ? 'AI analysis completed successfully.' : feedback,
      'level': level,
      'strongestArea': strongestArea,
      'weakestArea': weakestArea,
      'transcript': transcript,
    };
  }

  // ============================================================
  // SCORE PARSER
  // ============================================================

  double _requiredScore(
    Map<String, dynamic> data,
    List<String> keys,
    String label,
  ) {
    dynamic value;

    for (final String key in keys) {
      if (data.containsKey(key) && data[key] != null) {
        value = data[key];
        break;
      }
    }

    if (value == null) {
      throw Exception(
        'The server response is missing the $label score.',
      );
    }

    final double? parsed;

    if (value is num) {
      parsed = value.toDouble();
    } else {
      parsed = double.tryParse(
        value.toString().trim(),
      );
    }

    if (parsed == null || parsed.isNaN || parsed.isInfinite) {
      throw Exception(
        'The server returned an invalid $label score.',
      );
    }

    if (parsed < 0 || parsed > 100) {
      throw Exception(
        'The server returned a $label score outside 0–100.',
      );
    }

    return parsed;
  }

  // ============================================================
  // RESPONSE DECODING
  // ============================================================

  Map<String, dynamic> _decodeResponse(
    http.Response response,
  ) {
    return _unwrapData(
      _decodeBody(
        response.body,
      ),
    );
  }

  Map<String, dynamic> _decodeBody(
    String body,
  ) {
    final String cleanBody = body.trim();

    if (cleanBody.isEmpty) {
      throw Exception(
        'The SpeakWise server returned an empty response.',
      );
    }

    dynamic decoded;

    try {
      decoded = jsonDecode(
        cleanBody,
      );
    } catch (_) {
      throw Exception(
        'The SpeakWise server returned an invalid response.',
      );
    }

    if (decoded is! Map) {
      throw Exception(
        'The SpeakWise server returned an unexpected response.',
      );
    }

    return Map<String, dynamic>.from(
      decoded,
    );
  }

  // ============================================================
  // UNWRAP RESPONSE
  // ============================================================

  Map<String, dynamic> _unwrapData(
    Map<String, dynamic> data,
  ) {
    const List<String> wrapperKeys = [
      'data',
      'result',
      'assessment',
    ];

    for (final String key in wrapperKeys) {
      final dynamic wrapped = data[key];

      if (wrapped is Map) {
        final Map<String, dynamic> inner = Map<String, dynamic>.from(
          wrapped,
        );

        if (!inner.containsKey('success') && data.containsKey('success')) {
          inner['success'] = data['success'];
        }

        if (!inner.containsKey('message') && data.containsKey('message')) {
          inner['message'] = data['message'];
        }

        if (!inner.containsKey('error') && data.containsKey('error')) {
          inner['error'] = data['error'];
        }

        return inner;
      }
    }

    return data;
  }

  // ============================================================
  // VALIDATION HELPERS
  // ============================================================

  void _validateBytes(
    Uint8List bytes,
    String message,
  ) {
    if (bytes.isEmpty) {
      throw Exception(
        message,
      );
    }
  }

  String _validateFileName(
    String fileName,
    String message,
  ) {
    final String cleanFileName = fileName.trim();

    if (cleanFileName.isEmpty) {
      throw Exception(
        message,
      );
    }

    return cleanFileName;
  }

  // ============================================================
  // ERROR MESSAGE
  // ============================================================

  String _extractErrorMessage(
    Map<String, dynamic> data, {
    required String fallback,
  }) {
    final List<dynamic> possibleMessages = [
      data['error'],
      data['message'],
      data['detail'],
    ];

    for (final dynamic value in possibleMessages) {
      if (value == null) {
        continue;
      }

      final String text = value.toString().trim();

      if (text.isNotEmpty) {
        return text;
      }
    }

    final dynamic errors = data['errors'];

    if (errors is Map) {
      for (final dynamic value in errors.values) {
        if (value is List && value.isNotEmpty) {
          final String text = value.first.toString().trim();

          if (text.isNotEmpty) {
            return text;
          }
        }

        if (value != null) {
          final String text = value.toString().trim();

          if (text.isNotEmpty) {
            return text;
          }
        }
      }
    }

    return fallback;
  }

  // ============================================================
  // HTTP STATUS MESSAGE
  // ============================================================

  String _statusMessage(
    int statusCode,
  ) {
    switch (statusCode) {
      case 400:
        return 'The server could not process the request.';

      case 401:
        return 'The request was not authorized.';

      case 403:
        return 'The request was not allowed.';

      case 404:
        return 'The SpeakWise API endpoint was not found.';

      case 408:
        return 'The server took too long to process the request.';

      case 413:
        return 'The selected file is too large.';

      case 415:
        return 'The selected file format is not supported.';

      case 422:
        return 'The uploaded information is invalid.';

      case 429:
        return 'Too many AI requests were made. '
            'Please wait and try again.';

      case 500:
        return 'The SpeakWise server encountered an error.';

      case 502:
      case 503:
      case 504:
        return 'The SpeakWise AI service is temporarily unavailable.';

      default:
        return 'The request failed with status $statusCode.';
    }
  }

  // ============================================================
  // TEXT HELPER
  // ============================================================

  String _firstText(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final String key in keys) {
      final dynamic value = data[key];

      if (value == null) {
        continue;
      }

      final String text = value.toString().trim();

      if (text.isNotEmpty) {
        return text;
      }
    }

    return '';
  }

  // ============================================================
  // FILE EXTENSION
  // ============================================================

  String _extensionOf(
    String fileName,
  ) {
    final String cleanName = fileName.trim();

    final int dotIndex = cleanName.lastIndexOf('.');

    if (dotIndex < 0 || dotIndex == cleanName.length - 1) {
      return '';
    }

    return cleanName
        .substring(
          dotIndex + 1,
        )
        .toLowerCase();
  }

  // ============================================================
  // CLEAN EXCEPTION
  // ============================================================

  String _cleanException(
    Object error,
  ) {
    final String message = error.toString().trim();

    if (message.startsWith('Exception: ')) {
      return message.substring(
        'Exception: '.length,
      );
    }

    return message;
  }

  // ============================================================
  // DEBUG
  // ============================================================

  void debugLog(
    String message,
  ) {
    // ignore: avoid_print
    print(
      '[AssessmentService] $message',
    );
  }
}
