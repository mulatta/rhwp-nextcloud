<?php

declare(strict_types=1);

namespace OCA\RhwpViewer\Controller;

use OCA\RhwpViewer\AppInfo\Application;
use OCA\RhwpViewer\Service\ConversionFailed;
use OCA\RhwpViewer\Service\ConversionResult;
use OCA\RhwpViewer\Service\FileResolver;
use OCA\RhwpViewer\Service\RhwpConverter;
use OCP\AppFramework\Controller;
use OCP\AppFramework\Http;
use OCP\AppFramework\Http\Attribute\NoAdminRequired;
use OCP\AppFramework\Http\Attribute\NoCSRFRequired;
use OCP\AppFramework\Http\JSONResponse;
use OCP\IRequest;

class ConversionController extends Controller {
    private const MAX_OUTPUT_BYTES = 8192;

    public function __construct(
        IRequest $request,
        private FileResolver $fileResolver,
        private RhwpConverter $converter,
    ) {
        parent::__construct(Application::APP_ID, $request);
    }

    #[NoAdminRequired]
    #[NoCSRFRequired]
    public function convert(int $fileId): JSONResponse {
        $file = $this->fileResolver->resolveForCurrentUser($fileId);
        if ($file === null) {
            return new JSONResponse([
                'status' => 'error',
                'error' => 'File not found.',
            ], Http::STATUS_NOT_FOUND);
        }

        try {
            $result = $this->converter->smokeTest();
        } catch (ConversionFailed $error) {
            return new JSONResponse([
                'fileId' => $file->getId(),
                'fileName' => $file->getName(),
                'status' => 'error',
                'error' => $this->userMessageForFailure($error),
            ], $this->statusForFailure($error));
        }

        return new JSONResponse([
            'fileId' => $file->getId(),
            'fileName' => $file->getName(),
            'status' => 'ok',
            'kind' => $this->kindForResult($result),
            'output' => $this->outputForResult($result),
        ]);
    }

    private function statusForFailure(ConversionFailed $error): int {
        return match ($error->getReason()) {
            ConversionFailed::REASON_TIMEOUT => Http::STATUS_GATEWAY_TIMEOUT,
            ConversionFailed::REASON_NON_ZERO_EXIT => Http::STATUS_BAD_GATEWAY,
            default => Http::STATUS_INTERNAL_SERVER_ERROR,
        };
    }

    private function userMessageForFailure(ConversionFailed $error): string {
        return match ($error->getReason()) {
            ConversionFailed::REASON_TIMEOUT => 'Conversion timed out.',
            ConversionFailed::REASON_MISSING_EXECUTABLE => 'Conversion engine is unavailable.',
            default => 'Conversion failed.',
        };
    }

    private function kindForResult(ConversionResult $result): string {
        if ($result->getOperation() === 'smoke-test') {
            return 'smoke';
        }

        return $result->getOperation();
    }

    private function outputForResult(ConversionResult $result): string {
        $output = trim($result->getStdout()) !== '' ? $result->getStdout() : $result->getStderr();

        return $this->sanitizeOutput($output);
    }

    private function sanitizeOutput(string $output): string {
        $output = preg_replace('/\/nix\/store\/[a-z0-9]{32}-[^\s\'"<>]+/', '[store-path]', $output) ?? $output;
        $output = trim(str_replace(["\r\n", "\r"], "\n", $output));

        if (strlen($output) > self::MAX_OUTPUT_BYTES) {
            return substr($output, 0, self::MAX_OUTPUT_BYTES) . "\n[truncated]";
        }

        return $output;
    }
}
