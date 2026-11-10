#!/bin/bash
# v19.sh by Daniele Lolli (UncleDan) feat. Claude AI - Release 1.0 - 2026-11-10 16-01-58
set -euo pipefail
umask 077

result=${TKL_TEST_RESULT:?TKL_TEST_RESULT is required}
password=${TKL_TEST_DB_PASS:?TKL_TEST_DB_PASS is required}
work=/run/tkl-v19-tests/lamp
database=tkl_v19_lamp_$$
table_name=persistence
php_test=/var/www/tkl-v19-lamp-db.php
php8_v=$(find /etc/php -mindepth 1 -maxdepth 1 -name '8.*' -printf '%f\n' | sort -V | tail -n1)
client_conf=$work/client.cnf
password_file=$work/db-password

mysql_qa() {
    mysql --defaults-extra-file="$client_conf" "$@"
}

cleanup() {
    status=$?
    trap - EXIT
    mysql_qa --execute="DROP DATABASE IF EXISTS \`$database\`;" \
        >/dev/null 2>&1 || true
    rm -f -- "$php_test" /var/www/app-php5/tkl-v19-lamp-db.php \
        /var/www/app-php8/tkl-v19-lamp-db.php
    rm -rf -- "$work"
    exit "$status"
}
trap cleanup EXIT

install -d -o root -g www-data -m 0750 "$work"
cat >"$client_conf" <<EOF
[client]
user=root
password=$password
EOF
chmod 0600 "$client_conf"

systemctl --quiet is-active \
    apache2.service mariadb.service multi-user.target \
    "php$php8_v-fpm.service" php5.6-fpm.service
grep -Fq 'Inithooks run completed' /var/log/inithooks.log
grep -Fq '[40lamp] successfully completed' /var/log/inithooks.log
apache2ctl configtest 2>&1 | grep -Fq 'Syntax OK'
php -m | grep -Fxq mysqli
php5.6 -m | grep -Fxq mysqli
php -r 'exit(PHP_MAJOR_VERSION == 8 ? 0 : 1);'
apache2ctl -M 2>/dev/null | grep -Fq mpm_event_module
apache2ctl -M 2>/dev/null | grep -Fq proxy_fcgi_module
/usr/local/bin/rector --version >/dev/null
/usr/local/bin/phpcs -i | grep -Fq PHPCompatibility
test -x /usr/local/bin/tkl-php5to8

curl -kfsS https://127.0.0.1/ >"$work/landing.html"
grep -Eqi 'TurnKey.*LAMP|LAMP' "$work/landing.html"
curl -kfsS https://127.0.0.1:12322/ >"$work/adminer.html"
grep -Fqi Adminer "$work/adminer.html"

mysql_qa <<SQL
CREATE DATABASE \`$database\`;
CREATE TABLE \`$database\`.\`$table_name\` (message varchar(64) NOT NULL);
INSERT INTO \`$database\`.\`$table_name\` VALUES ('lamp-v19-persistence');
SQL
printf '%s' "$password" >"$password_file"
chown root:www-data "$password_file"
chmod 0640 "$password_file"
cat >"$php_test" <<PHP
<?php
\$password = trim(file_get_contents('$password_file'));
\$database = new mysqli('localhost', 'adminer', \$password, '$database');
if (\$database->connect_error) { http_response_code(500); exit('connect-failed'); }
\$result = \$database->query('SELECT message FROM $table_name');
if (!\$result) { http_response_code(500); exit('query-failed'); }
header('Content-Type: text/plain');
echo \$result->fetch_row()[0];
?>
PHP
chmod 0644 "$php_test"

curl -kfsS https://127.0.0.1/tkl-v19-lamp-db.php \
    >"$work/flow-before-restart.txt"
grep -Fxq lamp-v19-persistence "$work/flow-before-restart.txt"

# same database from both app vhosts, each one with its own PHP version
sed 's|echo \$result->fetch_row()\[0\];|echo PHP_MAJOR_VERSION, ":", $result->fetch_row()[0];|' \
    "$php_test" >/var/www/app-php5/tkl-v19-lamp-db.php
cp /var/www/app-php5/tkl-v19-lamp-db.php /var/www/app-php8/
chmod 0644 /var/www/app-php5/tkl-v19-lamp-db.php /var/www/app-php8/tkl-v19-lamp-db.php
curl -kfsS https://127.0.0.1:5443/tkl-v19-lamp-db.php >"$work/app-php5.txt"
grep -Fxq 5:lamp-v19-persistence "$work/app-php5.txt"
curl -kfsS https://127.0.0.1:8443/tkl-v19-lamp-db.php >"$work/app-php8.txt"
grep -Fxq 8:lamp-v19-persistence "$work/app-php8.txt"
# app trees are not reachable through the default vhost
test "$(curl -ks -o /dev/null -w '%{http_code}' https://127.0.0.1/app-php5/)" = 404

systemctl restart mariadb.service apache2.service
systemctl --quiet is-active mariadb.service apache2.service
curl -kfsS https://127.0.0.1/tkl-v19-lamp-db.php \
    >"$work/flow-after-restart.txt"
grep -Fxq lamp-v19-persistence "$work/flow-after-restart.txt"

apache_version=$(dpkg-query -W -f='${Version}' apache2)
php_version=$(dpkg-query -W -f='${Version}' "php$php8_v-fpm")
php5_version=$(dpkg-query -W -f='${Version}' php5.6-fpm)
mariadb_version=$(dpkg-query -W -f='${Version}' mariadb-server)
adminer_version=$(dpkg-query -W -f='${Version}' adminer)
for package in apache2 "php$php8_v-fpm" php5.6-fpm mariadb-server adminer; do
    candidate=$(apt-cache policy "$package" | awk '/Candidate:/ {print $2}')
    test -n "$candidate" && test "$candidate" != '(none)'
done
grep -Rqs '^Suites:.*trixie' /etc/apt/sources.list.d
apt-cache policy php5.6-fpm | grep -Fq packages.sury.org
# PHP 8 must still come from Debian (Sury pinned to 10 for non php5.6 packages)
! apt-cache policy "php$php8_v-fpm" | sed -n '/\*\*\*/,/^ *[0-9]/p' | grep -Fq packages.sury.org
if test -f /etc/apt/sources.list; then
    ! grep -qi bookworm /etc/apt/sources.list
fi
! grep -Rqi bookworm /etc/apt/sources.list.d
! grep -F -- "$password" /var/log/inithooks.log

cat >"$result" <<EOF
package_source=Debian Trixie APT packages for Apache, PHP 8, MariaDB and Adminer; packages.sury.org for PHP 5.6; composer for Rector/PHPCompatibility
installed_version=apache2 $apache_version; php$php8_v-fpm $php_version; php5.6-fpm $php5_version; mariadb-server $mariadb_version; adminer $adminer_version; $(/usr/local/bin/rector --version | head -n1)
runtime_checks=normal firstboot completion, Apache HTTPS (event MPM + PHP-FPM) and PHP mysqli, MariaDB-backed PHP request across Apache and database restart, same database from PHP 5.6 (:5443) and PHP 8 (:8443) vhosts, and Adminer HTTPS reachability
updater_command=apt-cache policy apache2 php$php8_v-fpm php5.6-fpm mariadb-server adminer
updater_result=eligible APT candidates found; installed packages unchanged
updater_channel=Debian and TurnKey Trixie signed APT repositories
integrity_evidence=installed dpkg state and configured signed Trixie Deb822 repositories; no Bookworm source remains
EOF
