#!/usr/bin/env bash
#
# Vagrant Provisionner : Create Laravel project
#
# @author:  Thierry 'Akarun' Lagasse
# @since:   August 2013
#
# =============================================================================

function echo_success { echo -ne "$1\033[60G\033[0;39m[   \033[1;32mOK\033[0;39m    ]\n"; }
function echo_failure { echo -ne "$1\033[60G\033[0;39m[ \033[1;31mFAILED\033[0;39m  ]\n"; }
function echo_warning { echo -ne "$1\033[60G\033[0;39m[ \033[1;33mWARNING\033[0;39m ]\n"; }
function echo_exists  { echo -ne "$1\033[60G\033[0;39m[   \033[1;34mDONE\033[0;39m  ]\n"; }

# =============================================================================
printf '%0.1s' "-"{1..80}

pushd /vagrant
if [ -f www/artisan ]; then
    echo_exists "\n\tThe sources seem to already be present !"
    exit 0
fi

# =============================================================================

PROJECT_NAME='laravel'
[ -e $1 ] && PROJECT_NAME='$1'

echo -en "Creating project folder $1/www"
[ -d www ] && echo_exists || (mkdir www && echo_success || echo_failure)

# =============================================================================

echo -en "Install Laravel sources"
composer create-project -q --no-progress laravel/laravel www
[ $? == 0 ] && echo_success || echo_failure

pushd ./www
php artisan key:generate

# =============================================================================

echo -e "\t- Creating Vhost"
cat > /etc/nginx/sites-available/default <<EOL
server {
    listen 80;
    listen 443 ssl;

    server_name localhost;
    
    root        /home/vagrant/www/public;
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

echo -e "\t- Restarting NginX"
service nginx restart

# =============================================================================

echo -e "\t- Cleaning sources"

rm -Rf .gitattributes license.txt CONTRIBUTING.md readme.md public/packages
cat > .gitignore <<EOL
*.sublime*
logs
storage/(sessions|views|logs|database|cache|work)/*
laravel/test/storage/(sessions|views|logs|cache)/*
EOL

if [ -n $(which git) ]; then
    echo -e "\t- GIT init and branching"
    git init && git add . && git commit -q -m "Initial commit"

    git branch testing
    git branch develop
fi

# =============================================================================

if [ ! -f /home/vagrant/mysql_pass ]; then
    echo_failure "\tMySQL Pass not found" ; exit 1
fi

echo -e "\t- Creating database"
MYSQL_PASS=$(cat /home/vagrant/mysql_pass)

#mysql -u'root' -p$MYSQL_PASS -s -e "SHOW DATABASES;" | grep laravel &> /dev/null ; echo $?

mysql -u'root' -p$MYSQL_PASS <<EOF
CREATE USER 'admin'@'localhost' IDENTIFIED BY '$MYSQL_PASS';
GRANT ALL ON *.* TO 'admin'@'localhost'; 
FLUSH PRIVILEGES;
EOF

mysql -u'root' -p$MYSQL_PASS <<EOF
CREATE SCHEMA \`${PROJECT_NAME}\` DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci; 
EOF

cat > app/config/database.php <<EOL
<?php
return array(
    'fetch' => PDO::FETCH_CLASS,
    'default' => 'mysql',
    'connections' => array(
        'mysql' => array(
            'driver'   => 'mysql',
            'host'     => 'localhost',
            'database' => '${PROJECT_NAME}',
            'username' => 'admin',
            'password' => '${MYSQL_PASS}',
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
EOL

php artisan migrate:install
php artisan migrate:make creation

# =============================================================================

cat > $(basename `pwd`).sublime-project <<EOL
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
EOL

# =============================================================================

echo_success
echo -en "\n\tDONE !\n"