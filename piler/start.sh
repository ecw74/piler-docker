#!/bin/bash

DATAROOTDIR="/var"
SYSCONFDIR="/usr/local/etc"
PILER_KEY="${SYSCONFDIR}/piler/piler.key"
PILER_CONF="${SYSCONFDIR}/piler/piler.conf"
MYSQL_DB_CREATED="${SYSCONFDIR}/piler/mysql_db_created"
SPHINX_CONF="${SYSCONFDIR}/piler/sphinx.conf"
NGINX_CONF="${SYSCONFDIR}/piler/piler-nginx.conf"
SITE_CONFIG_PHP="${SYSCONFDIR}/piler/config-site.php"
CRONT_TAB_PILER="${SYSCONFDIR}/piler/cron.jobs"

setup_tz() {
    rm -rf /etc/localtime
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
    echo $TZ > /etc/timezone
}

create_mysql_db() {
    if [[ ! -f "${MYSQL_DB_CREATED}" ]]; then
        echo "-- Create MySQLDatabase"
        mysql -h "$MYSQL_HOSTNAME" -u "$MYSQL_PILER_USER" --password="$MYSQL_PILER_PASSWORD" "$MYSQL_DATABASE" < "${PILER_SRC_FOLDER}/db-mysql.sql"
        touch "$MYSQL_DB_CREATED"
    fi
}

create_cron_entries() {
    echo "-- Crontab Entires"
    if [[ ! -f "${CRONT_TAB_PILER}" ]]; then
        {
            echo "";
            echo "### PILERSTART";
            echo "5,35 * * * * /usr/local/libexec/piler/indexer.delta.sh";
            echo "30   2 * * * /usr/local/libexec/piler/indexer.main.sh";
            echo "3 * * * * /usr/local/libexec/piler/watch_sphinx_main_index.sh";
            echo "*/15 * * * * /usr/bin/indexer --quiet tag1 --rotate --config ${SPHINX_CONF}";
            echo "*/15 * * * * /usr/bin/indexer --quiet note1 --rotate --config ${SPHINX_CONF}";
            echo "30   6 * * * /usr/bin/php /usr/local/libexec/piler/generate_stats.php --webui /var/piler/www >/dev/null";
            echo "*/5 * * * * /usr/bin/find /var/piler/error -type f|wc -l > /var/piler/stat/error";
            echo "*/5 * * * * /usr/bin/find /var/piler/www/tmp -type f -name i.\* -exec rm -f {} \;";
            echo "2 0 * * * /usr/local/libexec/piler/pilerpurge.py -c ${PILER_CONF}";
            echo "### PILEREND";
        } >> "${CRONT_TAB_PILER}"
    fi

    crontab -u "$PILER_USER" "$CRONT_TAB_PILER"
}

create_sphinx_conf() {
    if [[ ! -f "${SPHINX_CONF}" ]]; then
        echo "-- Create Sphinx Config"
        cp ${PILER_SRC_FOLDER}/sphinx.conf.dist "$SPHINX_CONF"
        sed -i "s%MYSQL_HOSTNAME%${MYSQL_HOSTNAME}%" "$SPHINX_CONF"
        sed -i "s%MYSQL_DATABASE%${MYSQL_DATABASE}%" "$SPHINX_CONF"
        sed -i "s%MYSQL_USERNAME%${MYSQL_PILER_USER}%" "$SPHINX_CONF"
        sed -i "s%MYSQL_PASSWORD%${MYSQL_PILER_PASSWORD}%" "$SPHINX_CONF"
        sed -i "s%220%311%" "$SPHINX_CONF"
        # Bugfix see https://sphinxsearch.com/forum/view.html?id=16193
        sed -i "s%sql_query_kbatch%sql_query_killlist%" "$SPHINX_CONF"
    fi

    if [[ ! -d "${DATAROOTDIR}/piler/sphinx" ]]; then
        echo "-- Initializing Sphinx Indices"
        mkdir -p ${DATAROOTDIR}/piler/sphinx
        chown -R $PILER_USER ${DATAROOTDIR}/piler/sphinx
        chgrp -R $PILER_USER ${DATAROOTDIR}/piler/sphinx
        su "$PILER_USER" -c "indexer --all --config $SPHINX_CONF"
    fi
}

create_piler_key() {
    if [[ ! -f "${PILER_KEY}" ]]; then
        echo "-- Create Piler Key"
        dd if=/dev/urandom bs=56 count=1 of=${PILER_KEY} &> /dev/null
    fi
}

create_piler_conf() {
    if [[ ! -f "$PILER_CONF" ]]; then
        echo "-- Create Piler Config"
        cp ${PILER_SRC_FOLDER}/piler.conf "$PILER_CONF"
        chmod 640 "$PILER_CONF"
        chown root:$PILER_USER "$PILER_CONF"
        sed -i "s%hostid=.*%hostid=${PILER_HOST%%:*}%" "$PILER_CONF"
        sed -i "s%username=.*%username=${PILER_USER}%" "$PILER_CONF"
        sed -i "s%tls_enable=.*%tls_enable=1%" "$PILER_CONF"
        sed -i "s%mysqlsocket=.*%mysqlhost=${MYSQL_HOSTNAME}\nmysqlport=3306%" "$PILER_CONF"
        sed -i "s%mysqluser=.*%mysqluser=${MYSQL_PILER_USER}%" "$PILER_CONF"
        sed -i "s%mysqlpwd=.*%mysqlpwd=${MYSQL_PILER_PASSWORD}%" "$PILER_CONF"

        # Bugfix see https://bitbucket.org/jsuto/piler/issues/880/pilerpurge-not-working
        echo "queuedir=/var/piler/store" >> "$PILER_CONF"
    fi
}

create_nginx_conf() {
    if [[ ! -f "/etc/nginx/sites-enabled/piler" ]]; then
        echo "-- Create Nginx Config"
        cp ${PILER_SRC_FOLDER}/piler-nginx.conf "$NGINX_CONF"
        sed -i "s%PILER_HOST%${PILER_HOST}%" "$NGINX_CONF"
        sed -i "s%php7\.2%php7\.4%" "$NGINX_CONF"
        rm -rf /etc/nginx/sites-enabled/default
        ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/piler
    fi

    if [[ ! -d "${DATAROOTDIR}/piler/www" ]]; then
        echo "-- Create Web Folder"
        cp -R ${PILER_SRC_FOLDER}/webui ${DATAROOTDIR}/piler/www
        chown www-data:www-data ${DATAROOTDIR}/piler/www
        rm -rf ${DATAROOTDIR}/piler/www/Makefile*
    fi

    if [[ ! -f "${SITE_CONFIG_PHP}" ]]; then
        
        echo "<?php" > "${SITE_CONFIG_PHP}"
        echo "-- Create Site Config"
        
        compgen -A variable SITE_CONFIG_PHP_ | while read v; do
                echo "\$config['${v//SITE_CONFIG_PHP_/}'] = '${!v}';" >> "${SITE_CONFIG_PHP}"
        done

        echo "?>" >> "${SITE_CONFIG_PHP}"

    fi
}

create_folders()
 {
    if [[ ! -d "${DATAROOTDIR}/piler/stat" ]]; then
        mkdir -p ${DATAROOTDIR}/piler/stat
        chown -R $PILER_USER ${DATAROOTDIR}/piler/stat
    fi

    if [[ ! -d "${DATAROOTDIR}/piler/error" ]]; then
        mkdir -p ${DATAROOTDIR}/piler/error
        chown -R $PILER_USER ${DATAROOTDIR}/piler/error
    fi

    if [[ ! -d "${DATAROOTDIR}/piler/store" ]]; then
        mkdir -p ${DATAROOTDIR}/piler/store
        chown -R $PILER_USER ${DATAROOTDIR}/piler/store
    fi

    if [[ ! -d "${DATAROOTDIR}/piler/tmp" ]]; then
        mkdir -p ${DATAROOTDIR}/piler/tmp
        chown -R $PILER_USER ${DATAROOTDIR}/piler/tmp
    fi
 }

# create required configs
echo "-----------------------------------------------------------"
echo "-- Mailpiler Host"
echo "-----------------------------------------------------------"
setup_tz
create_folders
create_mysql_db
create_cron_entries
create_sphinx_conf
create_piler_key
create_piler_conf
create_nginx_conf

service cron start
service php7.4-fpm start
service nginx start
service rc.searchd start
service rc.piler start

while true; do sleep 120; done