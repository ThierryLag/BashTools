#!/bin/bash
#
# Create new laravel project
#
# @author:  Thierry 'Akarun' Lagasse
# @since:   August 2013
#
# =============================================================================
# You can chnage these default variables according your configuration
DEFAULT_PROJECTPATH=`pwd`
DEFAULT_VHOST="${HOME}/sites/.vhosts"

# You can pass the "projectname" as the first args
DEFAULT_PROJECTNAME="laravel"
[ -n $1 ] && DEFAULT_PROJECTNAME='$1'

# No need to change these variables, the script will ask you a specific entry for each.
MYSQL_ADMIN=$(who am i | awk '{print $1}')

DEFAULT_MYSQLBASE="${DEFAULT_PROJECTNAME}"
DEFAULT_MYSQLUSER="${DEFAULT_PROJECTNAME}admin"
DEFAULT_MYSQLPASS="$(apg -q -a  0 -n 1 -m 11 -M NCL)"

# =============================================================================

function echo_success { echo -ne "$1\033[60G\033[0;39m[   \033[1;32mOK\033[0;39m    ]\n"; }
function echo_failure { echo -ne "$1\033[60G\033[0;39m[ \033[1;31mFAILED\033[0;39m  ]\n"; }
function echo_warning { echo -ne "$1\033[60G\033[0;39m[ \033[1;33mWARNING\033[0;39m ]\n"; }
function echo_done    { echo -ne "$1\033[60G\033[0;39m[   \033[1;34mDONE\033[0;39m  ]\n"; }

# =============================================================================
printf '%0.1s' "-"{1..80}

while [ ! -d $PROJECTPATH ]
	echo -e "Provide the directory that contains projects [$DEFAULT_PROJECTPATH] : " ; read PROJECTPATH
	[ -z $PROJECTPATH ] && PROJECTPATH=$DEFAULT_PROJECTPATH
done 

if [ -n $1 ]; then
	echo -e "\nEnter the project name [$DEFAULT_PROJECTNAME] : " ; read PROJECTNAME
	[ -z $PROJECTNAME ] && PROJECTNAME=$DEFAULT_PROJECTNAME
fi

DEFAULT_DOMAIN="${PROJECTNAME}.$(hostname)"
echo -e "\nEnter the domain name [$DEFAULT_DOMAIN] : " ; read DOMAIN
[ -z $DOMAIN ] && DOMAIN=$DEFAULT_DOMAIN

# -----------------------------------------------------------------------------

echo -e "\nEnter MySQL database name [$DEFAULT_MYSQLBASE] or [none] : " ; read MYSQLBASE
[ -z $MYSQLBASE ] && MYSQLBASE=$DEFAULT_MYSQLBASE

if [[ 'none' -ne $MYSQLBASE ]]; then
	echo -e "\nEnter mysql user which access to $MYSQLBASE [$DEFAULT_MYSQLUSER] : " ; read MYSQLUSER
	[ -z $MYSQLUSER ] && MYSQLUSER=$DEFAULT_MYSQLUSER

	echo -e "\nEnter password for this user [$DEFAULT_MYSQLPASS] : " ; read MYSQLPASS
	[ -z $MYSQLPASS ] && MYSQLPASS=$DEFAULT_MYSQLPASS
fi

# =============================================================================
#
#   Laravel Project (create empty project)
#
echo -e "Creating Laravel project \"$PROJECTNAME\""
pushd $PROJECTPATH
composer create-project -q --no-progress laravel/laravel $PROJECTNAME
if [ $? -ne 0 ]; then
	echo_failure
	echo -e "Composer was unable to get sources in : $PROJECTPATH/$PROJECTNAME"
fi

echo_success
pushd $PROJECTNAME

# =============================================================================
#
#   Laravel configuration
#
echo -e "\t- Creating application key"
php artisan key:generate && echo_success || echo_failure

# =============================================================================
#
#   Virtual Host (NginX)
#
if [ ! -d $DEFAULT_VHOST ]; then
	echo -e "\nEnter path where store the vHost [$PROJECTPATH] : " ; read DEFAULT_VHOST
	[ -z $DEFAULT_VHOST ] && DEFAULT_VHOST=$PROJECTPATH
fi

echo -e "\t- Creating Vhost"
cat > $DEFAULT_VHOST/$PROJECTNAME.conf <<EOL
server {
	listen 80;
	#listen 443 ssl;

	server_name ${DOMAIN};
	
	root        ${PROJECTPATH}/${PROJECTNAME}/public;
	index       index.html index.htm index.php;

	location / {
		autoindex on;
	}

	location ~ \.php$ {
		fastcgi_split_path_info ^(.+\.php)(/.+)$;

		fastcgi_pass    unix:/var/run/php5-fpm.sock;
		fastcgi_index  index.php;
		fastcgi_param  SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
		include fastcgi_params;
	}
}
EOL
echo_done

echo -e "\t- Restarting NginX"
service nginx restart && echo_success || echo_failure

# =============================================================================
#
#   GIT
#
echo -e "\t- Prepare GIT configuration"

rm -Rf .gitattributes license.txt CONTRIBUTING.md readme.md public/packages
cat > .gitignore <<EOL
*.sublime*
logs
storage/(sessions|views|logs|database|cache|work)/*
laravel/test/storage/(sessions|views|logs|cache)/*
EOL
echo_done

if [ -n $(which git) ]; then
	echo -e "\t- GIT init"
	git init && git add . && git commit -q -m "Initial commit"

	if [ $? -ne 0 ]; then
		echo_failure
	else
		echo_success

		echo -e "\t- GIT branching"
		git branch testing && git branch develop && echo_success || echo_failure
	fi
fi

# =============================================================================
#
#   MySQL
#
if [[ 'none' -ne $MYSQLBASE ]]; then
	if [ -z $(mysql -u$MYSQLUSER -p$MYSQLPASS -q -Bse "show database like '$MYSQLBASE';") ]; then

		echo -e "\nEnter your '$MYSQL_ADMIN' password  : " ; read MYSQL_ADMINPASS
		while ! mysql -u$MYSQL_ADMIN -p$MYSQL_ADMINPASS  -e ";" ; do
			read -p "Can't connect, please retry: " MYSQL_ADMINPASS
		done

		echo -en "\t- Creating Database"
		mysql -u$MYSQL_ADMIN -p$MYSQL_ADMINPASS  <<-EOF
		CREATE SCHEMA \`$MYSQLBASE\` DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
		GRANT ALL PRIVILEGES ON \`$MYSQLBASE\`.* TO '$MYSQLUSER'@localhost IDENTIFIED BY '$MYSQLPASS'; 
		FLUSH PRIVILEGES;
		EOF

		if ( $? ); then echo_failure; else echo_success; fi
	fi

	cat > app/config/database.php <<-EOF
	<?php
	return array(
	    'fetch' => PDO::FETCH_CLASS,
	    'default' => 'mysql',
	    'connections' => array(
	        'mysql' => array(
	            'driver'   => 'mysql',
	            'host'     => 'localhost',
	            'database' => '${MYSQLBASE}',
	            'username' => '${MYSQLUSER}',
	            'password' => '${MYSQLPASS}',
	            'charset'  => 'utf8',
	            'collation' => 'utf8_unicode_ci',
	            'prefix'   => '',
	        )
	    ),
	    'migrations' => 'migrations',
	    'redis' => array(
	        'cluster' => true,
	        'default' => array(
	            'host'     => '127.0.0.1',
	            'port'     => 6379,
	            'database' => 0,
	        ),
	    ),
	);
	EOF

	# Migrations
	php artisan migrate:install
	php artisan migrate:make creation
fi

# =============================================================================
#
#	Sublime Text 2
#
cat > $PROJECTNAME.sublime-project <<EOF
{
    "folders": [
        {
            "path": ".",
            "file_exclude_patterns":[
               "._*",
               "*.sublime*",
               "*.lock"
            ],
            "folder_exclude_patterns": [
                "log",
                "bootstrap",
                "vendor"
            ]
        }
    ],
    "settings":
    {
        "tab_size": 4,
        "use_tab_stops": true
    }
}
EOF

# =============================================================================

printf '%0.1s' "-"{1..80}

# *****************************************************************************
# http://tldp.org/LDP/Bash-Beginners-Guide/html/sect_07_01.html