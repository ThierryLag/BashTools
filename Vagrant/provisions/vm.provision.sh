#!/usr/bin/env bash
#
# Vagrant Provisionner : VM and Package install
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

# =============================================================================

# Update (if older than ...)
TIME_UPDATE=$(( $(date +%s) - $(stat -c %Y /var/lib/apt/periodic/update-success-stamp) )); 

if [[ $TIME_UPDATE -gt 3600 ]]; then
    apt-get -yq update && apt-get -yq upgrade
fi

# Tools
test $(which vim) || apt-get install -yq vim
test $(which apg) || apt-get install -yq apg
test $(which zip) || apt-get install -yq zip unzip

# =============================================================================

# Prompt and aliases
grep -q 'alias duh' /root/.bashrc || sudo tee -a /root/.bashrc <<EOF
# Prompt
export PS1="\n\[\033[1;34m\][\u@\h \#|\W]\n\[$(tput bold)\]↪\[\033[0m\] "

# Use colors
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

alias l='clear; ls -la'
alias duh='du -hs'
alias tree="find . | sed 's/[^/]*\//|   /g;s/| *\([^| ]\)/+--- \1/'"
alias wget="wget -c"
EOF

cp -f /root/.bashrc /home/vagrant/ && chown vagrant: /home/vagrant/.bashrc

# Resolution de prob. de sharing
echo "SELINUX=disabled" >> /etc/selinux/config

# =============================================================================

echo -en "\nInstall MySQL"

if [ -f /home/vagrant/mysql_pass ]; then
    MYSQL_PASS=$(cat mysql_pass)
else
    MYSQL_PASS=$(apg -q -a  0 -n 1 -m 11 -M NCL)
fi

if [ -z $(which mysql) ]; then
    echo "mysql-server mysql-server/root_password password $MYSQL_PASS" | debconf-set-selections
    echo "mysql-server mysql-server/root_password_again password $MYSQL_PASS" | debconf-set-selections 

    apt-get install -yq mysql-client mysql-server

    if ( $? ); then echo_failure; else echo_success; fi
    echo "$MYSQL_PASS" > /home/vagrant/mysql_pass
else
    echo_exists
fi

# =============================================================================

echo -en "\nInstall NginX"

if [ -f /etc/nginx/nginx.conf ]; then
    apt-get install -yq nginx
    sed -i 's/user www-data/user vagrant/' /etc/nginx/nginx.conf

    service nginx restart
    if ( $? ); then echo_failure; else echo_success; fi
else
    echo_exists
fi

# -----------------------------------------------------------------------------

echo -en "\nInstall PHP"

if [ -z $(which php) ]; then
    apt-get install -yq php5-fpm php5-cli php5-common php5-mysql php5-gd php5-mcrypt
    if ( $? ); then echo_failure; else echo_success; fi
else
    echo_exists
fi

# =============================================================================

echo -en "\nInstall Composer"

if [ -z $(which composer) ]; then
    curl -s https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer
    if [ -z $(which composer) ]; then echo_failure; else echo_success; fi
else
    echo_exists
fi


