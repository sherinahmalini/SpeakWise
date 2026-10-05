<?php

namespace App\Http\Controllers;

use App\Services\OpenAIService;
use App\Services\PresentationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Process;
use Illuminate\Support\Facades\Storage;
use RuntimeException;
use Throwable;

class AssessmentController extends Controller
{
    // =========================================================
    // NORMAL SPEECH ASSESSMENT
    // =========================================================

    /**
     * POST /api/analyze
     *
     * Existing normal SpeakWise assessment.
     */
    public function analyze(
        Request $request,
        OpenAIService $openAI
    ) {
        $request->validate([
            'file' => [
                'required',
                'file',
                'max:51200',
            ],

            'mediaType' => [
                'required',
                'in:audio,video',
            ],
        ]);

        $file =
            $request->file(
                'file'
            );

        if ($file === null) {
            return response()->json([
                'success' => false,
                'message' => 'No speech file was uploaded.',
            ], 422);
        }

        $originalFileName =
            $file->getClientOriginalName();

        $mediaType =
            (string) $request->input(
                'mediaType'
            );

        $temporaryDirectory =
            $this->getTemporaryDirectory();

        $storedPath =
            $file->storeAs(
                'temp',
                uniqid('speech_', true)
                . '_'
                . $this->safeFileName(
                    $originalFileName
                )
            );

        if ($storedPath === false) {
            return response()->json([
                'success' => false,
                'message' =>
                    'Unable to store the uploaded speech file.',
            ], 500);
        }

        $fullOriginalPath =
            Storage::disk('local')->path(
                $storedPath
            );

        $audioPath =
            $temporaryDirectory
            . DIRECTORY_SEPARATOR
            . uniqid(
                'normalized_',
                true
            )
            . '.wav';

        try {
            // -------------------------------------------------
            // VALIDATE UPLOAD
            // -------------------------------------------------

            $this->validatePhysicalFile(
                $fullOriginalPath,
                'Uploaded audio/video file'
            );

            // -------------------------------------------------
            // CONVERT TO STANDARD WAV
            // -------------------------------------------------

            $this->convertToWav(
                $fullOriginalPath,
                $audioPath,
                $mediaType
            );

            // -------------------------------------------------
            // TRANSCRIBE
            // -------------------------------------------------

            $transcript =
                $openAI->transcribe(
                    $audioPath
                );

            // -------------------------------------------------
            // EVALUATE
            // -------------------------------------------------

            $evaluation =
                $openAI->evaluate(
                    $transcript
                );

            // -------------------------------------------------
            // RESPONSE
            // -------------------------------------------------

            return response()->json(
                $this->buildEvaluationResponse(
                    evaluation: $evaluation,
                    transcript: $transcript,
                    extra: [
                        'mediaType' =>
                            $mediaType,

                        'fileName' =>
                            $originalFileName,

                        'fileSize' =>
                            $file->getSize(),
                    ]
                )
            );
        } catch (Throwable $e) {
            return response()->json([
                'success' => false,

                'message' =>
                    'Speech analysis failed.',

                'error' =>
                    $e->getMessage(),
            ], 500);
        } finally {
            $this->deleteFile(
                $fullOriginalPath
            );

            $this->deleteFile(
                $audioPath
            );
        }
    }

    // =========================================================
    // PROCESS PRESENTATION
    // =========================================================

    /**
     * POST /api/practice/presentation
     *
     * Supported:
     *
     * PDF
     * PPT
     * PPTX
     * DOC
     * DOCX
     * PNG
     * JPG
     * JPEG
     * WEBP
     *
     * Documents:
     * Extract readable text using PresentationService.
     *
     * Legacy PPT/DOC:
     * PresentationService converts them through LibreOffice.
     *
     * Images:
     * Send them to OpenAI vision.
     */
    public function processPresentation(
        Request $request,
        PresentationService $presentationService,
        OpenAIService $openAI
    ) {
        $request->validate([
            'presentation' => [
                'required',
                'file',
                'max:51200',
                'mimes:pdf,ppt,pptx,doc,docx,png,jpg,jpeg,webp',
            ],
        ]);

        $file =
            $request->file(
                'presentation'
            );

        if ($file === null) {
            return response()->json([
                'success' => false,

                'message' =>
                    'No presentation file was uploaded.',
            ], 422);
        }

        $originalFileName =
            $file->getClientOriginalName();

        $extension =
            strtolower(
                $file->getClientOriginalExtension()
            );

        $storedPath =
            $file->storeAs(
                'temp',
                uniqid(
                    'presentation_',
                    true
                )
                . '_'
                . $this->safeFileName(
                    $originalFileName
                )
            );

        if ($storedPath === false) {
            return response()->json([
                'success' => false,

                'message' =>
                    'Unable to store the uploaded presentation.',
            ], 500);
        }

        $fullPath =
            Storage::disk('local')->path(
                $storedPath
            );

        try {
            // -------------------------------------------------
            // CHECK PHYSICAL FILE
            // -------------------------------------------------

            $this->validatePhysicalFile(
                $fullPath,
                'Presentation file'
            );

            // -------------------------------------------------
            // DETECT / EXTRACT PRESENTATION
            // -------------------------------------------------

            $result =
                $presentationService->extractText(
                    $fullPath,
                    $originalFileName
                );

            $requiresVision =
                ($result['requiresVision'] ?? false)
                === true;

            $context = '';

            // -------------------------------------------------
            // IMAGE -> OPENAI VISION
            // -------------------------------------------------

            if ($requiresVision) {
                $context =
                    $openAI->analyzePresentationImage(
                        $fullPath,
                        $originalFileName
                    );
            }

            // -------------------------------------------------
            // DOCUMENT -> EXTRACTED TEXT
            // -------------------------------------------------

            else {
                $context =
                    trim(
                        (string) (
                            $result['text']
                            ?? ''
                        )
                    );
            }

            // -------------------------------------------------
            // VALIDATE CONTEXT
            // -------------------------------------------------

            $context =
                trim(
                    $context
                );

            if ($context === '') {
                throw new RuntimeException(
                    'No readable presentation content '
                    . 'could be extracted.'
                );
            }

            // -------------------------------------------------
            // RESPONSE
            // -------------------------------------------------

            return response()->json([
                'success' => true,

                'message' =>
                    'Presentation processed successfully.',

                'fileName' =>
                    $originalFileName,

                'extension' =>
                    $result['extension']
                    ?? $extension,

                'processedExtension' =>
                    $result['processedExtension']
                    ?? $extension,

                'presentationType' =>
                    $result['type']
                    ?? (
                        $requiresVision
                            ? 'image'
                            : 'document'
                    ),

                'presentationContext' =>
                    $context,

                'characterCount' =>
                    mb_strlen(
                        $context,
                        'UTF-8'
                    ),

                'requiresVision' =>
                    false,

                'visionProcessed' =>
                    $requiresVision,

                'converted' =>
                    (bool) (
                        $result['converted']
                        ?? false
                    ),
            ]);
        } catch (Throwable $e) {
            return response()->json([
                'success' => false,

                'message' =>
                    'Presentation processing failed.',

                'error' =>
                    $e->getMessage(),
            ], 500);
        } finally {
            $this->deleteFile(
                $fullPath
            );
        }
    }

    // =========================================================
    // GENERATE SUGGESTED SPEECH
    // =========================================================

    /**
     * POST /api/practice/suggested-speech
     *
     * JSON:
     *
     * {
     *   "presentationContext": "..."
     * }
     */
    public function suggestedSpeech(
        Request $request,
        OpenAIService $openAI
    ) {
        $request->validate([
            'presentationContext' => [
                'required',
                'string',
                'max:50000',
            ],
        ]);

        $presentationContext =
            trim(
                (string) $request->input(
                    'presentationContext'
                )
            );

        if ($presentationContext === '') {
            return response()->json([
                'success' => false,

                'message' =>
                    'Presentation context is empty.',
            ], 422);
        }

        try {
            $speech =
                $openAI->generateSuggestedSpeech(
                    $presentationContext
                );

            $speech =
                trim(
                    $speech
                );

            if ($speech === '') {
                throw new RuntimeException(
                    'The generated suggested speech is empty.'
                );
            }

            return response()->json([
                'success' => true,

                'message' =>
                    'Suggested speech generated successfully.',

                'suggestedSpeech' =>
                    $speech,
            ]);
        } catch (Throwable $e) {
            return response()->json([
                'success' => false,

                'message' =>
                    'Unable to generate suggested speech.',

                'error' =>
                    $e->getMessage(),
            ], 500);
        }
    }

    // =========================================================
    // PRACTICE SPEECH ANALYSIS
    // =========================================================

    /**
     * POST /api/practice/analyze
     *
     * Multipart:
     *
     * file
     * presentationContext
     */
    public function analyzePractice(
        Request $request,
        OpenAIService $openAI
    ) {
        $request->validate([
            'file' => [
                'required',
                'file',
                'max:51200',
            ],

            'presentationContext' => [
                'required',
                'string',
                'max:50000',
            ],
        ]);

        $speechFile =
            $request->file(
                'file'
            );

        if ($speechFile === null) {
            return response()->json([
                'success' => false,

                'message' =>
                    'No practice recording was uploaded.',
            ], 422);
        }

        $presentationContext =
            trim(
                (string) $request->input(
                    'presentationContext'
                )
            );

        if ($presentationContext === '') {
            return response()->json([
                'success' => false,

                'message' =>
                    'Presentation context is empty.',
            ], 422);
        }

        $originalFileName =
            $speechFile->getClientOriginalName();

        $temporaryDirectory =
            $this->getTemporaryDirectory();

        $storedPath =
            $speechFile->storeAs(
                'temp',
                uniqid(
                    'practice_',
                    true
                )
                . '_'
                . $this->safeFileName(
                    $originalFileName
                )
            );

        if ($storedPath === false) {
            return response()->json([
                'success' => false,

                'message' =>
                    'Unable to store the practice recording.',
            ], 500);
        }

        $fullSpeechPath =
            Storage::disk('local')->path(
                $storedPath
            );

        $audioPath =
            $temporaryDirectory
            . DIRECTORY_SEPARATOR
            . uniqid(
                'practice_normalized_',
                true
            )
            . '.wav';

        try {
            // -------------------------------------------------
            // CHECK RECORDING
            // -------------------------------------------------

            $this->validatePhysicalFile(
                $fullSpeechPath,
                'Practice recording'
            );

            // -------------------------------------------------
            // NORMALIZE AUDIO
            // -------------------------------------------------

            $this->convertToWav(
                $fullSpeechPath,
                $audioPath,
                'audio'
            );

            // -------------------------------------------------
            // TRANSCRIBE
            // -------------------------------------------------

            $transcript =
                $openAI->transcribe(
                    $audioPath
                );

            // -------------------------------------------------
            // EVALUATE AGAINST PRESENTATION
            // -------------------------------------------------

            $evaluation =
                $openAI->evaluatePractice(
                    $transcript,
                    $presentationContext
                );

            // -------------------------------------------------
            // RESPONSE
            // -------------------------------------------------

            return response()->json(
                $this->buildEvaluationResponse(
                    evaluation: $evaluation,
                    transcript: $transcript,
                    extra: [
                        'practiceMode' =>
                            true,

                        'presentationContextUsed' =>
                            true,

                        'fileName' =>
                            $originalFileName,

                        'fileSize' =>
                            $speechFile->getSize(),
                    ]
                )
            );
        } catch (Throwable $e) {
            return response()->json([
                'success' => false,

                'message' =>
                    'Practice analysis failed.',

                'error' =>
                    $e->getMessage(),
            ], 500);
        } finally {
            $this->deleteFile(
                $fullSpeechPath
            );

            $this->deleteFile(
                $audioPath
            );
        }
    }

    // =========================================================
    // TEMP DIRECTORY
    // =========================================================

    private function getTemporaryDirectory(): string
    {
        $temporaryDirectory =
            Storage::disk('local')->path(
                'temp'
            );

        if (!is_dir($temporaryDirectory)) {
            $created =
                mkdir(
                    $temporaryDirectory,
                    0755,
                    true
                );

            if (
                !$created &&
                !is_dir(
                    $temporaryDirectory
                )
            ) {
                throw new RuntimeException(
                    'Unable to create temporary directory.'
                );
            }
        }

        return $temporaryDirectory;
    }

    // =========================================================
    // VALIDATE PHYSICAL FILE
    // =========================================================

    private function validatePhysicalFile(
        string $path,
        string $description
    ): void {
        if (!file_exists($path)) {
            throw new RuntimeException(
                $description
                . ' was not found.'
            );
        }

        if (!is_file($path)) {
            throw new RuntimeException(
                $description
                . ' is not a valid file.'
            );
        }

        $size =
            filesize(
                $path
            );

        if (
            $size === false ||
            $size <= 0
        ) {
            throw new RuntimeException(
                $description
                . ' is empty.'
            );
        }
    }

    // =========================================================
    // FFMPEG
    // =========================================================

    private function convertToWav(
        string $inputPath,
        string $outputPath,
        string $mediaType
    ): void {
        $ffmpegPath =
            'C:/ffmpeg-9.0.1-essentials_build/bin/ffmpeg.exe';

        if (!file_exists($ffmpegPath)) {
            throw new RuntimeException(
                'FFmpeg executable was not found at: '
                . $ffmpegPath
            );
        }

        $process =
            Process::timeout(
                180
            )->run([
                $ffmpegPath,

                '-y',

                '-i',
                $inputPath,

                '-vn',

                '-ac',
                '1',

                '-ar',
                '16000',

                '-c:a',
                'pcm_s16le',

                $outputPath,
            ]);

        if ($process->failed()) {
            $errorOutput =
                trim(
                    $process->errorOutput()
                );

            if (
                mb_strlen(
                    $errorOutput,
                    'UTF-8'
                ) > 2000
            ) {
                $errorOutput =
                    mb_substr(
                        $errorOutput,
                        0,
                        2000,
                        'UTF-8'
                    )
                    . '...';
            }

            throw new RuntimeException(
                'FFmpeg could not convert the '
                . $mediaType
                . ' file to WAV.'
                . (
                    $errorOutput !== ''
                        ? ' FFmpeg error: '
                            . $errorOutput
                        : ''
                )
            );
        }

        if (!file_exists($outputPath)) {
            throw new RuntimeException(
                'FFmpeg completed, but the normalized '
                . 'WAV file was not created.'
            );
        }

        $audioSize =
            filesize(
                $outputPath
            );

        if (
            $audioSize === false ||
            $audioSize <= 0
        ) {
            throw new RuntimeException(
                'FFmpeg created an empty WAV file.'
            );
        }
    }

    // =========================================================
    // EVALUATION RESPONSE
    // =========================================================

    private function buildEvaluationResponse(
        array $evaluation,
        string $transcript,
        array $extra = []
    ): array {
        $response = [
            'success' =>
                true,

            'pronunciation' =>
                $this->score(
                    $evaluation['pronunciation']
                    ?? 0
                ),

            'fluency' =>
                $this->score(
                    $evaluation['fluency']
                    ?? 0
                ),

            'grammar' =>
                $this->score(
                    $evaluation['grammar']
                    ?? 0
                ),

            'vocabulary' =>
                $this->score(
                    $evaluation['vocabulary']
                    ?? 0
                ),

            'speechClarity' =>
                $this->score(
                    $evaluation['speechClarity']
                    ?? 0
                ),

            'pacing' =>
                $this->score(
                    $evaluation['pacing']
                    ?? 0
                ),

            'overallScore' =>
                $this->score(
                    $evaluation['overallScore']
                    ?? 0
                ),

            'feedback' =>
                trim(
                    (string) (
                        $evaluation['feedback']
                        ?? ''
                    )
                ),

            'level' =>
                trim(
                    (string) (
                        $evaluation['level']
                        ?? 'Beginner'
                    )
                ),

            'strongestArea' =>
                trim(
                    (string) (
                        $evaluation['strongestArea']
                        ?? ''
                    )
                ),

            'weakestArea' =>
                trim(
                    (string) (
                        $evaluation['weakestArea']
                        ?? ''
                    )
                ),

            'transcript' =>
                trim(
                    $transcript
                ),
        ];

        return array_merge(
            $response,
            $extra
        );
    }

    // =========================================================
    // SCORE
    // =========================================================

    private function score(
        mixed $value
    ): int {
        if (!is_numeric($value)) {
            return 0;
        }

        return max(
            0,
            min(
                100,
                (int) round(
                    (float) $value
                )
            )
        );
    }

    // =========================================================
    // SAFE FILE NAME
    // =========================================================

    private function safeFileName(
        string $fileName
    ): string {
        $fileName =
            basename(
                $fileName
            );

        $safe =
            preg_replace(
                '/[^A-Za-z0-9._-]/',
                '_',
                $fileName
            );

        if (
            $safe === null ||
            trim($safe) === ''
        ) {
            return 'upload';
        }

        return $safe;
    }

    // =========================================================
    // DELETE TEMP FILE
    // =========================================================

    private function deleteFile(
        ?string $path
    ): void {
        if (
            $path !== null &&
            $path !== '' &&
            file_exists($path) &&
            is_file($path)
        ) {
            @unlink(
                $path
            );
        }
    }
}