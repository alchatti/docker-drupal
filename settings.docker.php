<?php

/**
 * Runtime Drupal settings shipped with the container image.
 *
 * Add the following to the end of your Drupal site's settings.php:
 *
 * @code
 * // Container runtime settings.
 * $container_settings = '/_config/drupal/settings.runtime.php';
 * if (file_exists($container_settings)) {
 *   include $container_settings;
 * }
 * @endcode
 */

/**
 * Return an environment variable or its default value.
 *
 * Empty environment values are treated as unset.
 */
$container_env = static function (
    string $name,
    string $default = '',
): string {
    $value = getenv($name);

    return $value === false || $value === ''
        ? $default
        : $value;
};

/**
 * Return an environment variable as a Boolean.
 */
$container_env_bool = static function (
    string $name,
    bool $default = false,
): bool {
    $value = getenv($name);

    if ($value === false || $value === '') {
        return $default;
    }

    $parsed = filter_var(
        $value,
        FILTER_VALIDATE_BOOLEAN,
        FILTER_NULL_ON_FAILURE,
    );

    return $parsed ?? $default;
};

/**
 * Drupal file-system paths.
 */
$settings['file_public_path'] = $container_env(
    'DRUPAL_PUBLIC_FILES_PATH',
    'files',
);

$settings['file_private_path'] = $container_env(
    'DRUPAL_PRIVATE_FILES_PATH',
    '/mnt/files/private',
);

$settings['file_temp_path'] = $container_env(
    'DRUPAL_TMP_PATH',
    '/mnt/files/tmp',
);

$settings['config_sync_directory'] = $container_env(
    'DRUPAL_CONFIG_SYNC_DIR',
    '/mnt/files/config/sync',
);

/**
 * Database connection.
 */
$database_driver = $container_env('DB_DRIVER', 'mysql');

$database = [
    'driver' => $database_driver,
    'database' => $container_env('DB_NAME', 'drupal'),
    'username' => $container_env('DB_USER', 'drupal'),
    'password' => $container_env('DB_PASS', ''),
    'host' => $container_env('DB_HOST', 'database'),
    'port' => $container_env('DB_PORT', '3306'),
    'prefix' => $container_env('DB_PREFIX', ''),
];

if ($database_driver === 'mysql') {
    $database['charset'] = $container_env('DB_CHARSET', 'utf8mb4');
    $database['collation'] = $container_env(
        'DB_COLLATION',
        'utf8mb4_unicode_ci',
    );
}

$databases['default']['default'] = $database;

/**
 * Override the existing Drupal hash salt only when explicitly supplied.
 */
$hash_salt = getenv('DRUPAL_HASH_SALT');

if ($hash_salt !== false && $hash_salt !== '') {
    $settings['hash_salt'] = $hash_salt;
}

/**
 * Trusted host patterns.
 *
 * Supply a semicolon-separated list of regular expressions:
 *
 * DRUPAL_TRUSTED_HOST_PATTERNS=^localhost$;^example\.com$;^.+\.example\.com$
 */
$trusted_host_patterns_value = getenv('DRUPAL_TRUSTED_HOST_PATTERNS');

if (
    $trusted_host_patterns_value !== false
    && $trusted_host_patterns_value !== ''
) {
    $settings['trusted_host_patterns'] = array_values(array_filter(
        array_map(
            'trim',
            explode(';', $trusted_host_patterns_value),
        ),
        static fn (string $value): bool => $value !== '',
    ));
}

/**
 * Reverse-proxy configuration.
 *
 * Enable with:
 *
 * DRUPAL_REVERSE_PROXY=1
 *
 * Trusted proxy addresses:
 * Supply a semicolon-separated list
 *
 * DRUPAL_TRUSTED_PROXIES=172.18.0.0/16;10.0.0.0/8
 *
 * Header forwarding preset (default: traefik):
 *   traefik   — X-Forwarded-* headers as forwarded by Traefik
 *   all       — all X-Forwarded-* headers (nginx, HAProxy, etc.)
 *   forwarded — RFC 7239 Forwarded header only
 *
 * DRUPAL_REVERSE_PROXY_HEADERS=traefik
 */
if ($container_env_bool('DRUPAL_REVERSE_PROXY')) {
    $trusted_proxies_value = getenv('DRUPAL_TRUSTED_PROXIES');

    $trusted_proxies = $trusted_proxies_value === false
        ? []
        : array_values(array_filter(
            array_map(
                'trim',
                explode(';', $trusted_proxies_value),
            ),
            static fn (string $value): bool => $value !== '',
        ));

    if ($trusted_proxies === []) {
        throw new RuntimeException(
            'DRUPAL_REVERSE_PROXY is enabled, but '
            . 'DRUPAL_TRUSTED_PROXIES is empty.',
        );
    }

    $settings['reverse_proxy'] = true;
    $settings['reverse_proxy_addresses'] = $trusted_proxies;

    $proxy_headers_preset = $container_env('DRUPAL_REVERSE_PROXY_HEADERS', 'traefik');

    $settings['reverse_proxy_trusted_headers'] = match ($proxy_headers_preset) {
        'all'       => \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_ALL,
        'forwarded' => \Symfony\Component\HttpFoundation\Request::HEADER_FORWARDED,
        default     => \Symfony\Component\HttpFoundation\Request::HEADER_X_FORWARDED_TRAEFIK,
    };
}

/**
 * Optional Drupal configuration overrides.
 */
$site_name = getenv('DRUPAL_SITE_NAME');

if ($site_name !== false && $site_name !== '') {
    $config['system.site']['name'] = $site_name;
}
