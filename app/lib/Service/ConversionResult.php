<?php

declare(strict_types=1);

namespace OCA\RhwpViewer\Service;

final class ConversionResult {
    private function __construct(
        private string $operation,
        private string $stdout,
        private string $stderr,
        private int $exitCode,
    ) {
    }

    public static function smokeTest(string $stdout, string $stderr, int $exitCode): self {
        return new self('smoke-test', $stdout, $stderr, $exitCode);
    }

    public function getOperation(): string {
        return $this->operation;
    }

    public function getStdout(): string {
        return $this->stdout;
    }

    public function getStderr(): string {
        return $this->stderr;
    }

    public function getExitCode(): int {
        return $this->exitCode;
    }
}
