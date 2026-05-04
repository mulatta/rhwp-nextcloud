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
        [
            'name' => 'conversion#convert',
            'url' => '/api/files/{fileId}/convert',
            'verb' => 'GET',
            'requirements' => ['fileId' => '\\d+'],
        ],
        [
            'name' => 'conversion#page',
            'url' => '/api/files/{fileId}/pages/{page}.svg',
            'verb' => 'GET',
            'requirements' => ['fileId' => '\\d+', 'page' => '\\d+'],
        ],
    ],
];
