FROM gitpod/workspace-full

USER root

RUN apt-get update \
 && apt-get -y install apache2 multitail postgresql postgresql-contrib mysql-server mysql-client \
 && apt-get -y install php-cli php-bz2 php-bcmath php-gmp php-imap php-shmop php-soap php-xmlrpc php-xsl php-ldap \
 && apt-get -y install php-amqp php-apcu php-imagick php-memcached php-mongodb php-oauth php-redis\
 && apt-get -y install libtidy-dev php7.4-tidy\
 && apt-get clean && rm -rf /var/cache/apt/* /var/lib/apt/lists/* /tmp/*
 
RUN sed -i "s/;extension=tidy/extension=tidy/g" /etc/php/7.4/cli/php.ini

RUN mkdir /var/run/mysqld

RUN chown -R gitpod:gitpod /var/run/apache2 /var/lock/apache2 /var/log/apache2 /etc/apache2 \
 && chown -R gitpod:gitpod /var/run/mysqld /usr/share/mysql /var/lib/mysql /var/log/mysql /etc/mysql

RUN echo 'ServerRoot ${GITPOD_REPO_ROOT}\n\
PidFile /var/run/apache2/apache.pid\n\
User gitpod\n\
Group gitpod\n\
IncludeOptional /etc/apache2/mods-enabled/*.load\n\
IncludeOptional /etc/apache2/mods-enabled/*.conf\n\
ServerName localhost\n\
Listen *:8000\n\
LogFormat "%h %l %u %t \"%r\" %>s %b" common\n\
CustomLog /var/log/apache2/access.log common\n\
ErrorLog /var/log/apache2/error.log\n\
<Directory />\n\
    AllowOverride All\n\
    Require all denied\n\
</Directory>\n\
DirectoryIndex index.php index.html\n\
DocumentRoot "${GITPOD_REPO_ROOT}/public"\n\
<Directory "${GITPOD_REPO_ROOT}/public">\n\
    Require all granted\n\
</Directory>\n\
IncludeOptional /etc/apache2/conf-enabled/*.conf' > /etc/apache2/apache2.conf

RUN a2enmod rewrite

USER root

RUN apt-get update
# apt-utils for gnupg2
RUN apt-get -y install apt-utils

# Install MySQL
ENV PERCONA_MAJOR 5.7
RUN apt-get update \
 && apt-get install -y gnupg2 \
 && apt-get clean && rm -rf /var/cache/apt/* /var/lib/apt/lists/* /tmp/* \
 && cd /var/run/mysqld \
 && wget -c https://repo.percona.com/apt/percona-release_latest.stretch_all.deb \
 && dpkg -i percona-release_latest.stretch_all.deb \
 && apt-get update

RUN set -ex; \
	{ \
		for key in \
			percona-server-server/root_password \
			percona-server-server/root_password_again \
			"percona-server-server-$PERCONA_MAJOR/root-pass" \
			"percona-server-server-$PERCONA_MAJOR/re-root-pass" \
		; do \
			echo "percona-server-server-$PERCONA_MAJOR" "$key" password 'nem4540'; \
		done; \
	} | debconf-set-selections; \
	apt-get update; \
	apt-get install -y \
		percona-server-server-5.7 percona-server-client-5.7 percona-server-common-5.7 \
	;
	
RUN chown -R gitpod:gitpod /etc/mysql /var/run/mysqld /var/log/mysql /var/lib/mysql /var/lib/mysql-files /var/lib/mysql-keyring

# Install our own MySQL config
COPY ./docker/mysql.cnf /etc/mysql/conf.d/mysqld.cnf
COPY ./docker/my.cnf /home/gitpod
RUN chown gitpod:gitpod /home/gitpod/my.cnf

USER gitpod

# Install default-login for MySQL clients
COPY ./docker/client.cnf /etc/mysql/conf.d/client.cnf

COPY ./docker/mysql-bashrc-launch.sh /etc/mysql/mysql-bashrc-launch.sh

USER root
