<?php

header('Content-Type: application/json');

echo json_encode([
  'message' => 'Hello, Drupal Developer!',
  'sapi' => PHP_SAPI,
  'memory_limit' => ini_get('memory_limit'),
  'opcache_memory_consumption' => ini_get('opcache.memory_consumption'),
  'opcache_validate_timestamps' => ini_get('opcache.validate_timestamps'),
  'timezone' => ini_get('date.timezone'),
], JSON_PRETTY_PRINT);
