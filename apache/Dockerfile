ARG PHP=8.3
ARG OS=bookworm

FROM php:${PHP}-apache-${OS}

COPY --chmod=+x scripts/install-php-dependencies.sh /usr/local/bin/install-php-dependencies.sh
RUN /usr/local/bin/install-php-dependencies.sh \
    && rm /usr/local/bin/install-php-dependencies.sh

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
#RUN ln -s /var/www/html/vendor/bin/drush /usr/local/bin/drush
ENV PATH="/var/www/html/vendor/bin:${PATH}"

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

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=60'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

# https://www.drupal.org/node/3298550
# Drupal now recommends sites enable PHP output buffering by default, if PHP is run as a server module
# e.g. with Apache's mod_php
RUN { \
		echo 'output_buffering=true'; \
	} > /usr/local/etc/php/conf.d/docker-php-drupal-recommended.ini

# 9. Drop security privileges completely
USER www-data
EXPOSE 8080

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"] 
