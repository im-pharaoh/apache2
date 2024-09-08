FROM ubuntu:latest

LABEL maintainer="stefan@pejcic.rs"
LABEL author="Stefan Pejcic"

ENV TZ=UTC
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:ondrej/php && \
    apt-get update && \
    apt-get install --no-install-recommends -y \
        msmtp \
        ttyd \
        screen \
        apache2 \
        mysql-server \
        php8.2-fpm \
        php8.2-mysql \
        php8.2-curl \
        php8.2-gd \
        php8.2-mbstring \
        php8.2-xml \
        php8.2-xmlrpc \
        php8.2-soap \
        php8.2-intl \
        php8.2-zip \
        php8.2-bcmath \
        php8.2-calendar \
        php8.2-exif \
        php8.2-ftp \
        php8.2-ldap \
        php8.2-sockets \
        php8.2-sysvmsg \
        php8.2-sysvsem \
        php8.2-sysvshm \
        php8.2-tidy \
        php8.2-uuid \
        php8.2-opcache \
        php8.2-redis \
        curl \
        cron \
        pwgen \
        zip \
        unzip \
        wget \
        nano \
        less \
        phpmyadmin \
        openssh-server \
        php-mbstring && \
        apt-get clean && \
        apt-get autoremove -y && \
        rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


########## PHP Composer ##########
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

########## EXPOSED PORTS ##########
EXPOSE 22 3306 7681 8080


########## APACHE ##########
RUN a2enmod ssl rewrite proxy proxy_http proxy_fcgi remoteip headers
ENV APACHE_PID_FILE /var/run/apache2/apache2.pid
COPY apache/apache2.conf /etc/apache2/

# Allow .htaccess rewrite rules (needed for WP pretty links and wpcli auto login)
#RUN sed -i '/<Directory \/var\/www\/>/,/AllowOverride None/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf
RUN mkdir -p /var/log/apache2/domlogs/

########## PHP-FPM ##########
# 8.2
RUN update-alternatives --set php /usr/bin/php8.2
RUN sed -i \
    -e 's/^upload_max_filesize = .*/upload_max_filesize = 1024M/' \
    -e 's/^max_input_time = .*/max_input_time = 600/' \
    -e 's/^memory_limit = .*/memory_limit = -1/' \
    -e 's/^post_max_size = .*/post_max_size = 1024M/' \
    -e 's/^max_execution_time = .*/max_execution_time = 600/' \
    -e 's/^opcache.enable= .*/opcache.enable=1/' \
    -e 's|^;sendmail_path = .*|sendmail_path = "/usr/bin/msmtp -t"|' \
    /etc/php/8.2/fpm/php.ini
RUN sed -i 's|;sendmail_path = *|sendmail_path = "/usr/bin/msmtp -t"|g' /etc/php/8.2/fpm/php.ini


RUN sed -i \
    -e 's/^upload_max_filesize = .*/upload_max_filesize = 1024M/' \
    -e 's/^max_input_time = .*/max_input_time = 600/' \
    -e 's/^memory_limit = .*/memory_limit = -1/' \
    -e 's/^post_max_size = .*/post_max_size = 1024M/' \
    -e 's/^max_execution_time = .*/max_execution_time = 600/' \
    -e 's/^opcache.enable= .*/opcache.enable=1/' \
    /etc/php/8.2/cli/php.ini
RUN sed -i 's|;sendmail_path = *|sendmail_path = "/usr/bin/msmtp -t"|g' /etc/php/8.2/cli/php.ini


########## SSH ##########
ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile


########## SSL #############
RUN mkdir -p /etc/apache2/ssl/ && cd /etc/apache2/ssl/ && openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=GB/ST=London/L=London/O=Global Security/OU=R&D Department/CN=openpanel.co"  -keyout cert.key  -out cert.crt


########## TERMINAL #############
# fix for webterminal: bash: permission denied: /home/user/.bashrc
RUN chmod 755 /root


########## WP-CLI ##########
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

########## cleanup ##########
RUN rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

########## docker run entrypoint  ##########
COPY entrypoint.sh /etc/entrypoint.sh
RUN chmod +x /etc/entrypoint.sh
CMD ["/bin/sh", "-c", "/etc/entrypoint.sh ; tail -f /dev/null"]
