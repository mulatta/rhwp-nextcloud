<?php

declare(strict_types=1);

namespace OCA\RhwpViewer\Controller;

use OCA\RhwpViewer\AppInfo\Application;
use OCA\RhwpViewer\Service\FileResolver;
use OCA\RhwpViewer\Service\ResolvedFile;
use OCP\AppFramework\Controller;
use OCP\AppFramework\Http;
use OCP\AppFramework\Http\Attribute\NoAdminRequired;
use OCP\AppFramework\Http\Attribute\NoCSRFRequired;
use OCP\AppFramework\Http\ContentSecurityPolicy;
use OCP\AppFramework\Http\DataDisplayResponse;
use OCP\AppFramework\Http\JSONResponse;
use OCP\IRequest;
use OCP\IURLGenerator;
use Throwable;

class DocumentController extends Controller {
    public function __construct(
        IRequest $request,
        private FileResolver $fileResolver,
        private IURLGenerator $urlGenerator,
    ) {
        parent::__construct(Application::APP_ID, $request);
    }

    #[NoAdminRequired]
    #[NoCSRFRequired]
    public function studio(int $fileId): DataDisplayResponse|JSONResponse {
        $file = $this->fileResolver->resolveForCurrentUser($fileId);
        if ($file === null) {
            return $this->notFoundResponse();
        }

        if ($this->safeDocumentFilename($file) === null) {
            return $this->unsupportedResponse($file);
        }

        $html = $this->studioHtml();
        if ($html === null) {
            return new JSONResponse([
                'status' => 'error',
                'error' => 'Editor bundle is unavailable.',
            ], Http::STATUS_INTERNAL_SERVER_ERROR);
        }

        $response = new DataDisplayResponse($html, Http::STATUS_OK, [
            'Content-Type' => 'text/html; charset=utf-8',
        ]);
        $policy = new ContentSecurityPolicy();
        $policy->allowEvalWasm(true);
        $response->setContentSecurityPolicy($policy);

        return $response;
    }

    #[NoAdminRequired]
    #[NoCSRFRequired]
    public function content(int $fileId): DataDisplayResponse|JSONResponse {
        $file = $this->fileResolver->resolveForCurrentUser($fileId);
        if ($file === null) {
            return $this->notFoundResponse();
        }

        $safeFilename = $this->safeDocumentFilename($file);
        if ($safeFilename === null) {
            return $this->unsupportedResponse($file);
        }

        try {
            $content = $file->getFile()->getContent();
        } catch (Throwable) {
            return new JSONResponse([
                'fileId' => $file->getId(),
                'fileName' => $file->getName(),
                'status' => 'error',
                'error' => 'File content is unavailable.',
            ], Http::STATUS_INTERNAL_SERVER_ERROR);
        }

        $response = new DataDisplayResponse($content, Http::STATUS_OK, [
            'Content-Length' => (string)strlen($content),
            'Content-Type' => 'application/octet-stream',
        ]);
        $response->addHeader('Content-Disposition', sprintf('inline; filename="%s"', $safeFilename));

        return $response;
    }

    private function studioHtml(): ?string {
        $html = @file_get_contents(dirname(__DIR__, 2) . '/js/index.html');
        if ($html === false) {
            return null;
        }

        $assetRoot = rtrim($this->urlGenerator->linkTo(Application::APP_ID, 'js'), '/');
        $escapedAssetRoot = htmlspecialchars($assetRoot, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
        $nonce = \OC::$server->getContentSecurityPolicyNonceManager()->getNonce();
        $escapedNonce = htmlspecialchars($nonce, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');

        $html = preg_replace('#<link rel="manifest"[^>]*><script id="vite-plugin-pwa:register-sw"[^>]*></script>#', '', $html) ?? $html;
        $html = str_replace('<head>', '<head><base href="' . $escapedAssetRoot . '/">', $html);
        $html = str_replace('href="/favicon.ico"', 'href="' . $escapedAssetRoot . '/favicon.ico"', $html);
        $html = str_replace('href="/icons/', 'href="' . $escapedAssetRoot . '/icons/', $html);
        $html = str_replace('src="/assets/', 'src="' . $escapedAssetRoot . '/assets/', $html);
        $html = str_replace('href="/assets/', 'href="' . $escapedAssetRoot . '/assets/', $html);
        $html = str_replace('<script type="module"', '<script nonce="' . $escapedNonce . '" type="module"', $html);

        return $html;
    }

    private function safeDocumentFilename(ResolvedFile $file): ?string {
        $extension = strtolower(pathinfo($file->getName(), PATHINFO_EXTENSION));
        if (!in_array($extension, ['hwp', 'hwpx'], true)) {
            return null;
        }

        return 'document.' . $extension;
    }

    private function notFoundResponse(): JSONResponse {
        return new JSONResponse([
            'status' => 'error',
            'error' => 'File not found.',
        ], Http::STATUS_NOT_FOUND);
    }

    private function unsupportedResponse(ResolvedFile $file): JSONResponse {
        return new JSONResponse([
            'fileId' => $file->getId(),
            'fileName' => $file->getName(),
            'status' => 'error',
            'error' => 'Unsupported document type.',
        ], Http::STATUS_UNSUPPORTED_MEDIA_TYPE);
    }
}
