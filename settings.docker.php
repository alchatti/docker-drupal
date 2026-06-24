<?php

/**
 * Runtime Drupal settings shipped with the container image.
 *
 * Add the following to your Drupal site's settings.php:
 *
 * @code
 * // Container runtime settings.
 * $container_settings = '/_config/drupal/settings.runtime.php';
 * if (file_exists($container_settings)) {
 *   include $container_settings;
 * }
 * @endcode
 */

$settings['file_public_path'] = getenv('DRUPAL_PUBLIC_FILES_PATH') ?: 'files';

$settings['file_private_path'] = getenv('DRUPAL_PRIVATE_FILES_PATH') ?: '/mnt/files/private';

$settings['file_temp_path'] = getenv('DRUPAL_TMP_PATH') ?: '/mnt/files/tmp';

$settings['config_sync_directory'] = getenv('DRUPAL_CONFIG_SYNC_DIR') ?: '/mnt/files/config/sync';

if (getenv('DRUPAL_HASH_SALT')) {
    $settings['hash_salt'] = getenv('DRUPAL_HASH_SALT');
}

if (getenv('DRUPAL_TRUSTED_HOST_PATTERN')) {
    $settings['trusted_host_patterns'] = array_filter(array_map(
        'trim',
        explode(',', getenv('DRUPAL_TRUSTED_HOST_PATTERN'))
    ));
}

if (getenv('DRUPAL_REVERSE_PROXY') === '1') {
    $settings['reverse_proxy'] = true;

    if (getenv('DRUPAL_REVERSE_PROXY_ADDRESSES')) {
        $settings['reverse_proxy_addresses'] = array_filter(array_map(
            'trim',
            explode(',', getenv('DRUPAL_REVERSE_PROXY_ADDRESSES'))
        ));
    }
}

if (getenv('DRUPAL_SITE_NAME')) {
    $config['system.site']['name'] = getenv('DRUPAL_SITE_NAME');
}
