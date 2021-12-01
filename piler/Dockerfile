FROM debian:sid-slim

ENV DEBIAN_FRONTEND noninteractive

ARG MAILPILER_GIT_TAG="piler-1.3.10"

ARG PILER_HOST=localhost
ARG PILER_USER=piler

ARG MYSQL_HOSTNAME=piler-db
ARG MYSQL_DATABASE=piler
ARG MYSQL_PILER_USER=piler
ARG MYSQL_PILER_PASSWORD=piler

ENV SITE_CONFIG_PHP_SITE_NAME=${PILER_HOST}
ENV SITE_CONFIG_PHP_SITE_URL="http://${PILER_HOST}/"

ARG SITE_CONFIG_PHP_DB_HOSTNAME=${MYSQL_HOSTNAME}
ARG SITE_CONFIG_PHP_DB_DATABASE=${MYSQL_DATABASE}
ARG SITE_CONFIG_PHP_DB_USERNAME=${MYSQL_PILER_USER}
ARG SITE_CONFIG_PHP_DB_PASSWORD=${MYSQL_PILER_PASSWORD}

ENV PILER_HOST=$PILER_HOST
ENV PILER_USER=$PILER_USER
ENV TZ=$SITE_CONFIG_PHP_TIMEZONE

ENV MYSQL_HOSTNAME=$MYSQL_HOSTNAME
ENV MYSQL_DATABASE=$MYSQL_DATABASE
ENV MYSQL_PILER_USER=$MYSQL_PILER_USER
ENV MYSQL_PILER_PASSWORD=$MYSQL_PILER_PASSWORD

ENV SITE_CONFIG_PHP_SITE_NAME=${SITE_CONFIG_PHP_SITE_NAME}
ENV SITE_CONFIG_PHP_SITE_URL=${SITE_CONFIG_PHP_SITE_URL}

ENV SITE_CONFIG_PHP_DB_HOSTNAME=${SITE_CONFIG_PHP_DB_HOSTNAME}
ENV SITE_CONFIG_PHP_DB_DATABASE=${SITE_CONFIG_PHP_DB_DATABASE}
ENV SITE_CONFIG_PHP_DB_USERNAME=${SITE_CONFIG_PHP_DB_USERNAME}
ENV SITE_CONFIG_PHP_DB_PASSWORD=${SITE_CONFIG_PHP_DB_PASSWORD}

ENV MAILPILER_GIT_TAG=${MAILPILER_GIT_TAG}

ENV PILER_SRC_FOLDER=/src

ENV SPHINX_DOWNLOAD_URL_BASE="https://download.mailpiler.com/generic-local" \
SPHINX_BIN_TARGZ="sphinx-3.1.1-bin.tar.gz" \
SPHINX_BIN_TARGZ_SHA256="f543fae12d4a240b424a906519936c8ada6e338346e215edfe0b8ec75c930d56"

RUN echo "**** install required packages ****" && \
	apt-get update && \
	apt-get -y dist-upgrade && \
	apt-get -y install build-essential busybox-syslogd catdoc cron curl default-libmysqlclient-dev libssl-dev \
	    		libtre-dev libwrap0-dev libzip-dev mysql-client nginx php7.4-curl php7.4-fpm php7.4-gd php7.4-ldap php7.4-memcache \
                php7.4-mysql php7.4-common poppler-utils python3-mysqldb supervisor sysstat tnef unrtf vim git && \
	echo "**** add user ****" && \
	groupadd piler && \
	useradd -g ${PILER_USER} -m -s /bin/sh -d /var/piler ${PILER_USER} && \
	usermod -L ${PILER_USER} && \
	chmod 755 /var/piler && \
	echo "**** download and build xlhtml ****" && \
	mkdir -p /build/xlhtml && \
	curl -L https://bitbucket.org/jsuto/piler/downloads/xlhtml-0.5.1-sj-mod.tar.gz | tar xvz --strip=1 -C /build/xlhtml && \
	cd /build/xlhtml && \
	./configure && \
	make && \
	make install && \
	echo "**** download and build piler ${MAILPILER_GIT_TAG} ****" && \
	mkdir /build/piler && \
    git clone -b ${MAILPILER_GIT_TAG} --single-branch https://bitbucket.org/jsuto/piler.git  /build/piler && \
    cd /build/piler && \
	./configure --localstatedir=/var --with-database=mysql --enable-tcpwrappers && \
	make && \
	make install && \
	ldconfig && \
	echo "**** download and install sphinx ****" && \
    curl -fSL -o ${SPHINX_BIN_TARGZ} "${SPHINX_DOWNLOAD_URL_BASE}/${SPHINX_BIN_TARGZ}" && \
    echo "$SPHINX_BIN_TARGZ_SHA256 *$SPHINX_BIN_TARGZ" | sha256sum -c - || echo "sha256sum FAILD: ${SPHINX_DOWNLOAD_URL_BASE}/${SPHINX_BIN_TARGZ}" ; \
    echo "should $SPHINX_BIN_TARGZ_SHA256 but is:" ; sha256sum $SPHINX_BIN_TARGZ && \
    tar -zxvf ${SPHINX_BIN_TARGZ} -C / && \
    rm -f ${SPHINX_BIN_TARGZ} && \
	echo "**** preserve config files ****" && \
	mkdir ${PILER_SRC_FOLDER} && \
    cp /build/piler/util/db-mysql.sql ${PILER_SRC_FOLDER} && \
	cp /build/piler/etc/sphinx.conf.dist ${PILER_SRC_FOLDER} && \
	cp /build/piler/etc/piler.conf ${PILER_SRC_FOLDER} && \
	cp /build/piler/contrib/webserver/piler-nginx.conf ${PILER_SRC_FOLDER} && \
	cp -R /build/piler/webui ${PILER_SRC_FOLDER} && \
	echo "**** cleanup ****" && \
	apt-get clean && \
    rm -rf \
	/tmp/* \
	/var/lib/apt/lists/* \
	/var/tmp/* \
	/build

COPY start.sh /start.sh
RUN chmod +x /start.sh

# Fix till 1.3.8
RUN rm -rf /usr/local/libexec/piler/pilerpurge.py
COPY pilerpurge.py /usr/local/libexec/piler/pilerpurge.py
RUN chmod +x /usr/local/libexec/piler/pilerpurge.py

EXPOSE 25/tcp
EXPOSE 80/tcp

VOLUME /usr/local/etc/piler
VOLUME /var/piler

CMD ["/start.sh"]