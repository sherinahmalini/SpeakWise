<?php

namespace App\Services;

use RuntimeException;
use Smalot\PdfParser\Parser;
use Throwable;
use ZipArchive;

class PresentationService
{
    private const MAX_CONTEXT_LENGTH = 50000;

    /**
     * LibreOffice executable installed on Windows.
     */
    private const LIBREOFFICE_PATH =
        'C:/Program Files/LibreOffice/program/soffice.exe';

    /**
     * Supported presentation/document extensions.
     */
    private const DOCUMENT_EXTENSIONS = [
        'pdf',
        'ppt',
        'pptx',
        'doc',
        'docx',
    ];

    /**
     * Image formats.
     *
     * These are recognised here, but their actual content
     * will be handled by OpenAI vision separately.
     */
    private const IMAGE_EXTENSIONS = [
        'png',
        'jpg',
        'jpeg',
        'webp',
    ];

    // =========================================================
    // MAIN ENTRY POINT
    // =========================================================

    public function extractText(
        string $filePath,
        string $originalFileName
    ): array {
        $this->validateFile(
            $filePath
        );

        $extension = strtolower(
            pathinfo(
                $originalFileName,
                PATHINFO_EXTENSION
            )
        );

        if ($extension === '') {
            throw new RuntimeException(
                'The uploaded presentation has no file extension.'
            );
        }

        // -----------------------------------------------------
        // IMAGE
        // -----------------------------------------------------

        if (
            in_array(
                $extension,
                self::IMAGE_EXTENSIONS,
                true
            )
        ) {
            return [
                'type' => 'image',
                'extension' => $extension,
                'text' => '',
                'requiresVision' => true,
            ];
        }

        // -----------------------------------------------------
        // CHECK DOCUMENT TYPE
        // -----------------------------------------------------

        if (
            !in_array(
                $extension,
                self::DOCUMENT_EXTENSIONS,
                true
            )
        ) {
            throw new RuntimeException(
                'Unsupported presentation format: .'
                . $extension
            );
        }

        $temporaryConvertedFile = null;

        try {
            // -------------------------------------------------
            // LEGACY PPT
            // -------------------------------------------------

            if ($extension === 'ppt') {
                $temporaryConvertedFile =
                    $this->convertLegacyDocument(
                        $filePath,
                        'pptx'
                    );

                $text =
                    $this->extractPptx(
                        $temporaryConvertedFile
                    );

                return $this->buildDocumentResult(
                    text: $text,
                    originalExtension: 'ppt',
                    processedExtension: 'pptx',
                    converted: true
                );
            }

            // -------------------------------------------------
            // LEGACY DOC
            // -------------------------------------------------

            if ($extension === 'doc') {
                $temporaryConvertedFile =
                    $this->convertLegacyDocument(
                        $filePath,
                        'docx'
                    );

                $text =
                    $this->extractDocx(
                        $temporaryConvertedFile
                    );

                return $this->buildDocumentResult(
                    text: $text,
                    originalExtension: 'doc',
                    processedExtension: 'docx',
                    converted: true
                );
            }

            // -------------------------------------------------
            // PDF
            // -------------------------------------------------

            if ($extension === 'pdf') {
                $text =
                    $this->extractPdf(
                        $filePath
                    );

                return $this->buildDocumentResult(
                    text: $text,
                    originalExtension: 'pdf',
                    processedExtension: 'pdf',
                    converted: false
                );
            }

            // -------------------------------------------------
            // PPTX
            // -------------------------------------------------

            if ($extension === 'pptx') {
                $text =
                    $this->extractPptx(
                        $filePath
                    );

                return $this->buildDocumentResult(
                    text: $text,
                    originalExtension: 'pptx',
                    processedExtension: 'pptx',
                    converted: false
                );
            }

            // -------------------------------------------------
            // DOCX
            // -------------------------------------------------

            if ($extension === 'docx') {
                $text =
                    $this->extractDocx(
                        $filePath
                    );

                return $this->buildDocumentResult(
                    text: $text,
                    originalExtension: 'docx',
                    processedExtension: 'docx',
                    converted: false
                );
            }

            throw new RuntimeException(
                'Unable to process this presentation format.'
            );
        } finally {
            if (
                $temporaryConvertedFile !== null &&
                file_exists(
                    $temporaryConvertedFile
                )
            ) {
                @unlink(
                    $temporaryConvertedFile
                );
            }
        }
    }

    // =========================================================
    // BUILD RESULT
    // =========================================================

    private function buildDocumentResult(
        string $text,
        string $originalExtension,
        string $processedExtension,
        bool $converted
    ): array {
        $text =
            $this->cleanText(
                $text
            );

        if ($text === '') {
            throw new RuntimeException(
                'No readable text could be extracted '
                . 'from the presentation.'
            );
        }

        $text =
            $this->limitText(
                $text
            );

        return [
            'type' => 'document',

            'extension' =>
                $originalExtension,

            'processedExtension' =>
                $processedExtension,

            'converted' =>
                $converted,

            'text' =>
                $text,

            'requiresVision' =>
                false,
        ];
    }

    // =========================================================
    // VALIDATE FILE
    // =========================================================

    private function validateFile(
        string $filePath
    ): void {
        if (!file_exists($filePath)) {
            throw new RuntimeException(
                'Presentation file was not found.'
            );
        }

        if (!is_file($filePath)) {
            throw new RuntimeException(
                'The presentation path is not a valid file.'
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
                'Presentation file is empty.'
            );
        }
    }

    // =========================================================
    // LEGACY OFFICE CONVERSION
    // =========================================================

    /**
     * Convert:
     *
     * .ppt -> .pptx
     * .doc -> .docx
     *
     * using LibreOffice in headless mode.
     */
    private function convertLegacyDocument(
        string $inputPath,
        string $targetExtension
    ): string {
        if (
            !file_exists(
                self::LIBREOFFICE_PATH
            )
        ) {
            throw new RuntimeException(
                'LibreOffice was not found at: '
                . self::LIBREOFFICE_PATH
            );
        }

        if (
            !in_array(
                $targetExtension,
                [
                    'pptx',
                    'docx',
                ],
                true
            )
        ) {
            throw new RuntimeException(
                'Invalid LibreOffice conversion target.'
            );
        }

        $outputDirectory =
            sys_get_temp_dir()
            . DIRECTORY_SEPARATOR
            . 'speakwise_office_'
            . uniqid();

        if (
            !mkdir(
                $outputDirectory,
                0755,
                true
            ) &&
            !is_dir(
                $outputDirectory
            )
        ) {
            throw new RuntimeException(
                'Unable to create a temporary '
                . 'LibreOffice conversion directory.'
            );
        }

        try {
            // -------------------------------------------------
            // LIBREOFFICE FILTER
            // -------------------------------------------------

            $conversionTarget =
                match ($targetExtension) {
                    'pptx' =>
                        'pptx:Impress MS PowerPoint 2007 XML',

                    'docx' =>
                        'docx:Office Open XML Text',

                    default =>
                        $targetExtension,
                };

            // -------------------------------------------------
            // BUILD COMMAND
            // -------------------------------------------------

            $command =
                '"'
                . self::LIBREOFFICE_PATH
                . '"'
                . ' --headless'
                . ' --nologo'
                . ' --nodefault'
                . ' --nolockcheck'
                . ' --nofirststartwizard'
                . ' --convert-to '
                . escapeshellarg(
                    $conversionTarget
                )
                . ' --outdir '
                . escapeshellarg(
                    $outputDirectory
                )
                . ' '
                . escapeshellarg(
                    $inputPath
                )
                . ' 2>&1';

            $output = [];

            $exitCode = 0;

            exec(
                $command,
                $output,
                $exitCode
            );

            // -------------------------------------------------
            // FIND CONVERTED FILE
            // -------------------------------------------------

            $convertedFiles =
                glob(
                    $outputDirectory
                    . DIRECTORY_SEPARATOR
                    . '*.'
                    . $targetExtension
                );

            if (
                $exitCode !== 0 ||
                $convertedFiles === false ||
                empty(
                    $convertedFiles
                )
            ) {
                $message =
                    trim(
                        implode(
                            "\n",
                            $output
                        )
                    );

                throw new RuntimeException(
                    'LibreOffice could not convert the '
                    . 'legacy Office file.'
                    . (
                        $message !== ''
                            ? ' LibreOffice: '
                                . $message
                            : ''
                    )
                );
            }

            $convertedPath =
                $convertedFiles[0];

            $this->validateFile(
                $convertedPath
            );

            // -------------------------------------------------
            // COPY OUT OF TEMP DIRECTORY
            // -------------------------------------------------

            $persistentTemporaryPath =
                sys_get_temp_dir()
                . DIRECTORY_SEPARATOR
                . 'speakwise_converted_'
                . uniqid()
                . '.'
                . $targetExtension;

            if (
                !copy(
                    $convertedPath,
                    $persistentTemporaryPath
                )
            ) {
                throw new RuntimeException(
                    'Unable to prepare the converted '
                    . 'Office document.'
                );
            }

            return $persistentTemporaryPath;
        } finally {
            $this->deleteDirectory(
                $outputDirectory
            );
        }
    }

    // =========================================================
    // PDF
    // =========================================================

    private function extractPdf(
        string $filePath
    ): string {
        try {
            $parser =
                new Parser();

            $pdf =
                $parser->parseFile(
                    $filePath
                );

            return $pdf->getText();
        } catch (Throwable $e) {
            throw new RuntimeException(
                'Unable to read the PDF presentation: '
                . $e->getMessage(),
                0,
                $e
            );
        }
    }

    // =========================================================
    // PPTX
    // =========================================================

    private function extractPptx(
        string $filePath
    ): string {
        $zip =
            new ZipArchive();

        $result =
            $zip->open(
                $filePath
            );

        if ($result !== true) {
            throw new RuntimeException(
                'Unable to open the PowerPoint presentation.'
            );
        }

        try {
            $slides = [];

            // -------------------------------------------------
            // FIND SLIDE XML FILES
            // -------------------------------------------------

            for (
                $index = 0;
                $index < $zip->numFiles;
                $index++
            ) {
                $entryName =
                    $zip->getNameIndex(
                        $index
                    );

                if ($entryName === false) {
                    continue;
                }

                if (
                    preg_match(
                        '#^ppt/slides/slide(\d+)\.xml$#i',
                        $entryName,
                        $matches
                    )
                ) {
                    $slides[] = [
                        'name' =>
                            $entryName,

                        'number' =>
                            (int) $matches[1],
                    ];
                }
            }

            if (empty($slides)) {
                throw new RuntimeException(
                    'No slides were found in '
                    . 'the PowerPoint presentation.'
                );
            }

            // -------------------------------------------------
            // CORRECT SLIDE ORDER
            // -------------------------------------------------

            usort(
                $slides,
                static function (
                    array $first,
                    array $second
                ): int {
                    return $first['number']
                        <=> $second['number'];
                }
            );

            $presentationText = [];

            // -------------------------------------------------
            // EXTRACT SLIDE TEXT
            // -------------------------------------------------

            foreach (
                $slides
                as $slide
            ) {
                $xml =
                    $zip->getFromName(
                        $slide['name']
                    );

                if (
                    $xml === false ||
                    trim($xml) === ''
                ) {
                    continue;
                }

                $slideText =
                    $this->extractOfficeXmlText(
                        $xml
                    );

                if ($slideText === '') {
                    continue;
                }

                $presentationText[] =
                    'Slide '
                    . $slide['number']
                    . ":\n"
                    . $slideText;
            }

            if (
                empty(
                    $presentationText
                )
            ) {
                throw new RuntimeException(
                    'No readable text was found '
                    . 'in the PowerPoint slides.'
                );
            }

            return implode(
                "\n\n",
                $presentationText
            );
        } finally {
            $zip->close();
        }
    }

    // =========================================================
    // DOCX
    // =========================================================

    private function extractDocx(
        string $filePath
    ): string {
        $zip =
            new ZipArchive();

        $result =
            $zip->open(
                $filePath
            );

        if ($result !== true) {
            throw new RuntimeException(
                'Unable to open the Word document.'
            );
        }

        try {
            $documentXml =
                $zip->getFromName(
                    'word/document.xml'
                );

            if ($documentXml === false) {
                throw new RuntimeException(
                    'The Word document does not contain '
                    . 'readable document content.'
                );
            }

            $text =
                $this->extractOfficeXmlText(
                    $documentXml
                );

            // -------------------------------------------------
            // OPTIONAL HEADERS
            // -------------------------------------------------

            $headerText = [];

            for (
                $index = 0;
                $index < $zip->numFiles;
                $index++
            ) {
                $entryName =
                    $zip->getNameIndex(
                        $index
                    );

                if ($entryName === false) {
                    continue;
                }

                if (
                    preg_match(
                        '#^word/header\d+\.xml$#i',
                        $entryName
                    )
                ) {
                    $xml =
                        $zip->getFromName(
                            $entryName
                        );

                    if ($xml !== false) {
                        $header =
                            $this->extractOfficeXmlText(
                                $xml
                            );

                        if ($header !== '') {
                            $headerText[] =
                                $header;
                        }
                    }
                }
            }

            // -------------------------------------------------
            // OPTIONAL FOOTERS
            // -------------------------------------------------

            $footerText = [];

            for (
                $index = 0;
                $index < $zip->numFiles;
                $index++
            ) {
                $entryName =
                    $zip->getNameIndex(
                        $index
                    );

                if ($entryName === false) {
                    continue;
                }

                if (
                    preg_match(
                        '#^word/footer\d+\.xml$#i',
                        $entryName
                    )
                ) {
                    $xml =
                        $zip->getFromName(
                            $entryName
                        );

                    if ($xml !== false) {
                        $footer =
                            $this->extractOfficeXmlText(
                                $xml
                            );

                        if ($footer !== '') {
                            $footerText[] =
                                $footer;
                        }
                    }
                }
            }

            $sections = [];

            if (!empty($headerText)) {
                $sections[] =
                    "Header:\n"
                    . implode(
                        "\n",
                        $headerText
                    );
            }

            if (
                trim(
                    $text
                ) !== ''
            ) {
                $sections[] =
                    $text;
            }

            if (!empty($footerText)) {
                $sections[] =
                    "Footer:\n"
                    . implode(
                        "\n",
                        $footerText
                    );
            }

            if (empty($sections)) {
                throw new RuntimeException(
                    'No readable text was found '
                    . 'in the Word document.'
                );
            }

            return implode(
                "\n\n",
                $sections
            );
        } finally {
            $zip->close();
        }
    }

    // =========================================================
    // OFFICE XML
    // =========================================================

    private function extractOfficeXmlText(
        string $xml
    ): string {
        // -----------------------------------------------------
        // PRESERVE PARAGRAPH BREAKS
        // -----------------------------------------------------

        $xml =
            preg_replace(
                '/<\/(?:a:p|w:p)>/i',
                "\n",
                $xml
            ) ?? $xml;

        // -----------------------------------------------------
        // LINE BREAKS
        // -----------------------------------------------------

        $xml =
            preg_replace(
                '/<(?:a:br|w:br)\b[^>]*\/?>/i',
                "\n",
                $xml
            ) ?? $xml;

        // -----------------------------------------------------
        // TABLE ROWS
        // -----------------------------------------------------

        $xml =
            preg_replace(
                '/<\/(?:a:tr|w:tr)>/i',
                "\n",
                $xml
            ) ?? $xml;

        // -----------------------------------------------------
        // TABLE CELLS
        // -----------------------------------------------------

        $xml =
            preg_replace(
                '/<\/(?:a:tc|w:tc)>/i',
                "\t",
                $xml
            ) ?? $xml;

        // -----------------------------------------------------
        // TABS
        // -----------------------------------------------------

        $xml =
            preg_replace(
                '/<(?:w:tab)\b[^>]*\/?>/i',
                "\t",
                $xml
            ) ?? $xml;

        // -----------------------------------------------------
        // REMOVE XML TAGS
        // -----------------------------------------------------

        $text =
            strip_tags(
                $xml
            );

        // -----------------------------------------------------
        // DECODE XML ENTITIES
        // -----------------------------------------------------

        $text =
            html_entity_decode(
                $text,
                ENT_QUOTES | ENT_XML1,
                'UTF-8'
            );

        return $this->cleanText(
            $text
        );
    }

    // =========================================================
    // CLEAN TEXT
    // =========================================================

    private function cleanText(
        string $text
    ): string {
        $text =
            str_replace(
                [
                    "\r\n",
                    "\r",
                ],
                "\n",
                $text
            );

        $text =
            str_replace(
                "\0",
                '',
                $text
            );

        // Replace unusual non-breaking spaces.

        $text =
            str_replace(
                "\xC2\xA0",
                ' ',
                $text
            );

        // Collapse spaces and tabs.

        $text =
            preg_replace(
                '/[ \t]+/u',
                ' ',
                $text
            ) ?? $text;

        // Remove spaces surrounding new lines.

        $text =
            preg_replace(
                '/ *\n */u',
                "\n",
                $text
            ) ?? $text;

        // Avoid huge empty sections.

        $text =
            preg_replace(
                '/\n{3,}/u',
                "\n\n",
                $text
            ) ?? $text;

        return trim(
            $text
        );
    }

    // =========================================================
    // LIMIT AI CONTEXT
    // =========================================================

    private function limitText(
        string $text
    ): string {
        if (
            mb_strlen(
                $text,
                'UTF-8'
            ) <= self::MAX_CONTEXT_LENGTH
        ) {
            return $text;
        }

        return mb_substr(
            $text,
            0,
            self::MAX_CONTEXT_LENGTH,
            'UTF-8'
        );
    }

    // =========================================================
    // DELETE TEMP DIRECTORY
    // =========================================================

    private function deleteDirectory(
        string $directory
    ): void {
        if (!is_dir($directory)) {
            return;
        }

        $items =
            scandir(
                $directory
            );

        if ($items === false) {
            return;
        }

        foreach (
            $items
            as $item
        ) {
            if (
                $item === '.' ||
                $item === '..'
            ) {
                continue;
            }

            $path =
                $directory
                . DIRECTORY_SEPARATOR
                . $item;

            if (is_dir($path)) {
                $this->deleteDirectory(
                    $path
                );
            } else {
                @unlink(
                    $path
                );
            }
        }

        @rmdir(
            $directory
        );
    }
}