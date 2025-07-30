FROM php:8.3-apache

ENV DEBIAN_FRONTEND=noninteractive

# install the PHP extensions we need
RUN set -ex; \
	\
	apt-get update; \
	apt-get install -y --force-yes \
		unzip \
		openssl \
		libcurl4-openssl-dev \
		libjpeg-dev \
		libpng-dev \
		libmcrypt-dev \
		libxml2-dev \
		libonig-dev \
		libzip-dev \
        default-mysql-client \
		netcat-openbsd \ 
		cron \
		supervisor \
		sudo \
	; \
	rm -rf /var/lib/apt/lists/*; \
	\
	docker-php-ext-configure gd --with-jpeg=/usr; \
	docker-php-ext-install -j$(nproc) pdo_mysql curl dom gd mbstring zip exif
# RUN	docker-php-ext-install -j$(nproc) json
# RUN	docker-php-ext-install -j$(nproc) tokenizer

RUN pecl install -o -f redis \
    &&  rm -rf /tmp/pear \
    &&  docker-php-ext-enable redis

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
		echo 'opcache.fast_shutdown=1'; \
		echo 'opcache.enable_cli=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

RUN a2enmod rewrite
RUN a2enmod remoteip 
RUN a2enmod headers

RUN echo '\
<IfModule mod_remoteip.c>\n\
    RemoteIPHeader X-Real-IP\n\
    RemoteIPTrustedProxy 172.20.0.0/8 \n\
	RemoteIPTrustedProxy 192.20.0.0/8 \n\
</IfModule>\n'\
>> /etc/apache2/conf-available/remoteip.conf

RUN a2enconf remoteip 

VOLUME /var/www/html

ENV TASTYIGNITER_VERSION=3.7.7

RUN set -ex; \
	curl -o tastyigniter.zip -fSL "https://codeload.github.com/tastyigniter/TastyIgniter/zip/v${TASTYIGNITER_VERSION}"; \
	unzip tastyigniter.zip -d /usr/src/; \
	rm tastyigniter.zip; \
	mv /usr/src/TastyIgniter-${TASTYIGNITER_VERSION} /usr/src/tastyigniter


RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
    cd /usr/src/tastyigniter && composer install
COPY supervisord.conf /etc/supervisor/supervisord.conf

COPY docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["apache2-foreground"]