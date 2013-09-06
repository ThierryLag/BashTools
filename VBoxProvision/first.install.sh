#!/bin/bash
#
# VM and Package install
#
# @author:  Thierry 'Akarun' Lagasse
# @since:   August 2013
#
# =============================================================================

function echo_success { echo -ne "$1\033[60G\033[0;39m[   \033[1;32mOK\033[0;39m    ]\n"; }
function echo_failure { echo -ne "$1\033[60G\033[0;39m[ \033[1;31mFAILED\033[0;39m  ]\n"; }
function echo_warning { echo -ne "$1\033[60G\033[0;39m[ \033[1;33mWARNING\033[0;39m ]\n"; }
function echo_done    { echo -ne "$1\033[60G\033[0;39m[   \033[1;34mDONE\033[0;39m  ]\n"; }

# =============================================================================
printf '%0.1s' "-"{1..80}

# Must be root...
[[ $EUID -ne 0 ]] && ( echo_failure 'You must be ROOT !' ; exit 1 )

# Then for a real root...
if [ "root" eq $(who am i | awk '{print $1}') ]; then
	test $(which sudo) || apt-get install -yq sudo

	echo -e "\nEnter user need added to SUDO  : " ; read USER_NAME
	[ -z $USER_NAME ] && usermod -G sudo $USER_NAME

	echo_done "So now restart this script from 'SUDO' account"
	exit 0
fi

# Otherwise, your are just "sudo"
USER_NAME=$(who am i | awk '{print $1}')
USER_HOME=$(eval echo ~$USER_NAME)
USER_GROUP=$(id -g -nr $USER_NAME)

# =============================================================================
# Update packages (if older than ...)
TIME_UPDATE=$(( $(date +%s) - $(stat -c %Y /var/lib/apt/periodic/update-success-stamp) )); 

if [[ $TIME_UPDATE -gt 3600 ]]; then
	apt-get -yq update && apt-get -yq upgrade && apt-get -yq dist-upgrade
fi

# =============================================================================

echo -en "Installing VBox Guest Additions"
apt-get install -yq dkms build-essential linux-headers-generic linux-headers-$(uname -r)
if ( $? ); then echo_failure; else echo_success; fi

mount /dev/cdrom /media/cdrom && /media/cdrom/VBoxLinuxAdditions.run
if ( $? ); then echo_failure; else echo_success; fi

# =============================================================================

echo -en "Configuring network interfaces"
pushd /root
mkdir backups
cp /etc/network/interfaces /root/backups
tee /etc/network/interfaces <<-EOF
	auto lo
	iface lo inet loopback

	allow-hotplug eth0
	iface eth0 inet dhcp

	auto eth1
	iface eth1 inet static
	    address 10.0.0.6
	    netmask 255.0.0.0
	    network 10.0.0.0
EOF

/etc/init.d/networking restart && echo_success || echo_failure

# =============================================================================

echo -en "Tools - Install"
test $(which vim) || apt-get install -yq vim
sudo update-alternatives --set editor /usr/bin/vim.basic

test $(which apg) || apt-get install -yq apg
test $(which zip) || apt-get install -yq zip unzip
echo_done

# =============================================================================

echo -en "Open SSH"

apt-get -yq install ssh
sed -e "/^Port/s/22/22000/" -i /etc/ssh/sshd_config
sed -e "/^PermitRootLogin/s/yes/no/" -i /etc/ssh/sshd_config
sed -e "/^PubkeyAuthentication/s/no/yes/" -i /etc/ssh/sshd_config
sed -e "/pam_motd/s/^/# /" -i /etc/pam.d/sshd
sed -e "/PrintMotd/s/yes/no/" -i /etc/ssh/sshd_config

service ssh restart && echo_success || echo_failure


# =============================================================================

echo -en "Prompt and aliases"
grep -q 'alias duh' /root/.aliases || tee -a /root/.aliases <<EOF
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

cp -f /root/.aliases $USER_HOME && chown $USER_NAME:$USER_GROUP $USER_HOME/.aliases

grep -q '.aliases' $USER_HOME/.bashrc || tee -a $USER_HOME/.bashrc <<EOF
source $USER_HOME/.aliases
EOF

echo_done

# =============================================================================

echo -en "Add locales"
sed -e "s/^# fr_BE/fr_BE/g" -i /etc/locale.gen && sudo /usr/sbin/locale-gen
update-locale LANG=fr_BE.UTF-8
echo_done

# =============================================================================

echo -en "MySQL - Install"

# Create password
MYSQL_ROOT='/root/mysql_pass'
if [ -f $MYSQL_ROOT ]; then
	MYSQL_PASS=$(cat $MYSQL_ROOT)
else
	MYSQL_PASS=$(apg -q -a  0 -n 1 -m 11 -M NCL)
fi

# Install mysql
if [ -z $(which mysql) ]; then
	echo "mysql-server mysql-server/root_password password $MYSQL_PASS" | debconf-set-selections
	echo "mysql-server mysql-server/root_password_again password $MYSQL_PASS" | debconf-set-selections 

	apt-get install -yq mysql-client mysql-server

	if ( $? ); then echo_failure; else echo_success; fi
	echo "$MYSQL_PASS" > $MYSQL_ROOT
else
	echo_done
fi

# Create admin account
echo -e "\nEnter password for your mysql account (leave blank to skip) : " ; read MYSQL_USER_PASS
if [ $MYSQL_USER_PASS ]; then
	echo -en "\t- Create mysql user account"
	mysql -u'root' -p$MYSQL_PASS <<-EOF
	CREATE USER '$USER_NAME'@'localhost' IDENTIFIED BY '$MYSQL_USER_PASS';
	GRANT ALL ON *.* TO '$USER_NAME'@'localhost'; 
	FLUSH PRIVILEGES;
	EOF

	mysql -u"$USER_NAME" -p -q -e ';' 2> /dev/null && echo_success || echo_failure
fi

# =============================================================================

echo -en "NginX - Install"

if [ -f /etc/nginx/nginx.conf ]; then
	apt-get install -yq nginx
	#sed -i 's/user www-data/user vagrant/' /etc/nginx/nginx.conf

	service nginx restart
	if ( $? ); then echo_failure; else echo_success; fi
fi

# -----------------------------------------------------------------------------

echo -en "PHP - Install"

if [ -z $(which php) ]; then
	apt-get install -yq php5-fpm php5-cli php5-common php5-mysql php5-gd php5-mcrypt
	if ( $? ); then echo_failure; else echo_success; fi
fi

# =============================================================================

echo -en "Install Composer"

if [ -z $(which composer) ]; then
	curl -s https://getcomposer.org/installer | php
	mv composer.phar /usr/local/bin/composer
	if [ -z $(which composer) ]; then echo_failure; else echo_success; fi
fi

# =============================================================================

echo -en "Cleaning"

sudo apt-get purge -y xinetd portmap fuse-utils libfuse2 libntfs10
sudo apt-get autoremove -yq && sudo apt-get clean -yq

