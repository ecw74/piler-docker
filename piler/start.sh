#!/bin/bash

DATAROOTDIR="/var"
SYSCONFDIR="/usr/local/etc"
PILER_KEY="${SYSCONFDIR}/piler/piler.key"
PILER_CONF="${SYSCONFDIR}/piler/piler.conf"
PILER_MY_CNF="${SYSCONFDIR}/piler/.my.cnf"
SPHINX_CONF="${SYSCONFDIR}/piler/sphinx.conf"
NGINX_CONF="${SYSCONFDIR}/piler/piler-nginx.conf"
SITE_CONFIG_PHP="${SYSCONFDIR}/piler/config-site.php"
CRONT_TAB_PILER="${SYSCONFDIR}/piler/piler.cron"

give_it_to_piler() {
   local f="$1"

   [[ -f "$f" ]] || error "${f} does not exist, aborting"

   chown "${PILER_USER}:${PILER_USER}" "$f"
   chmod 600 "$f"
}

setup_tz() {
    rm -rf /etc/localtime
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
    echo $TZ > /etc/timezone
}

create_cron_entries() {
    echo "-- Crontab Entires"
    if [[ ! -f "${CRONT_TAB_PILER}" ]]; then
        cp ${PILER_SRC_FOLDER}/piler.cron ${CRONT_TAB_PILER}
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
        sed -i "s%memcached_servers=.*%memcached_servers=${MEMCACHED_HOST}%" "$PILER_CONF"

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

        {
            echo "\$memcached_server = ['${MEMCACHED_HOST}', 11211];"
            "?>"
        } >> "${SITE_CONFIG_PHP}"
    fi
}

create_folders() {
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

wait_until_mysql_server_is_ready() {
   while true; do if mysql "--defaults-file=${PILER_MY_CNF}" <<< "show databases"; then break; fi; log "${MYSQL_HOSTNAME} is not ready"; sleep 5; done
   echo "-- ${MYSQL_HOSTNAME} is ready"
}

create_database() {
   local table
   local has_metadata_table=0

   wait_until_mysql_server_is_ready

   while read -r table; do
      if [[ "$table" == metadata ]]; then has_metadata_table=1; fi
   done < <(mysql "--defaults-file=${PILER_MY_CNF}" "$MYSQL_DATABASE" <<< 'show tables')

   if [[ $has_metadata_table -eq 0 ]]; then
      echo "-- Create MySQLDatabase"
      mysql "--defaults-file=${PILER_MY_CNF}" "$MYSQL_DATABASE" < /usr/share/piler/db-mysql.sql
   else
      echo "-- MySQLDatabase exists"
   fi
}

create_my_cnf_files() {
   printf "[client]\nhost = %s\nuser = %s\npassword = %s\n[mysqldump]\nhost = %s\nuser = %s\npassword = %s\n" \
      "$MYSQL_HOSTNAME" "$MYSQL_USER" "$MYSQL_PASSWORD" "$MYSQL_HOSTNAME" "$MYSQL_USER" "$MYSQL_PASSWORD" \
      > "$PILER_MY_CNF"

   give_it_to_piler "$PILER_MY_CNF"
}

# create required configs
echo "-----------------------------------------------------------"
echo "-- Mailpiler Host"
echo "-----------------------------------------------------------"
setup_tz
create_folders
create_my_cnf_files
create_database
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