<?php

declare(strict_types=1);

namespace OCA\RhwpViewer\AppInfo;

return [
    'routes' => [
        ['name' => 'page#index', 'url' => '/', 'verb' => 'GET'],
        ['name' => 'page#blankView', 'url' => '/view', 'verb' => 'GET'],
        [
            'name' => 'page#view',
            'url' => '/view/{fileId}',
            'verb' => 'GET',
            'requirements' => ['fileId' => '\\d+'],
            'postfix' => 'with_id',
        ],
    ],
];
