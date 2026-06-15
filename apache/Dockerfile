ARG PHP=8.3
ARG OS=bookworm

FROM php:${PHP}-apache-${OS}

# 1. Enable critical Apache modules early for Drupal .htaccess support
RUN a2enmod rewrite alias expires

# 2. Consolidated extension compilation & dependency management
RUN set -eux; \
    savedAptMark="$(apt-mark showmanual)"; \
    \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libfreetype6-dev \
        libjpeg-dev \
        libpng-dev \
        libpq-dev \
        libwebp-dev \
        libzip-dev \
        libicu-dev \
        # libxml2-dev \
        mariadb-client \
        postgresql-client \
    ; \
    \
    # Configure extensions requiring external flags
    docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
        --with-webp \
    ; \
    \
    # Compile all extensions in a single parallelized layer
    docker-php-ext-install -j "$(nproc)" \
        # bcmath \
        gd \
        # intl \
        opcache \
        pdo_mysql \
        pdo_pgsql \
        zip \
    ; \
    \
    # Install PECL dependencies
    pecl install redis; \
    docker-php-ext-enable redis; \
    \
    # Production Clean-up: Preserve runtime libraries while dropping -dev packages
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark; \
    ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
        | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
        | sort -u \
        | xargs -r dpkg-query -S \
        | cut -d: -f1 \
        | sort -u \
        | xargs -rt apt-mark manual; \
    \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*

# 3. [Non-Root Setup] Shift Apache configuration to unprivileged port 8080 & update DocumentRoot
RUN sed -i 's/Listen 80/Listen 8080/g' /etc/apache2/ports.conf \
    && sed -i 's/<VirtualHost \*:80>/<VirtualHost \*:8080>/g' /etc/apache2/sites-available/000-default.conf \
    && sed -i 's|/var/www/html|/var/www/html/web|g' /etc/apache2/sites-available/000-default.conf

# 4. Create internal config engine layouts and persistent system directories
RUN mkdir -p /_config \
    && echo "IncludeOptional /_config/apache-mpm.conf" >> /etc/apache2/apache2.conf \
    && echo "IncludeOptional /_config/drupal-runtime.conf" >> /etc/apache2/apache2.conf \
    && mkdir -p /usr/local/etc/php-fpm.d/ \
    && echo "include=/_config/php-fpm.conf" >> /usr/local/etc/php-fpm.conf \
    && mkdir -p /mnt/files/{public,private,tmp,config/sync}

# 5. Runtime configurations & Scan environments
ENV PHP_INI_SCAN_DIR=/usr/local/etc/php/conf.d:/_config
WORKDIR /var/www/html

# 6. Global Drush Shortcut (Will hook natively once composer installs app files)
RUN ln -s /var/www/html/vendor/bin/drush /usr/local/bin/drush

# 7. Copy Custom Entrypoint
COPY --chmod=+x docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# 8. Standardize file system ownership under non-root user
RUN chown -R www-data:www-data \
    /var/www/html \
    /var/run/apache2 \
    /var/lock/apache2 \
    /var/log/apache2 \
    /_config \
    /mnt/files \
    && chmod -R 755 /mnt/files

RUN { \
    echo 'opcache.memory_consumption=128'; \
    echo 'opcache.interned_strings_buffer=8'; \
    echo 'opcache.max_accelerated_files=4000'; \
    echo 'opcache.revalidate_freq=60'; \
} > /usr/local/etc/php/conf.d/opcache-recommended.ini

# 9. Drop security privileges completely
USER www-data
EXPOSE 8080

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"] 
