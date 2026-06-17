#!/usr/bin/env php
<?php

declare(strict_types=1);

/**
 * Drupal 11 Base Image Requirement Checker
 *
 * This script is intended to run while building the base Docker image,
 * before Drupal app code or composer.json are copied.
 *
 * Usage:
 *   php /usr/local/bin/drupal-image-check
 *
 * Optional env vars:
 *   DRUPAL_DB_DRIVER=mysql|pgsql|sqlite
 *   REQUIRE_REDIS=1
 *   REQUIRE_IMAGICK=1
 *   REQUIRE_BCMATH=1
 */

$errors = [];
$warnings = [];

$dbDriver = strtolower(getenv('DRUPAL_DB_DRIVER') ?: 'mysql');

$requireRedis = getenv('REQUIRE_REDIS') === '1';
$requireImagick = getenv('REQUIRE_IMAGICK') === '1';
$requireBcmath = getenv('REQUIRE_BCMATH') === '1';

function ok(string $message): void
{
    echo "[OK]   {$message}\n";
}

function warn_msg(string $message): void
{
    echo "[WARN] {$message}\n";
}

function fail(string $message): void
{
    echo "[FAIL] {$message}\n";
}

function ini_bytes(string $value): int
{
    $value = trim($value);

    if ($value === '' || $value === '-1') {
        return -1;
    }

    $unit = strtolower(substr($value, -1));
    $number = (float) $value;

    return match ($unit) {
        'g' => (int) ($number * 1024 * 1024 * 1024),
        'm' => (int) ($number * 1024 * 1024),
        'k' => (int) ($number * 1024),
        default => (int) $number,
    };
}

function command_exists(string $command): bool
{
    $result = shell_exec('command -v ' . escapeshellarg($command) . ' 2>/dev/null');
    return is_string($result) && trim($result) !== '';
}

echo "Drupal 11 Base Image Requirement Check\n";
echo "=====================================\n";
echo "PHP version: " . PHP_VERSION . "\n";
echo "Database driver target: {$dbDriver}\n";
echo "Loaded php.ini: " . (php_ini_loaded_file() ?: 'none') . "\n\n";

/**
 * Drupal 11 PHP minimum.
 */
if (!version_compare(PHP_VERSION, '8.3.0', '>=')) {
    $errors[] = "Drupal 11 requires PHP >= 8.3.0. Current version: " . PHP_VERSION;
} else {
    ok("PHP version satisfies Drupal 11 minimum: >= 8.3.0");
}

/**
 * Drupal 11 core required extensions.
 *
 * These are checked as runtime extensions, not via composer.json,
 * because this script runs before app code is copied.
 */
$requiredExtensions = [
    'date',
    'dom',
    'filter',
    'gd',
    'hash',
    'json',
    'pcre',
    'pdo',
    'session',
    'simplexml',
    'spl',
    'tokenizer',
    'xml',
    'zlib',
];

foreach ($requiredExtensions as $extension) {
    if (!extension_loaded($extension)) {
        $errors[] = "Missing required Drupal 11 PHP extension: {$extension}";
    } else {
        ok("Required extension loaded: {$extension}");
    }
}

/**
 * Database-specific PDO driver.
 */
switch ($dbDriver) {
    case 'mysql':
    case 'mariadb':
        if (!extension_loaded('pdo_mysql')) {
            $errors[] = "Missing database extension: pdo_mysql";
        } else {
            ok("Database extension loaded: pdo_mysql");
        }
        break;

    case 'pgsql':
    case 'postgres':
    case 'postgresql':
        if (!extension_loaded('pdo_pgsql')) {
            $errors[] = "Missing database extension: pdo_pgsql";
        } else {
            ok("Database extension loaded: pdo_pgsql");
        }
        break;

    case 'sqlite':
        if (!extension_loaded('pdo_sqlite')) {
            $errors[] = "Missing database extension: pdo_sqlite";
        } else {
            ok("Database extension loaded: pdo_sqlite");
        }
        break;

    default:
        $warnings[] = "Unknown DRUPAL_DB_DRIVER={$dbDriver}. Skipping database-specific PDO driver check.";
}

/**
 * Strongly recommended extensions for production Drupal.
 */
$recommendedExtensions = [
    'curl' => 'Used for outgoing HTTP requests and many contrib integrations.',
    'mbstring' => 'Useful for Unicode and multilingual handling.',
    'openssl' => 'Used for HTTPS and secure integrations.',
    'opcache' => 'Strongly recommended for production performance.',
    'intl' => 'Recommended for locale, translation, and date formatting.',
    'zip' => 'Useful for archive handling and contrib/module workflows.',
];

foreach ($recommendedExtensions as $extension => $reason) {
    if (!extension_loaded($extension)) {
        $warnings[] = "Recommended extension missing: {$extension}. {$reason}";
    } else {
        ok("Recommended extension loaded: {$extension}");
    }
}

/**
 * Optional project-level extensions.
 */
if ($requireRedis) {
    if (!extension_loaded('redis')) {
        $errors[] = "REQUIRE_REDIS=1 but redis extension is missing.";
    } else {
        ok("Project-required extension loaded: redis");
    }
}

if ($requireImagick) {
    if (!extension_loaded('imagick')) {
        $errors[] = "REQUIRE_IMAGICK=1 but imagick extension is missing.";
    } else {
        ok("Project-required extension loaded: imagick");
    }
}

if ($requireBcmath) {
    if (!extension_loaded('bcmath')) {
        $errors[] = "REQUIRE_BCMATH=1 but bcmath extension is missing.";
    } else {
        ok("Project-required extension loaded: bcmath");
    }
}

/**
 * Useful optional warnings.
 */
if (!$requireRedis && !extension_loaded('redis')) {
    $warnings[] = "redis extension is not loaded. Fine if Redis cache/session backend is not used.";
}

if (!$requireImagick && !extension_loaded('imagick')) {
    $warnings[] = "imagick extension is not loaded. Fine if Drupal uses GD only.";
}

if (!$requireBcmath && !extension_loaded('bcmath')) {
    $warnings[] = "bcmath extension is not loaded. Fine unless contrib/custom modules require it.";
}

/**
 * PHP ini sanity checks.
 */
$memoryLimit = ini_get('memory_limit') ?: '';
$uploadMax = ini_get('upload_max_filesize') ?: '';
$postMax = ini_get('post_max_size') ?: '';
$maxExecution = ini_get('max_execution_time') ?: '';

$memoryBytes = ini_bytes($memoryLimit);

if ($memoryBytes !== -1 && $memoryBytes < 128 * 1024 * 1024) {
    $warnings[] = "memory_limit is {$memoryLimit}. Consider 256M for Drupal production.";
} else {
    ok("memory_limit: {$memoryLimit}");
}

if (ini_bytes($postMax) !== -1 && ini_bytes($uploadMax) !== -1 && ini_bytes($postMax) < ini_bytes($uploadMax)) {
    $warnings[] = "post_max_size ({$postMax}) is smaller than upload_max_filesize ({$uploadMax}).";
} else {
    ok("upload_max_filesize={$uploadMax}, post_max_size={$postMax}");
}

if ((int) $maxExecution > 0 && (int) $maxExecution < 60) {
    $warnings[] = "max_execution_time is {$maxExecution}. Consider 60-120 for admin/import operations.";
} else {
    ok("max_execution_time: {$maxExecution}");
}

/**
 * OPcache production checks.
 */
if (extension_loaded('opcache')) {
    $opcacheEnabled = ini_get('opcache.enable');
    $opcacheMemory = ini_get('opcache.memory_consumption');
    $opcacheFiles = ini_get('opcache.max_accelerated_files');
    $opcacheValidate = ini_get('opcache.validate_timestamps');

    if ($opcacheEnabled !== '1') {
        $warnings[] = "OPcache is installed but opcache.enable is not 1.";
    } else {
        ok("OPcache enabled.");
    }

    if ((int) $opcacheMemory < 128) {
        $warnings[] = "opcache.memory_consumption is {$opcacheMemory}. Consider 128 or 256.";
    } else {
        ok("opcache.memory_consumption: {$opcacheMemory}");
    }

    if ((int) $opcacheFiles < 10000) {
        $warnings[] = "opcache.max_accelerated_files is {$opcacheFiles}. Consider 10000-20000 for Drupal.";
    } else {
        ok("opcache.max_accelerated_files: {$opcacheFiles}");
    }

    if ($opcacheValidate !== '0') {
        $warnings[] = "opcache.validate_timestamps is {$opcacheValidate}. For immutable production images, consider 0.";
    } else {
        ok("opcache.validate_timestamps=0");
    }
}

/**
 * ImageMagick CLI check if imagick is installed.
 */
if (extension_loaded('imagick')) {
    if (command_exists('magick') || command_exists('convert')) {
        ok("ImageMagick CLI binary found.");
    } else {
        $warnings[] = "imagick extension is loaded, but ImageMagick CLI binary was not found.";
    }
}

echo "\nSummary\n";
echo "=======\n";

if ($warnings) {
    echo "\nWarnings:\n";
    foreach ($warnings as $warning) {
        warn_msg($warning);
    }
}

if ($errors) {
    echo "\nErrors:\n";
    foreach ($errors as $error) {
        fail($error);
    }

    echo "\nResult: FAILED\n";
    exit(1);
}

echo "\nResult: PASSED\n";
exit(0);
