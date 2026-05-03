<?php

declare(strict_types=1);

namespace OCA\RhwpViewer\Service;

use OCA\RhwpViewer\AppInfo\Application;
use OCP\App\IAppManager;
use Throwable;

final class RhwpConverter {
    public function __construct(
        private IAppManager $appManager,
        private float $timeoutSeconds = 10.0,
    ) {
    }

    /**
     * @throws ConversionFailed
     */
    public function smokeTest(): ConversionResult {
        $result = $this->run([$this->getCliPath(), '--help']);

        return ConversionResult::smokeTest(
            $result['stdout'],
            $result['stderr'],
            $result['exitCode'],
        );
    }

    /**
     * @return array{stdout: string, stderr: string, exitCode: int}
     * @throws ConversionFailed
     */
    private function run(array $command): array {
        if ($this->timeoutSeconds <= 0.0) {
            throw ConversionFailed::executionError('RHWP timeout must be greater than zero.');
        }

        $descriptors = [
            0 => ['pipe', 'r'],
            1 => ['pipe', 'w'],
            2 => ['pipe', 'w'],
        ];

        try {
            $process = proc_open(
                $command,
                $descriptors,
                $pipes,
                $this->getAppPath(),
                null,
                ['bypass_shell' => true],
            );
        } catch (Throwable $throwable) {
            throw ConversionFailed::executionError('Failed to start RHWP.', $throwable);
        }

        if (!is_resource($process)) {
            throw ConversionFailed::executionError('Failed to start RHWP.');
        }

        fclose($pipes[0]);
        stream_set_blocking($pipes[1], false);
        stream_set_blocking($pipes[2], false);

        $stdout = '';
        $stderr = '';
        $exitCode = null;
        $timedOut = false;
        $startedAt = microtime(true);

        while (true) {
            $stdout .= $this->readPipe($pipes[1]);
            $stderr .= $this->readPipe($pipes[2]);

            $status = proc_get_status($process);
            if (!$status['running']) {
                $exitCode = $status['exitcode'];
                break;
            }

            if (microtime(true) - $startedAt >= $this->timeoutSeconds) {
                $timedOut = true;
                proc_terminate($process);
                usleep(100000);

                $status = proc_get_status($process);
                if ($status['running']) {
                    proc_terminate($process, 9);
                }
                break;
            }

            usleep(10000);
        }

        $stdout .= $this->readPipe($pipes[1]);
        $stderr .= $this->readPipe($pipes[2]);
        fclose($pipes[1]);
        fclose($pipes[2]);

        $closedExitCode = proc_close($process);

        if ($timedOut) {
            throw ConversionFailed::timeout($this->timeoutSeconds, $stdout, $stderr);
        }

        if ($exitCode === null || $exitCode < 0) {
            $exitCode = $closedExitCode;
        }

        if ($exitCode < 0) {
            throw ConversionFailed::executionError('Failed to read RHWP exit status.');
        }

        if ($exitCode !== 0) {
            throw ConversionFailed::nonZeroExit($exitCode, $stdout, $stderr);
        }

        return [
            'stdout' => $stdout,
            'stderr' => $stderr,
            'exitCode' => $exitCode,
        ];
    }

    /**
     * @param resource $pipe
     */
    private function readPipe($pipe): string {
        $contents = stream_get_contents($pipe);

        return $contents === false ? '' : $contents;
    }

    /**
     * @throws ConversionFailed
     */
    private function getCliPath(): string {
        $path = $this->getAppPath() . DIRECTORY_SEPARATOR . 'bin' . DIRECTORY_SEPARATOR . 'rhwp';
        if (!is_file($path) || !is_executable($path)) {
            throw ConversionFailed::missingExecutable($path);
        }

        return $path;
    }

    /**
     * @throws ConversionFailed
     */
    private function getAppPath(): string {
        try {
            return $this->appManager->getAppPath(Application::APP_ID);
        } catch (Throwable $throwable) {
            throw ConversionFailed::executionError('Failed to resolve RHWP app path.', $throwable);
        }
    }
}
