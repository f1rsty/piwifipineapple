#!/bin/bash

# Find the rows and columns. Will default to 80x24 if it can not be detected.
screen_size=$(stty size 2>/dev/null || echo 24 80)
rows=$(echo $screen_size | awk '{print $1}')
columns=$(echo $screen_size | awk '{print $2}')

# Divide by two so the dialogs take up half of the screen, which looks nice.
r=$(( rows / 2 ))
c=$(( columns / 2 ))
# Unless the screen is tiny
r=$(( r < 20 ? 20 : r ))
c=$(( c < 70 ? 70 : c ))

# Run SUDO commands
export SUDO="sudo"

# Dependant applications
PKG_MANAGER="apt-get"
PKG_CACHE="/var/lib/apt/lists/"
UPDATE_PKG_CACHE="${PKG_MANAGER} update"
PKG_INSTALL="${PKG_MANAGER} --yes --no-install-recommends install"
PKG_COUNT="${PKG_MANAGER} -s -o Debug::NoLocking=true upgrade | grep -c ^Inst || true"
DEP_APPS=( dnsmasq hostapd php7.0 apache2 )

# Variables for storing messages so we can later count length if necessary
CHECK_ROOT="Sorry you are not root. Please type: sudo bash piwifipineapple.sh"
WELCOME_MESSAGE="Welcome! This is an automated installer for setting up the Pi as a rogue access point. Please see https://github.com/f1rsty/piwifipineapple for full documentation"
INSTALL_MESSAGE="This is the final prompt before installation begins. Are you sure you would like to continue?"
REBOOT_MESSAGE="It looks like the installation has completed successfully. In order for you to use the PI as an access point you must reboot. Would you like to reboot now?"
FAIL_MESSAGE="It looks like the installation did not complete successfully. Please check the error messages."

print_intro()
{
        whiptail --title "Pi Wifi Pineapple" --msgbox "$WELCOME_MESSAGE" ${r} ${c}
        whiptail --title "Begin Installer" --yesno "$INSTALL_MESSAGE" ${r} ${c}
}

get_ssid()
{
	SSID="$1"
	while [ -z "$SSID" ]; do
		SSID=$(whiptail --title "SSID" --backtitle "Configure Fake SSID" --inputbox "Please enter SSID" ${r} ${c} 3>&1 1>&2 2>&3)
		if [ $? -ne 0 ]; then
			return 0
		elif [ -z "$SSID" ]; then
			whiptail --title "Invalid SSID" --backtitle "Invalid SSID Entered" --msgbox "SSID cannot be empty. Please try again." ${r} ${c}
		fi
	done
	printf "interface=wlan0\nssid=$SSID\nchannel=1" > /etc/hostapd/hostapd.conf
}

# TODO: Needs work
change_pi_password()
{
	PASS="$1"
	while [ -z "PASS" ]; do
		PASS=$(whiptail --passwordbox "Please enter a password for the pi user" 20 60 3>&1 1>&2 2>&3)
		if [ $? -ne 0]; then
			echo 'pi:$PASS' | chpasswd
			return 0
		elif [ -z "$PASS" ]; then
			whiptail --msgbox "Password cannot be empty. Please try again." 20 50
		fi
	done
}

choose_user()
{
	whiptail --msgbox --backtitle "Parsing Users" -- title "Local Users" "Choose a local user" ${r} ${c}
	NUMUSERS=$(awk -F':' 'BEGIN {count=0} $3>=500 && $3<=60000 { count++ } END{ print count }' /etc/passwd)
	if [ "$NUMUSERS" -eq 0 ]
	then
		if ADDUSER=$(whiptail --title "Add A User" --inputbox "No non-root user account was found. Please type a new username." ${r} ${c} 3>&1 1>&2 2>&3)
		then
			PASSWORD=$(whiptail  --title "password dialog" --passwordbox "Please enter the new user password" ${r} ${c} 3>&1 1>&2 2>&3)
			CRYPT=$(perl -e 'printf("%s\n", crypt($ARGV[0], "password"))' "${PASSWORD}")
			useradd -m -p "${CRYPT}" -s /bin/bash "${ADDUSER}"
			if [[ $? = 0 ]]; then
				whiptail --title "Success" --msgbox "User successfully added" ${r} ${c}
				((NUMUSERS+=1))
			else
				exit 1
			fi
		else
			exit 1
		fi
	fi
	AVAILABLEUSERS=$(awk -F':' '$3>=500 && $3<=60000 {print $1}' /etc/passwd)
	local USERARRAY=()
	local FIRSTLOOP=1
	while read -r line
	do
		mode="OFF"
		if [[ $FIRSTLOOP -eq 1 ]]; then
			FIRSTLOOP=0
			mode="ON"
		fi
		USERARRAY+=("${line}" "" "${mode}")
	done <<< "${AVAILABLEUSERS}"
}

update()
{
	{
	COUNTER=1
	while read -r line; do
        	COUNTER=$(( $COUNTER + 1 ))
        	echo $COUNTER
	done < <(apt-get update -y && apt-get upgrade -y)
	} | whiptail --title "Progress" --gauge "Please wait while updating repos" 6 ${c} 0
}

update_package_cache()
{
	timestamp=$(stat -c %Y ${PKG_CACHE})
	timestampAsDate=$(date -d @"${timestamp}" "+%b %e")
	today=$(date "+%b %e")

	if [ ! "${today}" == "${timestampAsDate}" ]; then
		update
	fi
}

package_check_install()
{
	dpkg-query -W -f='${Status}' "${1}" 2>/dev/null | grep -c "ok installed" || ${PKG_INSTALL} "${1}"
}

notify_package_updates_available()
{
	updatesToInstall=$(eval "${PKG_COUNT}")
	if [[ ${updatesToInstall} -eq "0" ]]; then
		return 0;
	else
		update
  	fi
}

install_dependent_packages()
{
	declare -a argArray1=("${!1}")

	if command -v debconf-apt-progress &> /dev/null; then
		$SUDO debconf-apt-progress -- ${PKG_INSTALL} "${argArray1[@]}"
	else
		for i in "${argArray1[@]}"; do
		echo -n ":::    Checking for $i..."
		$SUDO package_check_install "${i}" &> /dev/null
		echo " installed!"
		done
	fi
}

enable_startup()
{
	update-rc.d lighttpd defaults
	update-rc.d hostapd defaults
	update-rc.d dnsmasq defaults
}

generate_confs()
{
	get_ssid
	sed -i 's/^\(DAEMON\_CONF=\).*$/\1\/etc\/hostapd\/hostapd\.conf/' /etc/init.d/hostapd
	mv /etc/default/hostapd /etc/default/hostapd.bak
	printf 'DAEMON_OPTS="-t -d -K -f /var/log/hostapd.log"' > /etc/default/hostapd
	printf "address=/#/172.16.1.1\ninterface=wlan0\ndhcp-range=wlan0,172.16.1.2,172.16.1.254,12h" > /etc/dnsmasq.conf
        printf "interface wlan0\nstatic ip_address=172.16.1.1/24\nstatic domain_name_servers=127.0.0.1" >> /etc/dhcpcd.conf
	echo "sudo ifconfig wlan0 hw ether 02:ab:cd:ef:12:30" >> /home/pi/.bashrc;
}

setup_apache2()
{
	# Directory to store the SSL Certificates / Key
	mkdir /etc/apache2/ssl/key
	mkdir /etc/apache2/ssl/cert
	chmod 777 /var/www/html
	rm /var/www/html/index.html
        openssl req -x509 -nodes -days 1095 -newkey rsa:2048 -out /etc/apache2/ssl/cert/cert.pem -keyout /etc/apache2/ssl/key/cert.key -subj "/C=/ST=/L=/O=/OU=/CN=*"
        a2enmod ssl
	ln -s /etc/apache2/sites-available/default-ssl.conf /etc/apache2/sites-enabled/000-default-ssl.conf
	mv ./submit.php /var/www/html/submit.php
        mv ./index.php /var/www/html/index.php
        mv ./000-default-ssl.conf /etc/apache2/sites-available/000-default-ssl.conf
}

reboot_screen()
{
	if (success -eq 0); then
		whiptail --title "Successful Installation" --yesno "$REBOOT_MESSAGE" ${r} ${c}
	else
		whoptail --title "Failed Installation" --msg "$FAIL_MESSAGE" ${r} ${c}
	fi
}

# Main Script

# Check if root
if [ "$(whoami)" != "root" ]; then
        whiptail --msgbox "$CHECK_ROOT" 10 ${#CHECK_ROOT}
	clear;
        exit;
fi

# Print intro, proceed with installation
if (print_intro -eq 0); then
	update_package_cache
	notify_package_updates_available
	install_dependent_packages DEP_APPS[@]
	enable_startup
	generate_confs
	setup_apache2
else
	exit 1
fi
