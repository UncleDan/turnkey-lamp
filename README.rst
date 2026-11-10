LAMP Stack PHP 5 -> 8 (beta) - Web Stack (MySQL) with PHP 5.6 + PHP 8
=====================================================================

*Personal "beta" variant of TurnKey LAMP v19: a legacy PHP 5 application and
its PHP 8 upgrade run side by side, on two virtual hosts, against the same
database. Rector is included to do the upgrade.*

LAMP stack is a popular open source web platform commonly used to run
dynamic web sites and servers. It includes Linux, Apache, MariaDB (MySQL
drop-in replacement), and PHP/Python/Perl. It is considered by many, as
the platform of choice for development and deployment of high performance
web applications which require a solid and reliable foundation.

LAMP stack includes all the standard features in `TurnKey Core`_, and on
top of that:

- SSL support out of the box.
- PHP, Python and Perl support for Apache2 and MySQL (MariaDB).
- PHP development helpers:

    - composer_ installed globally (/usr/local/bin/composer) from upstream.
    - turnkey-composer_ convenience wrapper script - runs composer as the
      'www-data' (webserver) user account.
    - `php-xdebug`_: debugging and profiling.
    - `php-pear`_: php extension and application repository.
    - php-cli: command-line interpreter.

- `Adminer`_ administration frontend for MySQL (MariaDB) (listening on port
  12322 - uses SSL).
- MariaDB_ - MySQL drop-in replacement.
- MySQLTuner_ - Perl script to review and tweak a MySQL/MariaDB
  installation.
- `Postfix`_ MTA (bound to localhost) to allow sending of email from web
  applications (e.g., password recovery).
- Webmin modules for configuring Apache2, PHP, MySQL and Postfix.

PHP 5 -> PHP 8 migration
------------------------

Apache uses the event MPM with PHP-FPM (mod_php is disabled), so each virtual
host can use its own PHP version:

=========================  ==============  ===================  =====================
Site                       Port (HTTPS)    PHP                  Document root
=========================  ==============  ===================  =====================
TurnKey landing, Adminer   443, 12322      8.x (Debian)         /var/www
Legacy app                 5443            5.6 (Sury repo)      /var/www/app-php5
Upgraded app               8443            8.x (Debian)         /var/www/app-php8
=========================  ==============  ===================  =====================

- PHP 5.6 comes from packages.sury.org (``PHP_VERSION = 5.6`` in the Makefile:
  only ``php5.6-*`` and a few libraries are pinned to Sury, PHP 8 stays the
  Debian one). ``php`` is PHP 8, ``php5.6`` is the legacy CLI.
- Each app has its own FPM pool (``/etc/php/<ver>/fpm/pool.d/app-php*.conf``):
  errors are never displayed (pages look the same), all of them are logged to
  ``/var/log/php/app-php5.error.log`` and ``/var/log/php/app-php8.error.log``;
  ``short_open_tag``, timezone and charset are the same on both.
- Both apps share the MariaDB server: the PHP 8 copy keeps the legacy config
  files, so it uses the same database and credentials.
- `Rector`_, `PHP_CodeSniffer`_ and `PHPCompatibility`_ are installed in
  ``/opt/php5to8-tools`` (wrappers: ``rector``, ``phpcs``, ``phpcbf``).
- ``tkl-php5to8`` drives the whole process.

Workflow::

    # 1. copy the legacy app to /var/www/app-php5 and import its database
    #    (Adminer or: mysql DBNAME < dump.sql), check https://<ip>:5443/
    tkl-php5to8 status                  # versions, vhosts, DB charset per PHP
    tkl-php5to8 check                   # read only report (PHPCompatibility,
                                        # lint, pitfalls, Rector dry run)
    # 2. create the PHP 8 copy; directories with uploaded files can be shared
    tkl-php5to8 migrate --share uploads
    # 3. compare https://<ip>:5443/ and https://<ip>:8443/, fix the rest in
    #    /var/www/app-php8 (tail -f /var/log/php/app-php8.error.log)
    tkl-php5to8 diff | less

``migrate`` never touches the legacy app; it refuses to overwrite a non empty
``app-php8`` unless ``--force`` is given (a backup goes to
``/var/backups/php5to8``). Reports are kept in ``/root/php5to8-reports``.

What Rector does not do (reported by ``check``/``migrate`` in ``pitfalls.md``):

- ``mysql_*`` functions (removed in PHP 7.0): port them to mysqli/PDO.
- ``php_value``/``php_flag`` in ``.htaccess`` (mod_php only, HTTP 500 under
  PHP-FPM): move them to a ``.user.ini`` file.
- ``mcrypt_*`` (removed in PHP 7.2).
- Connection charset: if the app never sets it, PHP 5.6 and PHP 8 may get a
  different one; compare with ``tkl-php5to8 status`` and, if needed, force it
  in ``/etc/mysql/mariadb.conf.d/90-php5to8.cnf``.

A separate `LAPP stack`_ appliance features PostgreSQL instead of MySQL.

Credentials *(passwords set at first boot)*
-------------------------------------------

-  Webmin, SSH, MySQL: username **root**

-  Adminer: username **adminer**

.. _TurnKey Core: https://www.turnkeylinux.org/core
.. _composer: https://getcomposer.org/
.. _turnkey-composer: https://github.com/turnkeylinux/common/blob/master/overlays/composer/usr/local/bin/turnkey-composer
.. _php-xdebug: https://xdebug.org/
.. _php-pear: https://pear.php.net/
.. _Adminer: https://www.adminer.org/
.. _MariaDB: https://mariadb.com/
.. _MySQLTuner: https://github.com/major/MySQLTuner-perl/blob/master/README.md
.. _Postfix: https://www.postfix.org/
.. _Rector: https://getrector.com/
.. _PHP_CodeSniffer: https://github.com/PHPCSStandards/PHP_CodeSniffer
.. _PHPCompatibility: https://github.com/PHPCompatibility/PHPCompatibility
.. _LAPP stack: https://www.turnkeylinux.org/lapp
