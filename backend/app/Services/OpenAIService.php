<?php

namespace App\Services;

use GuzzleHttp\Client;
use RuntimeException;
use Throwable;

class OpenAIService
{
    private Client $client;

    // =========================================================
    // CONSTRUCTOR
    // =========================================================

    public function __construct()
    {
        $apiKey = config('services.openai.api_key');

        if (
            !is_string($apiKey) ||
            trim($apiKey) === ''
        ) {
            throw new RuntimeException(
                'OPENAI_API_KEY is not configured.'
            );
        }

        $this->client = new Client([
            'base_uri' => 'https://api.openai.com/v1/',

            'headers' => [
                'Authorization' =>
                    'Bearer ' . trim($apiKey),

                'Accept' =>
                    'application/json',
            ],

            'timeout' => 180,

            'connect_timeout' => 30,
        ]);
    }

    // =========================================================
    // TRANSCRIBE AUDIO
    // =========================================================

    /**
     * Transcribe an audio file.
     */
    public function transcribe(
        string $audioPath
    ): string {
        if (!file_exists($audioPath)) {
            throw new RuntimeException(
                'Audio file was not found.'
            );
        }

        if (!is_file($audioPath)) {
            throw new RuntimeException(
                'The audio path is not a valid file.'
            );
        }

        $fileSize = filesize($audioPath);

        if (
            $fileSize === false ||
            $fileSize <= 0
        ) {
            throw new RuntimeException(
                'Audio file is empty.'
            );
        }

        $extension = strtolower(
            pathinfo(
                $audioPath,
                PATHINFO_EXTENSION
            )
        );

        $mimeType = match ($extension) {
            'mp3' =>
                'audio/mpeg',

            'wav' =>
                'audio/wav',

            'm4a' =>
                'audio/mp4',

            'mp4' =>
                'audio/mp4',

            'mpeg', 'mpga' =>
                'audio/mpeg',

            'webm' =>
                'audio/webm',

            default =>
                'application/octet-stream',
        };

        $fileName = basename(
            $audioPath
        );

        $audioStream = fopen(
            $audioPath,
            'rb'
        );

        if ($audioStream === false) {
            throw new RuntimeException(
                'Unable to read the audio file.'
            );
        }

        try {
            $response =
                $this->client->post(
                    'audio/transcriptions',
                    [
                        'multipart' => [
                            [
                                'name' =>
                                    'file',

                                'contents' =>
                                    $audioStream,

                                'filename' =>
                                    $fileName,

                                'headers' => [
                                    'Content-Type' =>
                                        $mimeType,
                                ],
                            ],

                            [
                                'name' =>
                                    'model',

                                'contents' =>
                                    'gpt-4o-transcribe',
                            ],

                            [
                                'name' =>
                                    'response_format',

                                'contents' =>
                                    'json',
                            ],
                        ],
                    ]
                );
        } catch (Throwable $e) {
            throw new RuntimeException(
                'OpenAI transcription failed: '
                . $this->friendlyApiError($e),
                0,
                $e
            );
        } finally {
            if (is_resource($audioStream)) {
                fclose($audioStream);
            }
        }

        $body =
            $response
                ->getBody()
                ->getContents();

        $data =
            json_decode(
                $body,
                true
            );

        if (!is_array($data)) {
            throw new RuntimeException(
                'Invalid transcription response from OpenAI.'
            );
        }

        $transcript =
            trim(
                (string) (
                    $data['text']
                    ?? ''
                )
            );

        if ($transcript === '') {
            throw new RuntimeException(
                'OpenAI returned an empty transcription.'
            );
        }

        return $transcript;
    }

    // =========================================================
    // NORMAL SPEECH ASSESSMENT
    // =========================================================

    public function evaluate(
        string $transcript
    ): array {
        $transcript =
            trim(
                $transcript
            );

        if ($transcript === '') {
            throw new RuntimeException(
                'Cannot evaluate an empty transcript.'
            );
        }

        $safeTranscript =
            $this->limitText(
                $transcript,
                30000
            );

        $prompt =
            "Evaluate this student presentation transcript.\n\n"
            . "STUDENT SPEECH TRANSCRIPT:\n"
            . $safeTranscript
            . "\n\n"
            . "Evaluate the student's presentation delivery "
            . "fairly and constructively.\n\n"
            . "Return JSON with exactly these fields:\n"
            . "pronunciation,\n"
            . "fluency,\n"
            . "grammar,\n"
            . "vocabulary,\n"
            . "speechClarity,\n"
            . "pacing,\n"
            . "overallScore,\n"
            . "feedback,\n"
            . "level,\n"
            . "strongestArea,\n"
            . "weakestArea.\n\n"
            . "Requirements:\n"
            . "- Every score must be an integer from 0 to 100.\n"
            . "- level must be Beginner, Intermediate, "
            . "or Advanced.\n"
            . "- feedback must be concise, constructive, "
            . "and useful to a student presenter.\n"
            . "- strongestArea and weakestArea should identify "
            . "specific speaking areas.\n"
            . "- Return only valid JSON.";

        return $this->requestJsonEvaluation(
            $prompt
        );
    }

    // =========================================================
    // PRACTICE ASSESSMENT
    // =========================================================

    public function evaluatePractice(
        string $transcript,
        string $presentationContext
    ): array {
        $transcript =
            trim(
                $transcript
            );

        $presentationContext =
            trim(
                $presentationContext
            );

        if ($transcript === '') {
            throw new RuntimeException(
                'Cannot evaluate an empty practice transcript.'
            );
        }

        if ($presentationContext === '') {
            return $this->evaluate(
                $transcript
            );
        }

        $safeContext =
            $this->limitText(
                $presentationContext,
                30000
            );

        $safeTranscript =
            $this->limitText(
                $transcript,
                30000
            );

        $prompt =
            "The student is practising a presentation.\n\n"
            . "PRESENTATION MATERIAL:\n"
            . $safeContext
            . "\n\n"
            . "STUDENT SPEECH TRANSCRIPT:\n"
            . $safeTranscript
            . "\n\n"
            . "Evaluate the student's speaking performance "
            . "and how appropriately the speech relates to "
            . "the supplied presentation material.\n\n"
            . "Important rules:\n"
            . "- Judge pronunciation, fluency, grammar, "
            . "vocabulary, speech clarity, and pacing.\n"
            . "- Do not require the student to read the "
            . "presentation word-for-word.\n"
            . "- Natural paraphrasing is acceptable.\n"
            . "- Do not lower a speaking score merely because "
            . "the student used different wording.\n"
            . "- Feedback may explain whether the speech "
            . "covers and communicates the presentation "
            . "material effectively.\n"
            . "- Keep feedback constructive and appropriate "
            . "for a student presenter.\n\n"
            . "Return JSON with exactly these fields:\n"
            . "pronunciation,\n"
            . "fluency,\n"
            . "grammar,\n"
            . "vocabulary,\n"
            . "speechClarity,\n"
            . "pacing,\n"
            . "overallScore,\n"
            . "feedback,\n"
            . "level,\n"
            . "strongestArea,\n"
            . "weakestArea.\n\n"
            . "All scores must be integers from 0 to 100.\n"
            . "level must be Beginner, Intermediate, "
            . "or Advanced.\n"
            . "Return only valid JSON.";

        return $this->requestJsonEvaluation(
            $prompt
        );
    }

    // =========================================================
    // SUGGESTED SPEECH
    // =========================================================

    public function generateSuggestedSpeech(
        string $presentationContext
    ): string {
        $presentationContext =
            trim(
                $presentationContext
            );

        if ($presentationContext === '') {
            throw new RuntimeException(
                'Presentation content is empty.'
            );
        }

        $safeContext =
            $this->limitText(
                $presentationContext,
                30000
            );

        $prompt =
            "Create a suggested presentation speech for a "
            . "student using only the presentation material "
            . "provided below.\n\n"
            . "PRESENTATION MATERIAL:\n"
            . $safeContext
            . "\n\n"
            . "Requirements:\n"
            . "- Write natural spoken English.\n"
            . "- Use student-friendly wording.\n"
            . "- Include a short introduction.\n"
            . "- Explain the main points logically.\n"
            . "- Use smooth transitions.\n"
            . "- Include a short conclusion.\n"
            . "- The student does not need to read slide "
            . "text word-for-word.\n"
            . "- Do not invent facts that are not supported "
            . "by the presentation material.\n"
            . "- Do not mention these instructions.\n"
            . "- Return only the suggested speech.";

        try {
            $response =
                $this->client->post(
                    'responses',
                    [
                        'json' => [
                            'model' =>
                                'gpt-5.6-luna',

                            'input' => [
                                [
                                    'role' =>
                                        'system',

                                    'content' => [
                                        [
                                            'type' =>
                                                'input_text',

                                            'text' =>
                                                'You are SpeakWise, '
                                                . 'an AI presentation '
                                                . 'coach. Help students '
                                                . 'prepare clear, '
                                                . 'natural presentation '
                                                . 'speeches based on '
                                                . 'their supplied '
                                                . 'presentation material.',
                                        ],
                                    ],
                                ],

                                [
                                    'role' =>
                                        'user',

                                    'content' => [
                                        [
                                            'type' =>
                                                'input_text',

                                            'text' =>
                                                $prompt,
                                        ],
                                    ],
                                ],
                            ],
                        ],
                    ]
                );
        } catch (Throwable $e) {
            throw new RuntimeException(
                'Suggested speech generation failed: '
                . $this->friendlyApiError($e),
                0,
                $e
            );
        }

        $data =
            $this->decodeApiResponse(
                $response
                    ->getBody()
                    ->getContents(),
                'suggested speech'
            );

        $text =
            trim(
                $this->extractResponseText(
                    $data
                )
            );

        if ($text === '') {
            throw new RuntimeException(
                'OpenAI returned an empty suggested speech.'
            );
        }

        return $text;
    }

    // =========================================================
    // PRESENTATION IMAGE VISION
    // =========================================================

    public function analyzePresentationImage(
        string $filePath,
        string $originalFileName
    ): string {
        if (!file_exists($filePath)) {
            throw new RuntimeException(
                'Presentation image was not found.'
            );
        }

        if (!is_file($filePath)) {
            throw new RuntimeException(
                'The presentation image path is invalid.'
            );
        }

        $fileSize =
            filesize(
                $filePath
            );

        if (
            $fileSize === false ||
            $fileSize <= 0
        ) {
            throw new RuntimeException(
                'Presentation image is empty.'
            );
        }

        $extension =
            strtolower(
                pathinfo(
                    $originalFileName,
                    PATHINFO_EXTENSION
                )
            );

        $mimeType =
            match ($extension) {
                'png' =>
                    'image/png',

                'jpg', 'jpeg' =>
                    'image/jpeg',

                'webp' =>
                    'image/webp',

                default =>
                    throw new RuntimeException(
                        'Unsupported presentation image format.'
                    ),
            };

        $imageContents =
            file_get_contents(
                $filePath
            );

        if ($imageContents === false) {
            throw new RuntimeException(
                'Unable to read the presentation image.'
            );
        }

        $base64 =
            base64_encode(
                $imageContents
            );

        $dataUrl =
            'data:'
            . $mimeType
            . ';base64,'
            . $base64;

        try {
            $response =
                $this->client->post(
                    'responses',
                    [
                        'json' => [
                            'model' =>
                                'gpt-5.6-luna',

                            'input' => [
                                [
                                    'role' =>
                                        'system',

                                    'content' => [
                                        [
                                            'type' =>
                                                'input_text',

                                            'text' =>
                                                'You are SpeakWise, '
                                                . 'an AI presentation '
                                                . 'coach. Analyse '
                                                . 'presentation images '
                                                . 'accurately and do '
                                                . 'not invent content '
                                                . 'that is not visible.',
                                        ],
                                    ],
                                ],

                                [
                                    'role' =>
                                        'user',

                                    'content' => [
                                        [
                                            'type' =>
                                                'input_text',

                                            'text' =>
                                                'This image is part '
                                                . 'of a student '
                                                . 'presentation. '
                                                . 'Extract important '
                                                . 'visible text and '
                                                . 'describe meaningful '
                                                . 'presentation content '
                                                . 'such as charts, '
                                                . 'tables, diagrams, '
                                                . 'figures, labels, '
                                                . 'headings, and key '
                                                . 'visual information. '
                                                . 'Create concise '
                                                . 'presentation context '
                                                . 'that can later be '
                                                . 'used to generate a '
                                                . 'suggested speech and '
                                                . 'evaluate the student. '
                                                . 'Do not invent facts '
                                                . 'that are not visible.',
                                        ],

                                        [
                                            'type' =>
                                                'input_image',

                                            'image_url' =>
                                                $dataUrl,
                                        ],
                                    ],
                                ],
                            ],
                        ],
                    ]
                );
        } catch (Throwable $e) {
            throw new RuntimeException(
                'Presentation image analysis failed: '
                . $this->friendlyApiError($e),
                0,
                $e
            );
        }

        $data =
            $this->decodeApiResponse(
                $response
                    ->getBody()
                    ->getContents(),
                'presentation image'
            );

        $text =
            trim(
                $this->extractResponseText(
                    $data
                )
            );

        if ($text === '') {
            throw new RuntimeException(
                'No presentation content could be '
                . 'understood from the image.'
            );
        }

        return $this->limitText(
            $text,
            15000
        );
    }

    // =========================================================
    // JSON EVALUATION REQUEST
    // =========================================================

    private function requestJsonEvaluation(
        string $prompt
    ): array {
        try {
            $response =
                $this->client->post(
                    'responses',
                    [
                        'json' => [
                            'model' =>
                                'gpt-5.6-luna',

                            'input' => [
                                [
                                    'role' =>
                                        'system',

                                    'content' => [
                                        [
                                            'type' =>
                                                'input_text',

                                            'text' =>
                                                'You are SpeakWise, '
                                                . 'an AI presentation '
                                                . 'coach. Evaluate '
                                                . 'student presentations '
                                                . 'fairly and '
                                                . 'constructively. '
                                                . 'Return only valid '
                                                . 'JSON with no Markdown '
                                                . 'or extra explanation.',
                                        ],
                                    ],
                                ],

                                [
                                    'role' =>
                                        'user',

                                    'content' => [
                                        [
                                            'type' =>
                                                'input_text',

                                            'text' =>
                                                $prompt,
                                        ],
                                    ],
                                ],
                            ],
                        ],
                    ]
                );
        } catch (Throwable $e) {
            throw new RuntimeException(
                'OpenAI evaluation failed: '
                . $this->friendlyApiError($e),
                0,
                $e
            );
        }

        $data =
            $this->decodeApiResponse(
                $response
                    ->getBody()
                    ->getContents(),
                'evaluation'
            );

        $text =
            $this->extractResponseText(
                $data
            );

        $result =
            $this->decodeJsonResponse(
                $text
            );

        return $this->normalizeEvaluation(
            $result
        );
    }

    // =========================================================
    // NORMALIZE EVALUATION
    // =========================================================

    private function normalizeEvaluation(
        array $result
    ): array {
        $scoreFields = [
            'pronunciation',
            'fluency',
            'grammar',
            'vocabulary',
            'speechClarity',
            'pacing',
            'overallScore',
        ];

        foreach (
            $scoreFields
            as $field
        ) {
            if (
                !array_key_exists(
                    $field,
                    $result
                )
            ) {
                throw new RuntimeException(
                    "OpenAI response is missing {$field}."
                );
            }

            if (
                !is_numeric(
                    $result[$field]
                )
            ) {
                throw new RuntimeException(
                    "OpenAI returned an invalid "
                    . "{$field} score."
                );
            }

            $score =
                (int) round(
                    (float) $result[$field]
                );

            $result[$field] =
                max(
                    0,
                    min(
                        100,
                        $score
                    )
                );
        }

        $result['feedback'] =
            trim(
                (string) (
                    $result['feedback']
                    ?? ''
                )
            );

        if (
            $result['feedback'] === ''
        ) {
            $result['feedback'] =
                'Keep practising and focus on '
                . 'clear, confident delivery.';
        }

        $result['strongestArea'] =
            trim(
                (string) (
                    $result['strongestArea']
                    ?? ''
                )
            );

        $result['weakestArea'] =
            trim(
                (string) (
                    $result['weakestArea']
                    ?? ''
                )
            );

        $level =
            trim(
                (string) (
                    $result['level']
                    ?? ''
                )
            );

        if (
            !in_array(
                $level,
                [
                    'Beginner',
                    'Intermediate',
                    'Advanced',
                ],
                true
            )
        ) {
            $overall =
                $result['overallScore'];

            if ($overall >= 90) {
                $level = 'Advanced';
            } elseif ($overall >= 75) {
                $level = 'Intermediate';
            } else {
                $level = 'Beginner';
            }
        }

        $result['level'] =
            $level;

        return $result;
    }

    // =========================================================
    // DECODE JSON RESPONSE
    // =========================================================

    private function decodeJsonResponse(
        string $text
    ): array {
        $text =
            trim(
                $text
            );

        if (
            str_starts_with(
                $text,
                '```json'
            )
        ) {
            $text =
                substr(
                    $text,
                    7
                );

            $text =
                trim(
                    $text
                );
        } elseif (
            str_starts_with(
                $text,
                '```'
            )
        ) {
            $text =
                substr(
                    $text,
                    3
                );

            $text =
                trim(
                    $text
                );
        }

        if (
            str_ends_with(
                $text,
                '```'
            )
        ) {
            $text =
                substr(
                    $text,
                    0,
                    -3
                );

            $text =
                trim(
                    $text
                );
        }

        $firstBrace =
            strpos(
                $text,
                '{'
            );

        $lastBrace =
            strrpos(
                $text,
                '}'
            );

        if (
            $firstBrace !== false &&
            $lastBrace !== false &&
            $lastBrace >= $firstBrace
        ) {
            $text =
                substr(
                    $text,
                    $firstBrace,
                    $lastBrace - $firstBrace + 1
                );
        }

        $result =
            json_decode(
                $text,
                true
            );

        if (!is_array($result)) {
            throw new RuntimeException(
                'OpenAI returned invalid evaluation JSON.'
            );
        }

        return $result;
    }

    // =========================================================
    // EXTRACT RESPONSES API TEXT
    // =========================================================

    private function extractResponseText(
        array $data
    ): string {
        if (
            isset($data['output_text']) &&
            is_string(
                $data['output_text']
            ) &&
            trim(
                $data['output_text']
            ) !== ''
        ) {
            return trim(
                $data['output_text']
            );
        }

        $collectedText = [];

        if (
            isset($data['output']) &&
            is_array(
                $data['output']
            )
        ) {
            foreach (
                $data['output']
                as $output
            ) {
                if (
                    !is_array($output) ||
                    !isset($output['content']) ||
                    !is_array(
                        $output['content']
                    )
                ) {
                    continue;
                }

                foreach (
                    $output['content']
                    as $content
                ) {
                    if (!is_array($content)) {
                        continue;
                    }

                    $type =
                        (string) (
                            $content['type']
                            ?? ''
                        );

                    if (
                        $type === 'output_text' &&
                        isset($content['text'])
                    ) {
                        $value =
                            trim(
                                (string) $content['text']
                            );

                        if ($value !== '') {
                            $collectedText[] =
                                $value;
                        }
                    }
                }
            }
        }

        if (!empty($collectedText)) {
            return trim(
                implode(
                    "\n",
                    $collectedText
                )
            );
        }

        throw new RuntimeException(
            'Could not read the OpenAI response.'
        );
    }

    // =========================================================
    // DECODE GENERAL API RESPONSE
    // =========================================================

    private function decodeApiResponse(
        string $body,
        string $description
    ): array {
        $body =
            trim(
                $body
            );

        if ($body === '') {
            throw new RuntimeException(
                'OpenAI returned an empty '
                . $description
                . ' response.'
            );
        }

        $data =
            json_decode(
                $body,
                true
            );

        if (!is_array($data)) {
            throw new RuntimeException(
                'OpenAI returned an invalid '
                . $description
                . ' response.'
            );
        }

        return $data;
    }

    // =========================================================
    // FRIENDLY API ERROR
    // =========================================================

    /**
     * Extract the useful OpenAI error response from Guzzle.
     *
     * Previously SpeakWise only displayed Guzzle's generic
     * "500 Internal Server Error" message. This version attempts
     * to read the actual HTTP response body returned by OpenAI.
     */
    private function friendlyApiError(
        Throwable $exception
    ): string {
        $message =
            trim(
                $exception->getMessage()
            );

        try {
            if (
                method_exists(
                    $exception,
                    'hasResponse'
                ) &&
                $exception->hasResponse()
            ) {
                $response =
                    $exception->getResponse();

                if ($response !== null) {
                    $statusCode =
                        $response->getStatusCode();

                    $body =
                        trim(
                            (string) $response->getBody()
                        );

                    if ($body !== '') {
                        $decoded =
                            json_decode(
                                $body,
                                true
                            );

                        if (
                            is_array($decoded) &&
                            isset($decoded['error']) &&
                            is_array($decoded['error'])
                        ) {
                            $apiMessage =
                                trim(
                                    (string) (
                                        $decoded['error']['message']
                                        ?? ''
                                    )
                                );

                            $apiType =
                                trim(
                                    (string) (
                                        $decoded['error']['type']
                                        ?? ''
                                    )
                                );

                            $apiCode =
                                trim(
                                    (string) (
                                        $decoded['error']['code']
                                        ?? ''
                                    )
                                );

                            if ($apiMessage !== '') {
                                $result =
                                    'OpenAI HTTP '
                                    . $statusCode
                                    . ': '
                                    . $apiMessage;

                                if ($apiType !== '') {
                                    $result .=
                                        ' [type: '
                                        . $apiType
                                        . ']';
                                }

                                if ($apiCode !== '') {
                                    $result .=
                                        ' [code: '
                                        . $apiCode
                                        . ']';
                                }

                                return $this->limitErrorText(
                                    $result
                                );
                            }
                        }

                        return $this->limitErrorText(
                            'OpenAI HTTP '
                            . $statusCode
                            . ': '
                            . $body
                        );
                    }

                    return 'OpenAI HTTP '
                        . $statusCode
                        . ' returned an empty error response.';
                }
            }
        } catch (Throwable $responseReadError) {
            // If the HTTP response itself cannot be read,
            // fall back to the original exception below.
        }

        if ($message === '') {
            return 'Unknown OpenAI API error.';
        }

        return $this->limitErrorText(
            $message
        );
    }

    // =========================================================
    // LIMIT ERROR TEXT
    // =========================================================

    private function limitErrorText(
        string $message
    ): string {
        $message =
            trim(
                $message
            );

        if ($message === '') {
            return 'Unknown OpenAI API error.';
        }

        if (
            mb_strlen(
                $message,
                'UTF-8'
            ) > 1500
        ) {
            return mb_substr(
                $message,
                0,
                1500,
                'UTF-8'
            )
            . '...';
        }

        return $message;
    }

    // =========================================================
    // LIMIT TEXT
    // =========================================================

    private function limitText(
        string $text,
        int $maxCharacters
    ): string {
        $text =
            trim(
                $text
            );

        if ($maxCharacters <= 0) {
            return '';
        }

        if (
            mb_strlen(
                $text,
                'UTF-8'
            ) <= $maxCharacters
        ) {
            return $text;
        }

        return mb_substr(
            $text,
            0,
            $maxCharacters,
            'UTF-8'
        );
    }
}