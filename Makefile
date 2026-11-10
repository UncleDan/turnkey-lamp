# Legacy PHP 5.6 (from the Sury repo) side by side with Debian's default PHP 8.
# PHP_VERSION makes common/conf/bootstrap_apt enable packages.sury.org with
# pins: php5.6-* (and a few libs) at 550, everything else from Sury at 10 - so
# Debian's PHP 8 packages stay the Debian ones.
PHP_VERSION = 5.6

COMMON_OVERLAYS = tkl-webcp
COMMON_CONF = tkl-webcp

include $(FAB_PATH)/common/mk/turnkey/lamp.mk
include $(FAB_PATH)/common/mk/turnkey/composer.mk

# 5443: legacy app on PHP 5.6 - 8443: upgraded app on PHP 8 (both HTTPS)
WEBMIN_FW_TCP_INCOMING += 5443 8443

include $(FAB_PATH)/common/mk/turnkey.mk
