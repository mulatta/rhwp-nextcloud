<?php

declare(strict_types=1);

namespace OCA\RhwpViewer\AppInfo;

return [
    'routes' => [
        ['name' => 'page#index', 'url' => '/', 'verb' => 'GET'],
        [
            'name' => 'page#view',
            'url' => '/view',
            'verb' => 'GET',
            'defaults' => ['fileId' => 0],
        ],
        [
            'name' => 'page#view',
            'url' => '/view/{fileId}',
            'verb' => 'GET',
            'requirements' => ['fileId' => '\\d+'],
            'postfix' => 'with_id',
        ],
    ],
];
