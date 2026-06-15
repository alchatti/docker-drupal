ARG PHP=8.3
ARG OS=bookworm

FROM php:${PHP}-apache-${OS}

RUN set -eux; \
	\
	if command -v a2enmod; then \
# https://github.com/drupal/drupal/blob/d91d8d0a6d3ffe5f0b6dde8c2fbe81404843edc5/.htaccess (references both mod_expires and mod_rewrite explicitly)
		a2enmod expires rewrite alias; \
	fi; \
	\
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
        mariadb-client \
        postgresql-client \
	; \
	\
	docker-php-ext-configure gd \
		--with-freetype \
		--with-jpeg=/usr \
		--with-webp \
	; \
	\
	docker-php-ext-install -j "$(nproc)" \
		gd \
		pdo_mysql \
		pdo_pgsql \
		zip \
    ; \
    \
    # Install PECL dependencies
    pecl install redis; \
    docker-php-ext-enable redis; \
    \
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
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
#RUN ln -s /var/www/html/vendor/bin/drush /usr/local/bin/drush
ENV PATH=${PATH}:/var/www/html/vendor/bin

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
