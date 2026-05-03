<?php

declare(strict_types=1);

namespace OCA\RhwpViewer\Controller;

use OCA\RhwpViewer\AppInfo\Application;
use OCP\AppFramework\Controller;
use OCP\AppFramework\Http;
use OCP\AppFramework\Http\Attribute\NoAdminRequired;
use OCP\AppFramework\Http\Attribute\NoCSRFRequired;
use OCP\AppFramework\Http\TemplateResponse;
use OCP\AppFramework\Services\IInitialState;
use OCP\Files\File;
use OCP\Files\IRootFolder;
use OCP\IRequest;
use OCP\IUserSession;
use Throwable;

class PageController extends Controller {
    public function __construct(
        IRequest $request,
        private IInitialState $initialState,
        private IRootFolder $rootFolder,
        private IUserSession $userSession,
    ) {
        parent::__construct(Application::APP_ID, $request);
    }

    #[NoAdminRequired]
    #[NoCSRFRequired]
    public function index(): TemplateResponse {
        return $this->blankView();
    }

    #[NoAdminRequired]
    #[NoCSRFRequired]
    public function blankView(): TemplateResponse {
        return $this->renderViewer([
            'fileId' => null,
            'fileName' => null,
            'mimeType' => null,
            'size' => null,
            'error' => null,
        ]);
    }

    #[NoAdminRequired]
    #[NoCSRFRequired]
    public function view(int $fileId): TemplateResponse {
        if ($fileId <= 0) {
            return $this->notFoundResponse();
        }

        $user = $this->userSession->getUser();
        if ($user === null) {
            return $this->notFoundResponse();
        }

        try {
            $userFolder = $this->rootFolder->getUserFolder($user->getUID());
            $nodes = $userFolder->getById($fileId);
        } catch (Throwable) {
            return $this->notFoundResponse();
        }

        $node = $nodes[0] ?? null;
        if (!$node instanceof File) {
            return $this->notFoundResponse();
        }

        return $this->renderViewer([
            'fileId' => $node->getId(),
            'fileName' => $node->getName(),
            'mimeType' => $node->getMimeType(),
            'size' => $node->getSize(),
            'error' => null,
        ]);
    }

    /**
     * @param array{fileId: int|null, fileName: string|null, mimeType: string|null, size: int|float|null, error: string|null} $params
     */
    private function renderViewer(array $params, int $status = Http::STATUS_OK): TemplateResponse {
        $this->initialState->provideInitialState('viewer', $params);

        return new TemplateResponse(
            Application::APP_ID,
            'index',
            $params,
            TemplateResponse::RENDER_AS_USER,
            $status,
        );
    }

    private function notFoundResponse(): TemplateResponse {
        return $this->renderViewer([
            'fileId' => null,
            'fileName' => null,
            'mimeType' => null,
            'size' => null,
            'error' => 'File not found.',
        ], Http::STATUS_NOT_FOUND);
    }
}
