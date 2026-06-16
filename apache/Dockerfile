ARG PHP=8.3
ARG OS=bookworm

FROM php:${PHP}-apache-${OS}

# 1. Custom Scripts & Entrypoint 
COPY --chmod=+x scripts/ /usr/local/bin/
RUN install-php-dependencies.sh

# 2. [Non-Root Setup] Shift Apache to unprivileged port 8080 & update DocumentRoot
RUN sed -i 's/Listen 80/Listen 8080/g' /etc/apache2/ports.conf \
    && sed -i 's/<VirtualHost \*:80>/<VirtualHost \*:8080>/g' /etc/apache2/sites-available/000-default.conf \
    && sed -i 's|/var/www/html|/var/www/html/web|g' /etc/apache2/sites-available/000-default.conf

# 3. Create internal config engine layouts and persistent system directories
# REMOVED: PHP-FPM lines (as this image runs Apache mod_php natively)
RUN mkdir -p /_config \
    && touch /_config/apache-mpm.conf /_config/drupal-runtime.conf \
    && echo "IncludeOptional /_config/apache-mpm.conf" >> /etc/apache2/apache2.conf \
    && echo "IncludeOptional /_config/drupal-runtime.conf" >> /etc/apache2/apache2.conf \
    && mkdir -p /mnt/files/public /mnt/files/private /mnt/files/tmp /mnt/files/config/sync

# 4. Runtime configurations & Scan environments
ENV PHP_INI_SCAN_DIR=/usr/local/etc/php/conf.d:/_config
WORKDIR /var/www/html

# 5. Global Composer/Drush Shortcut Path
ENV PATH="/var/www/html/vendor/bin:${PATH}"

# 6. Recommended PHP.ini settings (Opcache & Output Buffering)
RUN { \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=4000'; \
        echo 'opcache.revalidate_freq=60'; \
    } > /usr/local/etc/php/conf.d/opcache-recommended.ini

RUN { \
        echo 'output_buffering=true'; \
    } > /usr/local/etc/php/conf.d/docker-php-drupal-recommended.ini

# 7. Standardize file system ownership under non-root user
# Fixes Apache runtime pid/lock writes for unprivileged user execution
RUN chown -R www-data:www-data \
    /var/www/html \
    /var/run/apache2 \
    /var/lock/apache2 \
    /var/log/apache2 \
    /_config \
    /mnt/files \
    && chmod -R 755 /mnt/files

# 8. Drop security privileges completely
USER www-data
EXPOSE 8080

# NOTE: Ensure "docker-entrypoint.sh" exists in your local ./scripts directory 
# and handles passing control execution to the CMD arguments.
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
