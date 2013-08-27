#!/usr/bin/env bash
#
# Vagrant Provisionner : Create Laravel project
#
# @author:  Thierry 'Akarun' Lagasse
# @since:   August 2013
#
# =============================================================================

function echo_success { echo -ne "\033[60G\033[0;39m[   \033[1;32mOK\033[0;39m    ]\n\r"; }
function echo_failure { echo -ne "\033[60G\033[0;39m[ \033[1;31mFAILED\033[0;39m  ]\n\r"; }
function echo_warning { echo -ne "\033[60G\033[0;39m[ \033[1;33mWARNING\033[0;39m ]\n\r"; }
function echo_exists  { echo -ne "\033[60G\033[0;39m[   \033[1;34mDONE\033[0;39m  ]\n\r"; }

echo "================================================================================"
pushd /home/vagrant
[ -d www ] || mkdir www

# =============================================================================

echo -en "\nInstall Laravel sources"

if [ ! -f www/artisan ]; then
    composer create-project -q --no-progress laravel/laravel www
else
    echo_exists
    echo -en "\n\tSources already pressent !"
fi

# =============================================================================

if [ ! -f /home/vagrant/mysql_pass ]; then
    echo -en "\n\tMySQL Pass not found"
    echo_failure; exit 1
fi

echo -ne "\n\tCreating BDD Admin"

MYSQL_PASS=$(cat /home/vagrant/mysql_pass)
mysql -u'root' -p$MYSQL_PASS <<EOF
CREATE USER 'admin'@'localhost' IDENTIFIED BY '$MYSQL_PASS';
GRANT ALL ON *.* TO 'admin'@'localhost'; 
FLUSH PRIVILEGES;
EOF

# TODO : Complete the process