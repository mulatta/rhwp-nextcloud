<?php

declare(strict_types=1);

namespace OCA\RhwpViewer\Controller;

use OCA\RhwpViewer\AppInfo\Application;
use OCP\AppFramework\Controller;
use OCP\AppFramework\Http\Attribute\NoAdminRequired;
use OCP\AppFramework\Http\Attribute\NoCSRFRequired;
use OCP\AppFramework\Http\TemplateResponse;
use OCP\AppFramework\Services\IInitialState;
use OCP\IRequest;

class PageController extends Controller {
    public function __construct(
        IRequest $request,
        private IInitialState $initialState,
    ) {
        parent::__construct(Application::APP_ID, $request);
    }

    #[NoAdminRequired]
    #[NoCSRFRequired]
    public function index(): TemplateResponse {
        return $this->view(0);
    }

    #[NoAdminRequired]
    #[NoCSRFRequired]
    public function view(int $fileId = 0): TemplateResponse {
        $this->initialState->provideInitialState('viewer', [
            'fileId' => $fileId,
        ]);

        return new TemplateResponse(
            Application::APP_ID,
            'index',
            ['fileId' => $fileId],
            TemplateResponse::RENDER_AS_USER,
        );
    }
}
