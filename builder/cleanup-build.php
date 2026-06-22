#!/usr/bin/env php
<?php

/**
 * Production cleanup script.
 * Removes development-only files after build.
 *
 * Usage:
 *   cleanup-build             # destructive cleanup
 *   cleanup-build --dry-run   # preview only
 */

$root = $argv[1] ?? '/app';
$dryRun = in_array('--dry-run', $argv);

$configPath = '/usr/local/bin/cleanup.json';
if (!file_exists($configPath)) {
    fwrite(STDERR, "❌ cleanup.json missing @ $configPath\n");
    exit(1);
}

$config = json_decode(file_get_contents($configPath), true);
if (!$config) {
    fwrite(STDERR, "❌ Invalid JSON in cleanup.json\n");
    exit(1);
}

$removePatterns = $config['removePatterns'] ?? [];
$removeDirs     = $config['removeDirs']     ?? [];
$protectedPaths = $config['protectedPaths'] ?? [];

/**
 * Determine if a path is protected from deletion.
 */
function isProtected(string $relative, array $protectedPaths): bool
{
    foreach ($protectedPaths as $p) {
        if (str_starts_with($relative, $p)) {
            return true;
        }
    }
    return false;
}

/**
 * Recursively remove a directory and all its contents using native PHP.
 */
function removeDir(string $path): void
{
    try {
        $items = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator($path, RecursiveDirectoryIterator::SKIP_DOTS),
            RecursiveIteratorIterator::CHILD_FIRST
        );
    } catch (UnexpectedValueException $e) {
        throw new RuntimeException("Failed to iterate directory for removal: $path", 0, $e);
    }

    foreach ($items as $item) {
        if ($item->isDir()) {
            if (!rmdir($item->getRealPath())) {
                throw new RuntimeException("Failed to remove directory: " . $item->getRealPath());
            }
        } else {
            if (!unlink($item->getRealPath())) {
                throw new RuntimeException("Failed to remove file: " . $item->getRealPath());
            }
        }
    }

    if (!rmdir($path)) {
        throw new RuntimeException("Failed to remove directory: $path");
    }
}

$directory = new RecursiveDirectoryIterator($root, RecursiveDirectoryIterator::SKIP_DOTS);
$iterator  = new RecursiveIteratorIterator($directory, RecursiveIteratorIterator::CHILD_FIRST);

foreach ($iterator as $path => $info) {
    $relative = str_replace($root, '', $path);

    // Skip protected
    if (isProtected($relative, $protectedPaths)) {
        continue;
    }

    // Directories to remove
    foreach ($removeDirs as $dir) {
        if ($info->isDir() && fnmatch($dir, $info->getFilename())) {
            echo ($dryRun ? "[dry-run] Would remove dir: $relative\n"
                          : "Removing dir: $relative\n");
            if (!$dryRun) removeDir($path);
            continue 2;
        }
    }

    // File patterns
    foreach ($removePatterns as $pattern) {
        if (fnmatch($pattern, $info->getFilename())) {
            echo ($dryRun ? "[dry-run] Would remove file: $relative\n"
                          : "Removing file: $relative\n");
            if (!$dryRun) unlink($path);
            continue 2;
        }
    }
}

echo $dryRun ? "✅ Dry-run complete.\n" : "✅ Cleanup complete.\n"; 
