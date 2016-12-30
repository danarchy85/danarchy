#!/bin/bash
user=$1
domain=$2

echo "Grabbing most recent wp-cli..."
cd /tmp
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x /tmp/wp-cli.phar
php /tmp/wp-cli.phar --info --allow-root
mv -v /tmp/wp-cli.phar /usr/local/bin/wp

echo "Updating  WP plugins on $domain..."
su -l $user -c 'cd ~/$domain/ ; wp plugin update --all && wp theme update --all'

# allow apache access for $user:$user owned domain directory
setfacl -R -m u:apache:rwx /home/sbclp/$domain/
