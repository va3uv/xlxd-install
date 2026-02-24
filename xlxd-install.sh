###############################################################################################################
#!/bin/bash
#
# Ramesh Dhami, VA3UV - Nov 30, 2025
# Version 1.0 - 2026.02.13 - Clearn-up and added section to check php version and auto-populate the
#                            Nginx default file to allow the dashboard to start without causing a php error
#
# Huge credit to N5AMD and Andy Taylor, MW0MWZ
#
# xlxd RE-INSTALL script
# Tested on Ubuntu 24.04 LTS and Debian 12 Operating Systems
#
# Script maybe used to restore an existing XLX installation, or for a net new install.
# 
# If you are installing a backup...
#
# Place the following files in the /tmp folder...
#
# config.inc.php from your /var/www/html/dashboard/pgs folder
# 
# callinghome.php from wherever your previous install saved this (in my case /callhome)
#
###############################################################################################################

#/usr/bin/env bash

# Install dependencies

apt update
apt -y upgrade --fix-missing --fix-broken


apt -y install build-essential git nginx php-fpm



# Get IP address for the system script

IPADDR=$(hostname -I | awk '{print $1}')

# Ask what XLX number will be assigned to this reflector

read -p "Please enter the 3 digit XLX number, numerical value only -->  " XLXSUFFIX

XLXID=XLX$XLXSUFFIX

cd /

#git clone https://github.com/LX3JL/xlxd.git

git clone https://github.com/MW0MWZ/xlxd.git

cd /xlxd/src

make clean
make -j 1

strip xlxd

make install


cp xlxd /usr/local/bin/xlxd

cd /xlxd

cp -r dashboard1 /var/www/html/dashboard

if [ -f "/tmp/config.inc.php" ]; then

   cp /tmp/config.inc.php /var/www/html/dashboard/pgs/config.inc.php

else

   echo "config.inc.php backup not found in /tmp .... disregarding / using stock template"

fi   

# Get the php major / minor version so we can enter it into the Nginx default file

PHP_MAJOR_MINOR_CUT=$(php -v | head -n 1 | cut -d' ' -f2 | cut -f1-2 -d'.')
# echo "Major.Minor version (cut): $PHP_MAJOR_MINOR_CUT"


cd /root/xlxd-install

mv -f default /etc/nginx/sites-enabled/default

sed -i "s/server_name 172.26.9.165/server_name $IPADDR/g" /etc/nginx/sites-enabled/default

sed -i "s|fastcgi_pass unix:/run/php/php8.3-fpm.sock|fastcgi_pass unix:/run/php/php$PHP_MAJOR_MINOR_CUT-fpm.sock|g" /etc/nginx/sites-enabled/default


mkdir -p /callhome
chmod 777 /callhome

echo ""

if [ -f "/tmp/callinghome.php" ]; then

   cp /tmp/callinghome.php /callhome/callinghome.php
   
else
   
   echo "callinghome.php file not found in /tmp.... disregarding"

fi   


# create the unit file - thanks Andy for the instructions on this :)

cat << EOF >> /etc/systemd/system/xlxd.service
[Unit]
Description=$XLXID Service
Requires=network.target
After=syslog.target network.target

[Service]
User=root
Group=root
Type=forking
StandardOutput=journal
StandardError=journal
ExecStart=/bin/bash -c "/usr/local/bin/xlxd $XLXID $IPADDR 127.0.0.1"
ExecStartPost=/bin/bash -c "pgrep xlxd > /var/log/xlxd.pid"
ExecStopPost=/bin/bash -c "rm -rf /var/log/xlxd.pid"
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF



chmod 644 /etc/systemd/system/xlxd.service

systemctl daemon-reload

systemctl enable xlxd.service

systemctl restart xlxd.service

systemctl enable nginx.service

systemctl restart nginx.service

exit


