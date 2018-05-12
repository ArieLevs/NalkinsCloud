#! /bin/bash

function main() {

	echo
	echo '##    ##    ###    ##       ##    ## #### ##    ##  ######'
	echo '###   ##   ## ##   ##       ##   ##   ##  ###   ## ##    ##'
	echo '####  ##  ##   ##  ##       ##  ##    ##  ####  ## ##'
	echo '## ## ## ##     ## ##       #####     ##  ## ## ##  ######'
	echo '##  #### ######### ##       ##  ##    ##  ##  ####       ##'
	echo '##   ### ##     ## ##       ##   ##   ##  ##   ### ##    ##'
	echo '##    ## ##     ## ######## ##    ## #### ##    ##  ######'
	echo
	echo
	echo ' ######  ##        #######  ##     ## ########'
	echo '##    ## ##       ##     ## ##     ## ##     ##'
	echo '##       ##       ##     ## ##     ## ##     ##'
	echo '##       ##       ##     ## ##     ## ##     ##'
	echo '##       ##       ##     ## ##     ## ##     ##'
	echo '##    ## ##       ##     ## ##     ## ##     ##'
	echo ' ######  ########  #######   #######  ########'
	echo

	echo '############################################################'
	echo '              NalkinsCloud Automation Server'
	echo '############################################################'

	echo -e "\n\nReading nalkins.cloud.conf file"
	
	# Check if configuration file exists
	if [ -f $HOME/nalkins.cloud.conf ]; then
		source $HOME/nalkins.cloud.conf
		
		if [ -z "$DOMAIN_NAME" ]; then
			echo -e "${red}Error${nc} DOMAIN_NAME variable was not set"
			return 1;
		fi
		if [ -z "$DB_ROOT_USER" ]; then
			echo -e "${red}Error${nc} DB_ROOT_USER variable was not set"
			return 1;
		fi
		if [ -z "$DB_ROOT_PASS" ]; then
			echo -e "${red}Error${nc} DB_ROOT_PASS variable was not set"
			return 1;
		fi
		if [ -z "$DJANGO_HOST" ]; then
			echo -e "${red}Error${nc} DJANGO_HOST variable was not set"
			return 1;
		fi
		if [ -z "$DB_DJANGO_LOCATION" ]; then
			echo -e "${red}Error${nc} DB_DJANGO_LOCATION variable was not set"
			return 1;
		fi
		if [ -z "$DB_DJANGO_PASS" ]; then
			echo -e "${red}Error${nc} DB_DJANGO_PASS variable was not set"
			return 1;
		fi
		if [ -z "$MOSQUITTO_HOST" ]; then
			echo -e "${red}Error${nc} MOSQUITTO_HOST variable was not set"
			return 1;
		fi
		if [ -z "$DB_MOSQUITTO_LOCATION" ]; then
			echo -e "${red}Error${nc} DB_MOSQUITTO_LOCATION variable was not set"
			return 1;
		fi
		if [ -z "$DB_MOSQUITTO_PASS" ]; then
			echo -e "${red}Error${nc} DB_MOSQUITTO_PASS variable was not set"
			return 1;
		fi
		if [ -z "$MQTT2DB_HOST" ]; then
			echo -e "${red}Error${nc} MQTT2DB_HOST variable was not set"
			return 1;
		fi
		if [ -z "$DB_MQTT2DB_PASS" ]; then
			echo -e "${red}Error${nc} DB_MQTT2DB_PASS variable was not set"
			return 1;
		fi
		if [ -z "$DB_HOMEBRIDGE_PASS" ]; then
			echo -e "${red}Error${nc} DB_HOMEBRIDGE_PASS variable was not set"
			return 1;
		fi
		if [ -z "$MOSQUITTO_BKS_FILE_PASS" ]; then
			echo -e "${red}Error${nc} MOSQUITTO_BKS_FILE_PASS variable was not set"
			return 1;
		fi
	else # Conf file does not exist, exit with error
		echo -e "${red}Error${nc} Cannot read $HOME/nalkins.cloud.conf"
		return 1;
	fi
	
	read -p "Would you like to setup device simulator as well? " -r
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		if [ -z "$DB_DHT_SIMULATE_USER" ]; then
			echo -e "${red}Error${nc} DB_DHT_SIMULATE_USER variable was not set"
			return 1;
		fi
		if [ -z "$DB_DHT_SIMULATE_PASS" ]; then
			echo -e "${red}Error${nc} DB_DHT_SIMULATE_PASS variable was not set"
			return 1;
		fi
		if [ -z "$DB_SWITCH_SIMULATE_USER" ]; then
			echo -e "${red}Error${nc} DB_SWITCH_SIMULATE_USER variable was not set"
			return 1;
		fi
		if [ -z "$DB_SWITCH_SIMULATE_PASS" ]; then
			echo -e "${red}Error${nc} DB_SWITCH_SIMULATE_PASS variable was not set"
			return 1;
		fi
		SETUP_DEVICE_SIMULATORS=false
	else
		SETUP_DEVICE_SIMULATORS=true
		echo Skipping device simulators
	fi
	
	echo 'Domain selected: ' $DOMAIN_NAME

	# Check OS version
	if [ -f /etc/os-release ]; then
		. /etc/os-release
		OS=$NAME
		VER=$VERSION_ID
	else
		# use uname, e.g. "Linux <version>"
		OS=$(uname -s)
		VER=$(uname -r)
	fi
	echo 'Detected OS: ' $OS $VER
	
	#Create users to run the services
	sudo useradd --system mosquitto
	sudo useradd --system homebridge
	sudo useradd --system mqtt2db
		
	if [ "$OS" = "CentOS Linux" ]; then
		sudo yum -y update
		sudo yum -y install vim wget net-tools
		##Extend yum:
		##sudo yum install yum-utils
		
		#Install all dependent libraries
		sudo yum -y install python-devel mysql-devel gcc c-ares-devel libuuid libuuid-devel libxslt libwebsockets-devel docbook-style-xsl epel-release
		sudo yum -y groupinstall 'Development Tools'
	elif [ "$OS" = "Raspbian GNU/Linux" ]; then
		sudo apt-get -y update
		sudo apt-get -y upgrade
		sudo apt-get -y install make libssl-dev uuid-dev
		sudo apt-get -y upgrade openssl
	fi
	
	install_database
	
	if [ "$OS" = "CentOS Linux" ]; then
		install_apache_centos
	elif [ "$OS" = "Raspbian GNU/Linux" ]; then
		install_apache_raspbian
	fi
	
	setup_mosquitto_server
	insert_mosquitto_tables
	mosquitto_auth_plug
	mosquitto_ssl_tls_setup
	mosquitto_server_systemd
	create_bks_file
	#Home bridge will be commited to the repository once mqtt plugin will be integrated
	#Please don't run below two functions as the command you will send from iOS will not reach end devices
	#homebridge_installation
	#homebridge_server_systemd
	mqtt2db_service_systemd
	
	if [ "$SETUP_DEVICE_SIMULATORS=false" = true ]; then
		mqtt_simulators_systemd
	fi
	
	if [ "$OS" = "Raspbian GNU/Linux" ]; then
		#After both servers are running open HomeKit app on IOS and press 'add accessory'
		#If the device fails to find homebridge its a known issue with IPv6
		#do:
		#Check if file already containing the below string
		grep "ipv6.disable=1" /boot/cmdline.txt
		if [ ! $? -eq 0 ]; then #If not found
			sudo echo -e "ipv6.disable=1" | sudo tee -a /boot/cmdline.txt
		fi
		sudo reboot
	fi
}


function install_database() {
	echo Running install_database function
	if [ "$OS" = "CentOS Linux" ]; then
		sudo echo -e '# http://downloads.mariadb.org/mariadb/repositories/\n[mariadb]\nname = mariadb\nbaseurl = http://yum.mariadb.org/10.1/centos7-amd64\ngpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB\ngpgcheck=1' | sudo tee /etc/yum.repos.d/mariadb.repo
		sudo yum -y install mariadb-server
	elif [ "$OS" = "Raspbian GNU/Linux" ]; then
		sudo apt-get -y install mariadb-server
	fi
	
	sudo systemctl start mariadb
	sudo systemctl enable mariadb

	#When prompt for root password just hit ENTER
	#Accept all the security suggestions
	sudo mysql_secure_installation

	#You should now be able to connect to MariaDB server using the just selected password.
	#Connect with the just selected root user and password
		#mysql -u root -p # If error occur on raspbery use with sudo
	
	echo Setting up Databases and DB users
	sudo mysql --user="$DB_ROOT_USER" --password="$DB_ROOT_PASS" --execute="DROP USER IF EXISTS 'django'@'$DJANGO_HOST', 'mosquitto'@'$MOSQUITTO_HOST', 'mqtt2db'@'$MQTT2DB_HOST';"
	sudo mysql --user="$DB_ROOT_USER" --password="$DB_ROOT_PASS" --execute="DROP DATABASE IF EXISTS mosquitto; CREATE DATABASE mosquitto; DROP DATABASE IF EXISTS django_android; CREATE DATABASE django_android;"
	sudo mysql --user="$DB_ROOT_USER" --password="$DB_ROOT_PASS" --execute="CREATE USER IF NOT EXISTS 'django'@'$DJANGO_HOST' IDENTIFIED BY '$DB_DJANGO_PASS'; GRANT ALL PRIVILEGES ON django_android.* TO 'django'@'$DJANGO_HOST'; GRANT ALL PRIVILEGES ON mosquitto.* TO 'django'@'$DJANGO_HOST';"
	sudo mysql --user="$DB_ROOT_USER" --password="$DB_ROOT_PASS" --execute="CREATE USER IF NOT EXISTS 'mosquitto'@'$MOSQUITTO_HOST' IDENTIFIED BY '$DB_MOSQUITTO_PASS'; GRANT ALL PRIVILEGES ON mosquitto.* TO 'mosquitto'@'$MOSQUITTO_HOST';"
	sudo mysql --user="$DB_ROOT_USER" --password="$DB_ROOT_PASS" --execute="CREATE USER IF NOT EXISTS 'mqtt2db'@'$MQTT2DB_HOST' IDENTIFIED BY '$DB_MQTT2DB_PASS'; GRANT ALL PRIVILEGES ON mosquitto.* TO 'mqtt2db'@'$MQTT2DB_HOST'; FLUSH PRIVILEGES;"

	#Create the databases we will be using
	#DROP DATABASE IF EXISTS django_android;
	#CREATE DATABASE django_android;
	#DROP DATABASE IF EXISTS mosquitto;
	#CREATE DATABASE mosquitto;
		
	#Create application users:
	#CREATE USER IF NOT EXISTS 'django'@'$DJANGO_HOST' IDENTIFIED BY '$DB_DJANGO_PASS';
	#GRANT ALL PRIVILEGES ON django_android.* TO 'django'@'$DJANGO_HOST';
	#GRANT ALL PRIVILEGES ON mosquitto.* TO 'django'@'$DJANGO_HOST';
	#CREATE USER IF NOT EXISTS 'mosquitto'@'$MOSQUITTO_HOST' IDENTIFIED BY '$DB_MOSQUITTO_PASS';
	#GRANT ALL PRIVILEGES ON mosquitto.* TO 'mosquitto'@'$MOSQUITTO_HOST';
	#CREATE USER IF NOT EXISTS 'mqtt2db'@'$MQTT2DB_HOST' IDENTIFIED BY '$DB_MQTT2DB_PASS';
	#GRANT ALL PRIVILEGES ON mosquitto.* TO 'mqtt2db'@'$MQTT2DB_HOST';

	#### ONLY FOR TESTING ##### (So you could connect to DB from external app)
	#CREATE USER IF NOT EXISTS '[USER_NAME_HERE]'@'%' IDENTIFIED BY '[PASSWORD_HERE]';
	#GRANT ALL PRIVILEGES ON *.* TO '[USER_NAME_HERE]'@'%';
	##########################

	#FLUSH PRIVILEGES;
	#QUIT;

	####### FOR TESTING ONLY #####
	#sudo firewall-cmd --zone=public --add-port=3306/tcp --permanent
	#sudo firewall-cmd --reload
	############################
}

function install_apache_raspbian() {
	sudo apt-get -y install python3
	sudo apt-get -y install python3-pip apache2 libapache2-mod-wsgi-py3
	sudo apt-get -y install libmariadbclient-dev
	
	#Install Django and additional apps
	sudo pip3 install django
	sudo pip3 install djangorestframework django-oauth-toolkit mysqlclient apscheduler django-ipware
	
	#Function
	setup_nalkinscloud_django_project
	
	cd /var/www/html/django_server
	
	#Append project to database
	sudo python3 manage.py makemigrations
	sudo mysql --user="$DB_ROOT_USER" --password="$DB_ROOT_PASS" --execute="DROP DATABASE django_android; CREATE DATABASE django_android CHARACTER SET utf8;"

	sudo python3 manage.py migrate
	
	############### MANUAL UPDATE ##############
	#If you get error: "django.db.utils.OperationalError: (1071, 'Specified key was too long; max key length is 767 bytes')"
	#
	#sudo mysql -u root -p
	#DROP DATABASE django_android;
	#CREATE DATABASE django_android CHARACTER SET utf8;
	#QUIT;
	#############################################

	sudo python3 manage.py createsuperuser
	
	sudo python3 manage.py collectstatic

	sudo echo -e "<VirtualHost *:80>\n\tServerName www.$DOMAIN_NAME\n\tServerAlias $DOMAIN_NAME\n\n\tRedirect permanent / https://$DOMAIN_NAME/\n\tDocumentRoot /var/www/html\n\tErrorLog /var/log/apache2/$DOMAIN_NAME/error.log\n\tCustomLog /var/log/apache2/$DOMAIN_NAME/requests.log combined\n</VirtualHost>" | sudo tee /etc/apache2/sites-available/000-default.conf

	##############MANUAL UPDATE##############
	#sudo vim /etc/apache2/sites-available/000-default.conf
	#
	#<VirtualHost *:80>
	#	ServerName www.nalkins.cloud
	#	ServerAlias nalkins.cloud
	#
	#	Redirect permanent / https://nalkins.cloud/
	#	DocumentRoot /var/www/html
	#	ErrorLog /var/log/apache2/nalkins.cloud/error.log
	#	CustomLog /var/log/apache2/nalkins.cloud/requests.log combined
	#</VirtualHost>
	########################################
	
	#Create logs directory:
	sudo mkdir /var/log/apache2/$DOMAIN_NAME
	
	#Enable the Apache SSL module
	sudo a2enmod ssl
		
	sudo a2ensite default-ssl
	sudo a2enmod rewrite
	
	sudo ufw allow http
	sudo ufw allow https
	
	sudo service apache2 reload
	
	echo Setting up SSL certificates
	sudo mkdir /etc/apache2/ssl
	
	#request new certificate and sign it
	sudo openssl req -subj "/C=IL/L=Tel-Aviv/O=$DOMAIN_NAME/CN=$DOMAIN_NAME" -x509 -nodes -days 730 -newkey rsa:2048 -keyout /etc/apache2/ssl/$DOMAIN_NAME.key -out /etc/apache2/ssl/$DOMAIN_NAME.selfsigned.crt
	
	#create a strong Diffie-Hellman group:
	sudo openssl dhparam -out /etc/apache2/ssl/$DOMAIN_NAME.diffie_hellmanparam.pem 2048
	
	#append the generated file to the end of our self-signed certificate:
	sudo cat /etc/apache2/ssl/$DOMAIN_NAME.diffie_hellmanparam.pem | sudo tee -a /etc/apache2/ssl/$DOMAIN_NAME.selfsigned.crt
	
	#protect private key and certificate
	sudo chmod 600 /etc/apache2/ssl/*
	
	#copy certificate file to home directory, so it can be easally copied later
	sudo cp /etc/apache2/ssl/$DOMAIN_NAME.selfsigned.crt $HOME/$DOMAIN_NAME.selfsigned.crt
	
	sudo sed -i "s/ServerAdmin webmaster@localhost/ServerAdmin mail@$DOMAIN_NAME\n\t\tServerName $DOMAIN_NAME:443/" /etc/apache2/sites-enabled/default-ssl.conf

	grep "WSGIDaemonProcess" /etc/apache2/sites-enabled/default-ssl.conf
	if [ ! $? -eq 0 ]; then #If not found
		sudo sed -i "s:DocumentRoot /var/www/html:DocumentRoot /var/www/html\n\t\tAlias /static /var/www/html/django_server/static\n\t\t<Directory /var/www/html/static>\n\t\t\tRequire all granted\n\t\t</Directory>\n\n\t\t<Directory /var/www/html/django_server/django_server>\n\t\t\t<Files wsgi.py>\n\t\t\t\tRequire all granted\n\t\t\t</Files>\n\t\t</Directory>\n\n\t\tWSGIDaemonProcess django_server python-path=/var/www/html/django_server\n\t\tWSGIProcessGroup django_server\n\t\tWSGIScriptAlias / /var/www/html/django_server/django_server/wsgi.py\n\n\t\t# Line below is a must for DJANGO OAUTH TOOLKIT to provide tokens\n\t\tWSGIPassAuthorization On:" /etc/apache2/sites-enabled/default-ssl.conf
	fi
	
	sudo sed -i "s:SSLCertificateFile\t/etc/ssl/certs/ssl-cert-snakeoil.pem:SSLCertificateFile /etc/apache2/ssl/$DOMAIN_NAME.selfsigned.crt:" /etc/apache2/sites-enabled/default-ssl.conf
	sudo sed -i "s:SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key:SSLCertificateKeyFile /etc/apache2/ssl/$DOMAIN_NAME.key:" /etc/apache2/sites-enabled/default-ssl.conf
	
	#Check if file already containing the below string
	#
	#sudo a2enmod headers
	#
	#grep "SSLCipherSuite EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH" /etc/apache2/sites-enabled/default-ssl.conf
	#if [ ! $? -eq 0 ]; then #If not found
	#	sudo echo -e "\nSSLCipherSuite EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH\nSSLProtocol All -SSLv2 -SSLv3\nSSLHonorCipherOrder On\n# Disable preloading HSTS for now.  You can use the commented out header line that includes\n# the "preload" directive if you understand the implications.\n#Header always set Strict-Transport-Security 'max-age=63072000; includeSubdomains; preload'\nHeader always set Strict-Transport-Security 'max-age=63072000; includeSubdomains'\nHeader always set X-Frame-Options DENY\nHeader always set X-Content-Type-Options nosniff\n# Requires Apache >= 2.4\nSSLCompression off \nSSLUseStapling on \nSSLStaplingCache 'shmcb:logs/stapling-cache(150000)' \n# Requires Apache >= 2.4.11\n# SSLSessionTickets Off" | sudo tee -a /etc/apache2/sites-enabled/default-ssl.conf
	#else
	#	echo "SSLCipherSuite Already exist in file"
	#fi
		
	########### MANUAL UPDATE ##################
	#sudo vim /etc/apache2/sites-enabled/default-ssl.conf
	#Update after <VirtualHost _default_:443>
	#
	#	ServerAdmin mail@$DOMAIN_NAME
	#	ServerName $DOMAIN_NAME:443
	#	
	#	Alias /static /var/www/html/django_server/static
	#	<Directory /var/www/html/static>
	#		Require all granted
	#	</Directory>
	#
	#	<Directory /var/www/html/django_server/django_server>
	#		<Files wsgi.py>
	#			Require all granted
	#		</Files>
	#	</Directory>
	#
	#	WSGIDaemonProcess django_server python-path=/var/www/html/django_server
	#	WSGIProcessGroup django_server
	#	WSGIScriptAlias / /var/www/html/django_server/django_server/wsgi.py
	#
	#	# Line below is a must for DJANGO OAUTH TOOLKIT to provide tokens
	#	WSGIPassAuthorization On
	#	
	#	# Update 'SSLCertificateFile' and 'SSLCertificateKeyFile' lines
	#	SSLCertificateFile /etc/apache2/ssl/$DOMAIN_NAME.selfsigned.crt
	#	SSLCertificateKeyFile /etc/apache2/ssl/$DOMAIN_NAME.key
	#############################################################################
	
	# We need to get apache user permission to write logs inside the project
	sudo chown -R www-data:www-data /var/www/html
	
	###############################################################
	#Block access to /admin, and allow only from local IPs
	#sudo vim /etc/apache2/apache2.conf
	#<Location /admin>
    #    Order deny,allow
    #    Deny from all
    #    Allow from xxx.xxx.xxx.xxx/xx
	#</Location>
	###############################################################
	
	sudo service apache2 restart
	sudo service apache2 reload
	
	sudo apt-get -y install default-libmysqlclient-dev

	#For testing mosquitto install client:
	sudo apt-get -y install mosquitto-clients
	
	# By this point you should able to browse to the server domain name
	# Test by browsing to /admin or /register to see the results
}


function install_apache_centos() {
	echo Running install_apache_centos function
	#Install apache with mod_wsgi
	sudo yum install -y httpd-devel 
	
	sudo service httpd start
	#test
	sudo service httpd status
	
	echo Setting up apache firewall rules
	#In order to access the server we need to open HTTP/HTTPS ports
	sudo firewall-cmd --zone=public --add-port=80/tcp --permanent
	sudo firewall-cmd --zone=public --add-port=443/tcp --permanent
	sudo firewall-cmd --reload
		
	#After ports opened and firewall reloaded
	#Try browsing to the IP address of that instance, you should see the basic apache testing page
	#Lets continue by setting up Django, so it will run under apache, as well as self signed certificates, and restrict SSL access.
		
	echo installing python 3.6
	#install python 3.6:
	sudo yum -y install https://centos7.iuscommunity.org/ius-release.rpm
	sudo yum -y install python36u python36u-devel
	sudo yum -y install python36u-mod_wsgi.x86_64
	
	echo Setting up /etc/httpd/conf.d/
	#Add django_server.conf file in /etc/httpd/conf.d/ 
	sudo echo -e "Alias /static /var/www/html/django_server/static\n<Directory /var/www/html/static>\n\tRequire all granted\n</Directory>\n\n<Directory /var/www/html/django_server/django_server>\n\t<Files wsgi.py>\n\t\tRequire all granted\n\t</Files>\n</Directory>\n\nWSGIDaemonProcess django_server python-path=/var/www/html/django_server\nWSGIProcessGroup django_server\nWSGIScriptAlias / /var/www/html/django_server/django_server/wsgi.py\n\n# Line below is a must for DJANGO OAUTH TOOLKIT to provide tokens\nWSGIPassAuthorization On" | sudo tee /etc/httpd/conf.d/django_server.conf
	
	################# MANUAL WAY TO UPDATE /etc/httpd/conf.d/django_server.conf #########
	#	sudo vim /etc/httpd/conf.d/django_server.conf
	#		
	#Alias /static /var/www/html/django_server/static
	#<Directory /var/www/html/static>
	#	Require all granted
	#</Directory>
	#
	#<Directory /var/www/html/django_server/django_server>
	#	<Files wsgi.py>
	#		Require all granted
	#	</Files>
	#</Directory>
	#
	#WSGIDaemonProcess django_server python-path=/var/www/html/django_server
	#WSGIProcessGroup django_server
	#WSGIScriptAlias / /var/www/html/django_server/django_server/wsgi.py
	#
	## Line below is a must for DJANGO OAUTH TOOLKIT to provide tokens
	#WSGIPassAuthorization On
	#####################################################################################

	##Install audit tool for SELinux error (debugging):
	##	sudo yum install setroubleshoot setools
	
	##Check SELinux boolean permissions:
	##sestatus -b

	#Install policycoreutils-python that contains SEMANAGE, to allow policy to be set up that will allow Apache to read, or read/write area outside of the DocumentRoot.
	sudo yum -y install policycoreutils-python
	
	echo Setting up /etc/httpd/conf/httpd.conf
	#Check if file already containing the below string
	grep "IncludeOptional sites-enabled/*" /etc/httpd/conf/httpd.conf
	if [ ! $? -eq 0 ]; then #If not found
		sudo echo -e "IncludeOptional sites-enabled/*.conf" | sudo tee -a /etc/httpd/conf/httpd.conf
	else
		echo "IncludeOptional sites-enabled/*.conf Already exist in file"
	fi
	
	################# MANUAL UPDATE /etc/httpd/conf/httpd.conf #########
	#sudo vim /etc/httpd/conf/httpd.conf
	#	Add this line to the end of the file:
	#		IncludeOptional sites-enabled/*.conf
	####################################################################
	
	sudo mkdir /etc/httpd/sites-enabled
	sudo mkdir /etc/httpd/sites-available
	
	#configure virual hosts:
	echo Setting up /etc/httpd/sites-available/$DOMAIN_NAME.conf
	#Write bellow to /etc/httpd/sites-available/$DOMAIN_NAME.conf
	sudo echo -e "<VirtualHost *:80>\n\tServerName www.$DOMAIN_NAME\n\tRedirect permanent / https://www.$DOMAIN_NAME/\n\tServerAlias $DOMAIN_NAME\n\tDocumentRoot /var/www/html\n\tErrorLog /var/log/httpd/$DOMAIN_NAME/error.log\n\tCustomLog /var/log/httpd/$DOMAIN_NAME/requests.log combined\n</VirtualHost>" | sudo tee /etc/httpd/sites-available/$DOMAIN_NAME.conf

	################################
	#	sudo vim /etc/httpd/sites-available/nalkins.cloud.conf
	#<VirtualHost *:80>
	#	ServerName www.nalkins.cloud
	#	Redirect permanent / https://www.nalkins.cloud/
	#	ServerAlias nalkins.cloud
	#	DocumentRoot /var/www/html
	#	ErrorLog /var/log/httpd/nalkins.cloud/error.log
	#	CustomLog /var/log/httpd/nalkins.cloud/requests.log combined
	#</VirtualHost>
	################################
		
	sudo ln -s /etc/httpd/sites-available/$DOMAIN_NAME.conf /etc/httpd/sites-enabled/$DOMAIN_NAME.conf
	
	echo Setting up SSL
	
	#Install SSL for apache:
	sudo yum -y install mod_ssl
	
	#create private dir for the certs:
	sudo mkdir /etc/ssl/$DOMAIN_NAME
	sudo chmod 700 /etc/ssl/$DOMAIN_NAME
	
	#Create the certificate:
	sudo openssl req -subj "/C=IL/ST=/L=Tel-Aviv/O=$DOMAIN_NAME/CN=$DOMAIN_NAME" -x509 -nodes -days 730 -newkey rsa:2048 -keyout /etc/ssl/$DOMAIN_NAME/$DOMAIN_NAME.selfsigned.key -out /etc/ssl/certs/$DOMAIN_NAME.selfsigned.crt
	#-keyout: This line tells OpenSSL where to place the generated private key file that we are creating.
	#-out: This tells OpenSSL where to place the certificate that we are creating.
	
	#Fill in relevant details as:
	#	Country Name (2 letter code) [XX]:IL
	#	State or Province Name (full name) []:
	#	Locality Name (eg, city) [Default City]:Tel-Aviv
	#	Organization Name (eg, company) [Default Company Ltd]:nalkins.cloud
	#	Organizational Unit Name (eg, section) []:
	#	Common Name (eg, your name or your servers hostname) []:nalkins.cloud
	#	Email Address []:nalkins.cloud@gmail.com
	
	#create a strong Diffie-Hellman group:
	sudo openssl dhparam -out /etc/ssl/certs/$DOMAIN_NAME.diffie_hellmanparam.pem 2048
	
	#append the generated file to the end of our self-signed certificate:
	sudo cat /etc/ssl/certs/$DOMAIN_NAME.diffie_hellmanparam.pem | sudo tee -a /etc/ssl/certs/$DOMAIN_NAME.selfsigned.crt
	
	echo Setting up /etc/httpd/conf.d/ssl.conf
	
	######### RESTRICT ACCESS TO ADMIN FOR LAN ONLY ############
	#<Location /admin>
	#	Order deny,allow
	#	Deny from all
	#	Allow from xxx.xxx.xxx.xxx/xx
	#</Location>
	###############################################################
	
	sudo sed -i "s/#DocumentRoot/DocumentRoot/" /etc/httpd/conf.d/ssl.conf
	sudo sed -i "s/#ServerName www.example.com:443/ServerName www.$DOMAIN_NAME:443/" /etc/httpd/conf.d/ssl.conf
	sudo sed -i "s/SSLProtocol/#SSLProtocol/" /etc/httpd/conf.d/ssl.conf
	sudo sed -i "s/SSLCipherSuite/#SSLCipherSuite/" /etc/httpd/conf.d/ssl.conf
	sudo sed -i "s:SSLCertificateFile /etc/pki/tls/certs/localhost.crt:SSLCertificateFile /etc/ssl/certs/$DOMAIN_NAME.selfsigned.crt:" /etc/httpd/conf.d/ssl.conf
	sudo sed -i "s:SSLCertificateKeyFile /etc/pki/tls/private/localhost.key:SSLCertificateKeyFile /etc/ssl/$DOMAIN_NAME/$DOMAIN_NAME.selfsigned.key:" /etc/httpd/conf.d/ssl.conf
	
	#Check if file already containing the below string
	grep "SSLCipherSuite EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH" /etc/httpd/conf.d/ssl.conf
	if [ ! $? -eq 0 ]; then #If not found
		sudo echo -e "\nSSLCipherSuite EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH\nSSLProtocol All -SSLv2 -SSLv3\nSSLHonorCipherOrder On\n# Disable preloading HSTS for now.  You can use the commented out header line that includes\n# the "preload" directive if you understand the implications.\n#Header always set Strict-Transport-Security 'max-age=63072000; includeSubdomains; preload'\nHeader always set Strict-Transport-Security 'max-age=63072000; includeSubdomains'\nHeader always set X-Frame-Options DENY\nHeader always set X-Content-Type-Options nosniff\n# Requires Apache >= 2.4\nSSLCompression off \nSSLUseStapling on \nSSLStaplingCache 'shmcb:logs/stapling-cache(150000)' \n# Requires Apache >= 2.4.11\n# SSLSessionTickets Off" | sudo tee -a /etc/httpd/conf.d/ssl.conf
	fi
	
	################# MANUAL WAY TO UPDATE /etc/httpd/conf.d/ssl.conf #########
	#sudo vim /etc/httpd/conf.d/ssl.conf
	#
	#	under # General setup for the virtual host, inherited from global configuration
	#	Uncomment the 'DocumentRoot' line and edit the address in quotes 
	#	Uncomment the 'ServerName' line and replace www.example.com with your domain name or server IP address
	#	So it will look like:
	#		DocumentRoot "/var/www/html"
	#		ServerName www.nalkins.cloud:443
	#	
	#	find the 'SSLProtocol' and 'SSLCipherSuite' lines and comment them out
	#	configuration we be pasting will offer more secure settings
	#	Find the 'SSLCertificateFile' and 'SSLCertificateKeyFile' lines and change them:
	#	SSLCertificateFile /etc/ssl/certs/nalkins.cloud.selfsigned.crt
	#	SSLCertificateKeyFile /etc/ssl/nalkins.cloud/nalkins.cloud.selfsigned.key
	#	
	#	Add below after the </VirtualHost> section (buttom of file)#
	#SSLCipherSuite EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH
	#SSLProtocol All -SSLv2 -SSLv3
	#SSLHonorCipherOrder On
	## Disable preloading HSTS for now.  You can use the commented out header line that includes
	## the "preload" directive if you understand the implications.
	##Header always set Strict-Transport-Security "max-age=63072000; includeSubdomains; preload"
	#Header always set Strict-Transport-Security "max-age=63072000; includeSubdomains"
	#Header always set X-Frame-Options DENY
	#Header always set X-Content-Type-Options nosniff
	## Requires Apache >= 2.4
	#SSLCompression off 
	#SSLUseStapling on 
	#SSLStaplingCache "shmcb:logs/stapling-cache(150000)" 
	## Requires Apache >= 2.4.11
	## SSLSessionTickets Off
	#
	#Save the file!
	#########################################################
	
	#Create logs directory:
	sudo mkdir /var/log/httpd/$DOMAIN_NAME
	
	#Now restart apache:
	sudo service httpd restart
	
	#Apache is now secured, access the instance domain, you shuold see the website is secured, with our just created self-signed cetrificate,
	#You should also get a 404 error: "The requested URL / was not found on this server."
	#That is because we have yet loaded django
	
	#Installing Django
	echo Installing Django
	
	#install pip:
	sudo yum -y install python36u-pip
	
	sudo pip3.6 install django
	#these packages needed are:
	sudo pip3.6 install djangorestframework django-oauth-toolkit mysqlclient apscheduler django-ipware
	
	#Function
	setup_nalkinscloud_django_project
	
	cd /var/www/html/django_server
	#Append project to database
	sudo python3.6 manage.py makemigrations
	sudo python3.6 manage.py migrate
		
	echo Please select new username to use as Superuser for Django Admin
	sudo python3.6 manage.py createsuperuser
	
	sudo python3.6 manage.py collectstatic
	
	echo Setting up permissions and allowing SELinux
	#Allow SElinux to allow apache to write to /var/www/html/django_server/logs
	sudo chcon -R -t httpd_sys_rw_content_t /var/www/html/django_server/logs
	sudo chmod -R 766 /var/www/html/django_server/logs/
	
	sudo chown -R apache:apache /var/www/html
	#Create policy for read only areas that are a part of the application, outside of the DocumentRoot:
	sudo semanage fcontext -a -t httpd_sys_content_t "/var/www/html/django_server"
	#Apply the policy with the restorecon command:
	sudo restorecon -Rv /var/www/html/django_server
	
	#SELinux allow apache execute scripts
	semanage fcontext -a -t httpd_sys_script_exec_t '/var/www/html/django_server/scripts(/.*)?'
	#Apply the policy with the restorecon command:
	restorecon -R -v /var/www/html/django_server/scripts/
	sudo chmod +x /var/www/html/django_server/scripts/*
	
	echo Restaring httpd
	#Run and enable apache server:
	sudo service httpd restart
	sudo systemctl enable httpd.service
	
	################### NOT NEEDED ########################
	#Allow httpd access mysql module
	#	sudo semanage fcontext -a -t httpd_sys_script_exec_t .../lib/python3.6/site-packages/_mysql.cpython-36m-x86_64-linux-gnu.so
	#	sudo restorecon -v .../lib/python3.6/site-packages/_mysql.cpython-36m-x86_64-linux-gnu.so
	#
	#Allow Apache to connect to remote database through SELinux:
	#setsebool -P httpd_can_network_connect_db 1
	#########################################

	#OK So by this point you should have a running web server, that can already serve mobile application
	#Run a test by accessing the domain:
	#	nalkins.cloud/admin	
}


function setup_nalkinscloud_django_project() {

	cd /var/www/html/
	sudo django-admin startproject django_server
	
	cd $HOME
	
	echo Cloning NalkinsCloud-Django
	git clone https://github.com/ArieLevs/NalkinsCloud-Django.git
	
	sudo mv $HOME/NalkinsCloud-Django/* /var/www/html/django_server/
	
	echo Cleanup home dir
	rm -rf $HOME/NalkinsCloud-Django/
	
	grep "from django.conf.urls import include, url" /var/www/html/django_server/django_server/urls.py
	if [ ! $? -eq 0 ]; then #If not found
		sudo sed -i "s/from django.urls import path/from django.urls import path\nfrom django.conf.urls import include, url/" /var/www/html/django_server/django_server/urls.py
	fi

	echo Setting up settings.py
	sudo sed -i "s/DEBUG = True/DEBUG = False/" /var/www/html/django_server/django_server/settings.py
	sudo sed -i "s/ALLOWED_HOSTS = \[\]/ALLOWED_HOSTS = \['$DOMAIN_NAME'\,'www\.$DOMAIN_NAME'\]/" /var/www/html/django_server/django_server/settings.py
	
	#Installed apps
	sudo sed -i "s/'django.contrib.staticfiles',/'django.contrib.staticfiles',\n\n    'oauth2_provider',\n    'rest_framework',/" /var/www/html/django_server/django_server/settings.py
	
	#Tempate dirs
	'DIRS': [os.path.join(BASE_DIR, 'templates')],
	
	#Database setup
	sudo sed -i "s/'ENGINE': 'django.db.backends.sqlite3',/'ENGINE': 'django.db.backends.mysql',/" /var/www/html/django_server/django_server/settings.py
	sudo sed -i "s/'NAME': os.path.join(BASE_DIR, 'db.sqlite3'),/'NAME': 'django_android',\n        'USER': 'django',\n        'PASSWORD': '$DB_DJANGO_PASS',\n        'HOST': '$DB_DJANGO_LOCATION',\n        'PORT': '3306',/" /var/www/html/django_server/django_server/settings.py

	#Check if file already containing the below string
	grep "REST_FRAMEWORK = {" /var/www/html/django_server/django_server/settings.py
	if [ ! $? -eq 0 ]; then #If not found
		sudo echo -e "\nREST_FRAMEWORK = {\n    'DEFAULT_AUTHENTICATION_CLASSES': (\n        'oauth2_provider.contrib.rest_framework.OAuth2Authentication',\n    ),\n    'DEFAULT_PERMISSION_CLASSES': (\n        'rest_framework.permissions.IsAuthenticated',\n    ),\n}\n\nOAUTH2_PROVIDER = {\n    # this is the list of available scopes\n    'SCOPES': {'read': 'Read scope', 'write': 'Write scope', 'groups': 'Access to your groups'}\n}" | sudo tee -a /var/www/html/django_server/django_server/settings.py
	fi
	
	#Check if file already containing the below string
	grep "url(r'^', include('NalkinsCloud.urls'))," /var/www/html/django_server/django_server/urls.py
	if [ ! $? -eq 0 ]; then #If not found
		sudo sed -i "s:path('admin/', admin.site.urls),:path('admin/', admin.site.urls),\n    url(r'^', include('NalkinsCloud.urls')),\n\n    url(r'^', include('oauth2_provider.urls', namespace='oauth2_provider')),:" /var/www/html/django_server/django_server/urls.py
	fi
	
	################## MANUAL UPDATE ###################
	#sudo vim /var/www/html/django_server/django_server/settings.py
	#
	#ONCE ON PRODUCTION CHANGE DEBUG FROM True TO False, 
	#APPEND ""DATABASES"" AS TO PASSWORD SELECTED FOR USER 'django'
	#CONFIGURE ""ALLOWED_HOSTS"" TO MATCH YOU IP / DOMAIN
	#
	#UPDATE MYSQL BACKEND PERMISSIONS
	#DATABASES = {
	#	'default': {
	#		'ENGINE': 'django.db.backends.mysql',
	#		'NAME': 'django_android',
	#		'USER': 'django',
	#		'PASSWORD': '12345678',
	#		'HOST': '192.168.1.50',
	#		'PORT': '3306',
	#	}
	#}
	#
	#
	#INSTALLED_APPS = [
	#	'django.contrib.admin',
	#	'django.contrib.auth',
	#	'django.contrib.contenttypes',
	#	'django.contrib.sessions',
	#	'django.contrib.messages',
	#	'django.contrib.staticfiles',
	#
	#	'oauth2_provider',
	#	'rest_framework',
	#]
	#
	#
	#REST_FRAMEWORK = {
	#	'DEFAULT_AUTHENTICATION_CLASSES': (
	#		'oauth2_provider.contrib.rest_framework.OAuth2Authentication',
	#	),
	#	'DEFAULT_PERMISSION_CLASSES': (
	#		'rest_framework.permissions.IsAuthenticated',
	#	),
	#}
	#
	#OAUTH2_PROVIDER = {
	#	# this is the list of available scopes
	#	'SCOPES': {'read': 'Read scope', 'write': 'Write scope', 'groups': 'Access to your groups'}
	#}
	#
	#
	#
	#### Update urls.py
	#
	#urlpatterns = [
	#	path('admin/', admin.site.urls),
	#	url(r'^', include('NalkinsCloud.urls')),
	#	# OAUTH URLS
	#	url(r'^', include('oauth2_provider.urls', namespace='oauth2_provider')),
	#]
	###################################################
}


function setup_mosquitto_server() {
	echo Running setup_mosquitto_server function
	
	#If Single node installation, do sudo yum install openssl-devel libuuid-devel
	
	cd $HOME
	wget http://mosquitto.org/files/source/mosquitto-1.4.14.tar.gz
	tar xvzf mosquitto-1.4.14.tar.gz
	cd $HOME/mosquitto-1.4.14
	
	echo Configuring $HOME/mosquitto-1.4.14/config.mk
	sudo sed -i "s/WITH_SRV:=yes/WITH_SRV:=no/" $HOME/mosquitto-1.4.14/config.mk
	
	########## MANUAL UPDATE ###########
	#vim config.mk
	#	change WITH_SRV:=yes to WITH_SRV:=no
	####################################
		
	make
	sudo make install
	
	#sudo sed -i "s:/usr/share/xml/docbook/stylesheet/docbook-xsl/manpages/docbook.xsl:/usr/share/sgml/docbook/xsl-stylesheets-1.78.1/manpages/docbook.xsl:" $HOME/mosquitto-1.4.14/man/manpage.xsl # BELOW ISSUE
	
	################### ONLY IF YOU GET ERROR - MANUAL UPDATE ###########################
	#before building mosquitto:
	#	cd man/ in mosquitto folder (the just cloned project)
	#	vim manpage.xsl
	#	and change the third row 
	#	from <xsl:import href="/usr/share/xml/docbook/stylesheet/docbook-xsl/manpages/docbook.xsl"/>
	#	to <xsl:import href="/usr/share/sgml/docbook/xsl-stylesheets-1.78.1/manpages/docbook.xsl"/>
	#####################################################################################
	
	if [ "$OS" = "CentOS Linux" ]; then
		echo Installing paho-mqtt mysqlclient
		sudo pip3.6 install paho-mqtt mysqlclient
	elif [ "$OS" = "Raspbian GNU/Linux" ]; then
		sudo pip3 install paho-mqtt mysqlclient
	fi
	
	#test
	#	mosquitto
	#	mosquitto_pub -d -h localhost -t topic -m payload
	
	if [ "$OS" = "CentOS Linux" ]; then
		
		#****** If you get error 'mosquitto_sub: error while loading shared libraries: libmosquitto.so.1: cannot open shared object file: No such file or directory'
		#fix by:
		sudo echo -e "include /usr/local/lib\n/usr/lib\n/usr/local/lib" | sudo tee -a /etc/ld.so.conf
		########## MANUAL UPDATE ##########
		#sudo vim /etc/ld.so.conf
		#append these 3 lines:
		#	include /usr/local/lib
		#	/usr/lib
		#	/usr/local/lib
		#
		#and save
		####################################
					
		sudo /sbin/ldconfig
		sudo ln -s /usr/local/lib/libmosquitto.so.1 /usr/lib/libmosquitto.so.1
		#******************

		#test again
		#	mosquitto
		#	mosquitto_pub -d -h localhost -t topic -m payload
	fi
	
	#Now we have a working mosquitto server on the instance
	#Configure mosquitto.conf file:
	
	echo Configuring /etc/mosquitto/mosquitto.conf
	sudo cp /etc/mosquitto/mosquitto.conf.example /etc/mosquitto/mosquitto.conf

	sudo echo -e "\nallow_anonymous false\n\nconnection_messages true\nlog_timestamp true\nlog_type all\nlog_dest file /var/log/mosquitto/mosquitto.log\n\nlistener 1883 localhost\nlistener 8883\n\n#cafile /etc/mosquitto/certs/mosquitto_ca.crt\n#keyfile /etc/mosquitto/certs/mosquitto_server.key\n#certfile /etc/mosquitto/certs/mosquitto_server.crt\n#tls_version tlsv1.1\n#use_identity_as_username true\n\nmax_inflight_messages 1\n\n### Auth plug parameters - MYSQL back end ####\nauth_plugin /etc/mosquitto/auth-plug.so\n\nauth_opt_backends mysql\n#auth_opt_redis_host\n#auth_opt_redis_port\nauth_opt_host $DB_MOSQUITTO_LOCATION\nauth_opt_port 3306\nauth_opt_dbname mosquitto\nauth_opt_user mosquitto\nauth_opt_pass $DB_MOSQUITTO_PASS\nauth_opt_userquery SELECT password FROM devices WHERE device_id = '%s'\nauth_opt_superquery SELECT COUNT(*) FROM devices WHERE device_id = '%s' AND super = 1\nauth_opt_aclquery SELECT topic FROM acls WHERE (device_id = '%s') AND (rw >= '%d')\nauth_opt_anonusername AnonymouS\n\nauth_opt_mysql_opt_reconnect true\nauth_opt_mysql_auto_reconnect true\n#### END Auth plug parameters ####\n\n#Allow multiple connections for same client\nuse_username_as_clientid true" | sudo tee /etc/mosquitto/mosquitto.conf

	###################### MANUAL CONFIG ########################
	#	sudo vim /etc/mosquitto/mosquitto.conf
	#	
	#allow_anonymous false
	#
	#connection_messages true
	#log_timestamp true
	#log_type all
	#log_dest file /var/log/mosquitto/mosquitto.log
	#
	#listener 1883 localhost
	#listener 8883
	#
	##cafile /etc/mosquitto/certs/mosquitto_ca.crt
	##keyfile /etc/mosquitto/certs/mosquitto_server.key
	##certfile /etc/mosquitto/certs/mosquitto_server.crt
	##tls_version tlsv1.1
	##use_identity_as_username true
	#
	#max_inflight_messages 1
	#
	#### Auth plug parameters - MYSQL back end ####
	#auth_plugin /etc/mosquitto/auth-plug.so
	#
	#auth_opt_backends mysql
	##auth_opt_redis_host
	##auth_opt_redis_port
	#auth_opt_host $DB_MOSQUITTO_LOCATION
	#auth_opt_port 3306
	#auth_opt_dbname mosquitto
	#auth_opt_user mosquitto
	#auth_opt_pass $DB_MOSQUITTO_PASS
	#auth_opt_userquery SELECT password FROM devices WHERE device_id = '%s'
	#auth_opt_superquery SELECT COUNT(*) FROM devices WHERE device_id = '%s' AND super = 1
	#auth_opt_aclquery SELECT topic FROM acls WHERE (device_id = '%s') AND (rw >= '%d')
	#auth_opt_anonusername AnonymouS
	#
	#auth_opt_mysql_opt_reconnect true
	#auth_opt_mysql_auto_reconnect true
	##### END Auth plug parameters ####
	#
	##Allow multiple connections for same client
	#use_username_as_clientid true
	################################################################################################
	
	#Create the logs directory:
	echo Setting up logs for mosquitto
	sudo mkdir /var/log/mosquitto
	sudo chown -R $USER:$USER /var/log/mosquitto
}


function insert_mosquitto_tables() {
	# PLEASE NOTE - Creating 'customers' in 'mosquitto' DB is possible ONLY AFTER using 'python3.6 manage.py migrate' command (updating DB with mosquitto info)
	# If you want to only install mosquitto server remove row 'FOREIGN KEY (user_id) REFERENCES django_android.auth_user(id)'

	sudo mysql --user="$DB_ROOT_USER" --password="$DB_ROOT_PASS" --database="mosquitto" --execute="DROP TABLE IF EXISTS device_models;\nCREATE TABLE device_models (\nmodel VARCHAR(32) NOT NULL,\ndate_created TIMESTAMP DEFAULT NOW(),\nPRIMARY KEY (model)\n);"
	sudo mysql --user="$DB_ROOT_USER" --password="$DB_ROOT_PASS" --database="mosquitto" --execute="DROP TABLE IF EXISTS device_types;\nCREATE TABLE device_types (\ntype VARCHAR(32) NOT NULL,\ndate_created TIMESTAMP DEFAULT NOW(),\nPRIMARY KEY (type)\n);"
	sudo mysql --user="$DB_ROOT_USER" --password="$DB_ROOT_PASS" --database="mosquitto" --execute="DROP TABLE IF EXISTS customers;\nCREATE TABLE customers (\nuser_id INTEGER NOT NULL,\nemail VARCHAR(32) NOT NULL,\npassword VARCHAR(128) NOT NULL,\nis_active INT(1) NOT NULL DEFAULT 1,\ncountry_id INT(3),\nregistration_ip VARCHAR(15),\nlanguage VARCHAR(2) NOT NULL DEFAULT 'EN',\ndate_created TIMESTAMP DEFAULT NOW(),\nlast_update_date TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,\nlast_login TIMESTAMP,\nlast_login_ip VARCHAR(15),\nPRIMARY KEY (user_id),\nKEY user_id(user_id),\nFOREIGN KEY (user_id) REFERENCES django_android.auth_user(id)\n);\nCREATE UNIQUE INDEX customers_username_idx ON customers (user_id);"
	sudo mysql --user="$DB_ROOT_USER" --password="$DB_ROOT_PASS" --database="mosquitto" --execute="DROP TABLE IF EXISTS devices;\nCREATE TABLE devices (\ndevice_id VARCHAR(32) NOT NULL,\npassword VARCHAR(128) NOT NULL,\nsuper INT(1) NOT NULL DEFAULT 0,\nis_enabled INT(1) NOT NULL DEFAULT 1,\nmodel VARCHAR(32) NOT NULL,\ntype VARCHAR(32) NOT NULL,\ndate_created TIMESTAMP DEFAULT NOW(),\nlast_update_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,\nlast_connection TIMESTAMP,\nlast_connection_ip VARCHAR(15),\nPRIMARY KEY (device_id),\nFOREIGN KEY (type) REFERENCES device_types(type),\nFOREIGN KEY (model) REFERENCES device_models(model)\n);\nCREATE UNIQUE INDEX devices_deviceid_idx ON devices (device_id);"
	sudo mysql --user="$DB_ROOT_USER" --password="$DB_ROOT_PASS" --database="mosquitto" --execute="DROP TABLE IF EXISTS customer_devices;\nCREATE TABLE customer_devices (\nid INTEGER AUTO_INCREMENT,\nuser_id INTEGER NOT NULL,\ndevice_id VARCHAR(32) NOT NULL,\ndevice_name VARCHAR(32) NOT NULL,\ndate_created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,\nPRIMARY KEY (user_id, device_id),\nKEY id(id),\nFOREIGN KEY (user_id) REFERENCES customers(user_id),\nFOREIGN KEY (device_id) REFERENCES devices(device_id)\n);"
	sudo mysql --user="$DB_ROOT_USER" --password="$DB_ROOT_PASS" --database="mosquitto" --execute="DROP TABLE IF EXISTS acls;\nCREATE TABLE acls (\nid INTEGER AUTO_INCREMENT,\ndevice_id VARCHAR(32) NOT NULL,\ntopic VARCHAR(256) NOT NULL,\nrw INTEGER(1) NOT NULL DEFAULT 1,\nis_enabled INT(1) NOT NULL DEFAULT 1,\ndate_created TIMESTAMP DEFAULT NOW(),\nlast_update_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,\nPRIMARY KEY (id),\nFOREIGN KEY (device_id) REFERENCES devices(device_id)\n);\nCREATE UNIQUE INDEX acls_deviceid_idx ON acls (device_id, topic(228));"
	sudo mysql --user="$DB_ROOT_USER" --password="$DB_ROOT_PASS" --database="mosquitto" --execute="DROP TABLE IF EXISTS messages;\nCREATE TABLE messages (\nmessage_id INTEGER AUTO_INCREMENT,\ndevice_id VARCHAR(32) NOT NULL,\ntopic VARCHAR(256) NOT NULL,\nmessage VARCHAR(256) NOT NULL,\nqos INT(1) NOT NULL DEFAULT 1,\ndate_created TIMESTAMP DEFAULT NOW(),\nlast_update_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,\nPRIMARY KEY (message_id),\nFOREIGN KEY (device_id) REFERENCES devices(device_id)\n);\nCREATE UNIQUE INDEX messages_idx ON messages (message_id);"
	
	sudo mysql --user="$DB_ROOT_USER" --password="$DB_ROOT_PASS" --database="mosquitto" --execute="INSERT INTO device_models (model) VALUES ('esp8266'),('service'),('application');"
	sudo mysql --user="$DB_ROOT_USER" --password="$DB_ROOT_PASS" --database="mosquitto" --execute="INSERT INTO device_types (type) VALUES ('dht'), ('switch'), ('magnet'), ('distillery'),('service'),('user');"
	
	echo Hashing passwords
	if [ "$OS" = "CentOS Linux" ]; then
		chmod +x $HOME/generatePBKDF2pass
		HASHED_DB_HOMEBRIDGE_PASS="$(./generatePBKDF2pass -p $DB_HOMEBRIDGE_PASS)"
		HASHED_DB_MQTT2DB_PASS="$(./generatePBKDF2pass -p $DB_MQTT2DB_PASS)"
	elif [ "$OS" = "Raspbian GNU/Linux" ]; then
		chmod +x $HOME/generatePBKDF2passARM
		HASHED_DB_HOMEBRIDGE_PASS="$(./generatePBKDF2passARM -p $DB_HOMEBRIDGE_PASS)"
		HASHED_DB_MQTT2DB_PASS="$(./generatePBKDF2passARM -p $DB_MQTT2DB_PASS)"
	fi
	
	sudo mysql --user="$DB_ROOT_USER" --password="$DB_ROOT_PASS" --database="mosquitto" --execute="INSERT INTO devices (device_id, password, is_enabled, model, type, date_created, last_update_date, last_connection) VALUES ('homebridge', '$HASHED_DB_HOMEBRIDGE_PASS', '1', 'service', 'service',null, null, null);"
	sudo mysql --user="$DB_ROOT_USER" --password="$DB_ROOT_PASS" --database="mosquitto" --execute="INSERT INTO acls (device_id, topic, rw, is_enabled, date_created, last_update_date) VALUES ('homebridge', '#', 2, 1, null, null);"
	sudo mysql --user="$DB_ROOT_USER" --password="$DB_ROOT_PASS" --database="mosquitto" --execute="INSERT INTO devices (device_id, password, is_enabled, model, type, date_created, last_update_date, last_connection) VALUES ('mqtt2db', '$HASHED_DB_MQTT2DB_PASS', '1', 'service', 'service', null, null, null);"
	sudo mysql --user="$DB_ROOT_USER" --password="$DB_ROOT_PASS" --database="mosquitto" --execute="INSERT INTO acls (device_id, topic, rw, is_enabled, date_created, last_update_date) VALUES ('mqtt2db', '#', 2, 1, null, null);"

	echo '#######################################################'
	echo '#Inserting test devices -> "PBKDF2\$sha256\$901\$HoT3s+ntON8LogQ2\$lcAgx8Rhx0RptaKQZWUmi\/hPM1GAidWL" represent pass: 12345678'
	echo '#######################################################'
	sudo mysql --user="$DB_ROOT_USER" --password="$DB_ROOT_PASS" --database="mosquitto" --execute="INSERT INTO devices (device_id, password, is_enabled,  model, type, date_created, last_update_date, last_connection) VALUES ('test_dht_deviceid', 'PBKDF2\$sha256\$901\$HoT3s+ntON8LogQ2\$lcAgx8Rhx0RptaKQZWUmi\/hPM1GAidWL', '1', 'ESP8266', 'dht', null, null, null);"
	sudo mysql --user="$DB_ROOT_USER" --password="$DB_ROOT_PASS" --database="mosquitto" --execute="INSERT INTO acls (device_id, topic, rw, is_enabled, date_created, last_update_date) VALUES ('test_dht_deviceid', 'test_dht_deviceid/#', 2, 1, null, null);"

	#################################################### MANUAL UPDATE ####################################################
	#	mysql -u root -p
	#		
	#	USE mosquitto;
	#
	#	DROP TABLE IF EXISTS device_types;
	#	CREATE TABLE device_types (
	#	type VARCHAR(32) NOT NULL,
	#	date_created TIMESTAMP DEFAULT NOW(),
	#	PRIMARY KEY (type)
	#	);
	#
	#	DROP TABLE IF EXISTS device_models;
	#	CREATE TABLE device_models (
	#	model VARCHAR(32) NOT NULL,
	#	date_created TIMESTAMP DEFAULT NOW(),
	#	PRIMARY KEY (model)
	#	);
	#
	#	DROP TABLE IF EXISTS customers;
	#	CREATE TABLE customers (
	#	user_id INTEGER NOT NULL,
	#	email VARCHAR(32) NOT NULL,
	#	password VARCHAR(128) NOT NULL,
	#	is_active INT(1) NOT NULL DEFAULT 1,
	#	country_id INT(3),
	#	registration_ip VARCHAR(15),
	#	language VARCHAR(2) NOT NULL DEFAULT 'EN',
	#	date_created TIMESTAMP DEFAULT NOW(),
	#	last_update_date TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	#	last_login TIMESTAMP,
	#	last_login_ip VARCHAR(15),
	#	PRIMARY KEY (user_id),
	#	KEY user_id(user_id),
	#	FOREIGN KEY (user_id) REFERENCES django_android.auth_user(id)
	#	);
	#	CREATE UNIQUE INDEX customers_username_idx ON customers (user_id);
	#
	#	DROP TABLE IF EXISTS devices;
	#	CREATE TABLE devices (
	#	device_id VARCHAR(32) NOT NULL,
	#	password VARCHAR(128) NOT NULL,
	#	super INT(1) NOT NULL DEFAULT 0,
	#	is_enabled INT(1) NOT NULL DEFAULT 0,
	#	model VARCHAR(32) NOT NULL,
	#	type VARCHAR(32) NOT NULL,
	#	date_created TIMESTAMP DEFAULT NOW(),
	#	last_update_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	#	last_connection TIMESTAMP,
	#	last_connection_ip VARCHAR(15),
	#	PRIMARY KEY (device_id),
	#	FOREIGN KEY (type) REFERENCES device_types(type),
	#	FOREIGN KEY (model) REFERENCES device_models(model)
	#	);
	#	CREATE UNIQUE INDEX devices_deviceid_idx ON devices (device_id);
	#
	#	DROP TABLE IF EXISTS customer_devices;
	#	CREATE TABLE customer_devices (
	#	id INTEGER AUTO_INCREMENT,
	#	user_id INTEGER NOT NULL,
	#	device_id VARCHAR(32) NOT NULL,
	#	device_name VARCHAR(32) NOT NULL,
	#	date_created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	#	PRIMARY KEY (user_id, device_id),
	#	KEY id(id),
	#	FOREIGN KEY (user_id) REFERENCES customers(user_id),
	#	FOREIGN KEY (device_id) REFERENCES devices(device_id)
	#	);
	#
	#	DROP TABLE IF EXISTS acls;
	#	CREATE TABLE acls (
	#	id INTEGER AUTO_INCREMENT,
	#	device_id VARCHAR(32) NOT NULL,
	#	topic VARCHAR(256) NOT NULL,
	#	rw INTEGER(1) NOT NULL DEFAULT 1,	-- 1: read-only, 2: read-write
	#	is_enabled INT(1) NOT NULL DEFAULT 1,
	#	date_created TIMESTAMP DEFAULT NOW(),
	#	last_update_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	#	PRIMARY KEY (id),
	#	FOREIGN KEY (device_id) REFERENCES devices(device_id)
	#	);
	#	CREATE UNIQUE INDEX acls_deviceid_idx ON acls (device_id, topic(228));
	#
	#	DROP TABLE IF EXISTS messages;
	#	CREATE TABLE messages (
	#	message_id INTEGER AUTO_INCREMENT,
	#	device_id VARCHAR(32) NOT NULL,
	#	topic VARCHAR(256) NOT NULL,
	#	message VARCHAR(256) NOT NULL,
	#	qos INT(1) NOT NULL DEFAULT 1,
	#	date_created TIMESTAMP DEFAULT NOW(),
	#	last_update_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	#	PRIMARY KEY (message_id),
	#	FOREIGN KEY (device_id) REFERENCES devices(device_id)
	#	);
	#	CREATE UNIQUE INDEX messages_idx ON messages (message_id);
	#
	#	#### CHANGE PASSWORD !!! 
	#	#### PBKDF2$sha256$901$tlTV+swNfeA9QDPo$ZbEu+w05Gor+DVXPu0x3MsoiHnBk27ZE is the representation of the password '12345678'
	#	INSERT INTO devices (device_id, password, is_enabled, model, type, date_created, last_update_date, last_connection) VALUES ('homebridge', 'PBKDF2$sha256$901$tlTV+swNfeA9QDPo$ZbEu+w05Gor+DVXPu0x3MsoiHnBk27ZE', '1', 'service', 'service', null, null, null);
	#	INSERT INTO acls (device_id, topic, rw, is_enabled, date_created, last_update_date) VALUES ('homebridge', '#', 2, 1, null, null); #rw = 1 then only allow to subscribe, rw = 2 allow also to publish
	#	INSERT INTO devices (device_id, password, is_enabled, model, type, date_created, last_update_date, last_connection) VALUES ('mqtt2db', 'PBKDF2$sha256$901$tlTV+swNfeA9QDPo$ZbEu+w05Gor+DVXPu0x3MsoiHnBk27ZE', '1', 'service', 'service', null, null, null);
	#	INSERT INTO acls (device_id, topic, rw, is_enabled, date_created, last_update_date) VALUES ('mqtt2db', '#', 2, 1, null, null); #rw = 1 then only allow to subscribe, rw = 2 allow also to publish
	#
	#	QUIT;
	########################################################################################################
}


function mosquitto_auth_plug() {
	echo Running mosquitto_auth_plug function
	#Now you should have running a very basic moquitto configuration
	
	#We need to integrate an ACL plugin into mosquitto server (Additional reading can be found here https://github.com/jpmens/mosquitto-auth-plug/blob/master/README.md)
	
	#git clone the ACL plugin project:
	echo Cloning Auth-Plug
	cd $HOME
	git clone https://github.com/jpmens/mosquitto-auth-plug.git
	echo Updating config.mk
	cd $HOME/mosquitto-auth-plug
	cp config.mk.in config.mk
	#Config the file as your need acourding to link: https://github.com/jpmens/mosquitto-auth-plug/blob/master/README.md
	
	sudo sed -i "s:MOSQUITTO_SRC =:MOSQUITTO_SRC = $HOME/mosquitto-1.4.14:" $HOME/mosquitto-auth-plug/config.mk
	sudo sed -i "s:OPENSSLDIR = /usr:OPENSSLDIR = /etc/mosquitto/cert:" $HOME/mosquitto-auth-plug/config.mk
	
	########## MANUAL UPDATE ##########
	#vim $HOME/mosquitto-auth-plug/config.mk
	#Ive also specified:
	#	MOSQUITTO_SRC = $HOME/mosquitto-1.4.14
	#	OPENSSLDIR = /etc/mosquitto/cert
	####################################
	
	echo Updateing cache.c
	#update file cache.c from mosquitto-auth-plug in order to allow usage on openssl 1.0.1:
	sudo sed -i "s:#if OPENSSL_VERSION_NUMBER://if OPENSSL_VERSION_NUMBER:" $HOME/mosquitto-auth-plug/cache.c
	sudo sed -i "s:#else://else:" $HOME/mosquitto-auth-plug/cache.c
	sudo sed -i 's:EVP_MD_CTX \*mdctx = EVP_MD_CTX_new://EVP_MD_CTX \*mdctx = EVP_MD_CTX_new:' $HOME/mosquitto-auth-plug/cache.c
	sudo sed -i "s:#endif://endif:" $HOME/mosquitto-auth-plug/cache.c
	sudo sed -i "s:EVP_MD_CTX_free://EVP_MD_CTX_free:" $HOME/mosquitto-auth-plug/cache.c
	
	########## MANUAL UPDATE ##########
	#The relevant lines should look like that:
	#
	#vim cache.c
	#	const EVP_MD *md = EVP_get_digestbyname("SHA1");
	#
	#	if (md != NULL) {
	#		//if OPENSSL_VERSION_NUMBER < 0x10100000 || defined(LIBRESSL_VERSION_NUMBER)
	#		EVP_MD_CTX *mdctx = EVP_MD_CTX_create();
	#		//else
	#		//EVP_MD_CTX *mdctx = EVP_MD_CTX_new();
	#		//endif
	#		EVP_MD_CTX_init(mdctx);
	#		EVP_DigestInit_ex(mdctx, md, NULL);
	#		EVP_DigestUpdate(mdctx, data, size);
	#		EVP_DigestFinal_ex(mdctx, out, &md_len);
	#		//if OPENSSL_VERSION_NUMBER < 0x10100000 || defined(LIBRESSL_VERSION_NUMBER)
	#		EVP_MD_CTX_destroy(mdctx);
	#		//else
	#		//EVP_MD_CTX_free(mdctx);
	#		//endif
	#	}
	#	return md_len;
	####################################
	
	#Run make command
	echo Making Auth-Plug
	make
	#After the make you should have a shared object called auth-plug.so which you will reference in your mosquitto.conf
	
	echo Setting Auth-Plug Permissions
	sudo cp $HOME/mosquitto-auth-plug/auth-plug.so /etc/mosquitto/auth-plug.so
	sudo chown root:root /etc/mosquitto/auth-plug.so
	
	#test
	#	mosquitto -c /etc/mosquitto/mosquitto.conf
	#	mosquitto_pub -d -h localhost -p 8883 -t topic -m payload -u homebridge -P 12345678
}
	

function mosquitto_ssl_tls_setup() {
	echo Running mosquitto_ssl_tls_setup function
	sudo mkdir /etc/mosquitto/certs
	cd /etc/mosquitto/certs
	
	#TLS And Certificates (More info at http://www.steves-internet-guide.com/mosquitto-tls/)

	#sudo openssl genrsa -des3 -out /etc/mosquitto/certs/mosquitto_ca.key 2048
	#Choose strong password and save it (This is the password for the decryption key)
	
	sudo openssl genrsa -out /etc/mosquitto/certs/mosquitto_ca.key 2048
		
	#Create a certificate for the CA using the CA key
	sudo openssl req -subj "/C=IL/L=Tel-Aviv/O=$DOMAIN_NAME/CN=$DOMAIN_NAME" -new -x509 -days 1826 -key /etc/mosquitto/certs/mosquitto_ca.key -out /etc/mosquitto/certs/mosquitto_ca.crt
	#create a server key pair that will be used by the broker
	sudo openssl genrsa -out /etc/mosquitto/certs/mosquitto_server.key 2048
	#create a certificate request .csr
	sudo openssl req -subj "/C=IL/L=Tel-Aviv/O=$DOMAIN_NAME/CN=$DOMAIN_NAME" -new -out /etc/mosquitto/certs/mosquitto_server.csr -key /etc/mosquitto/certs/mosquitto_server.key
		
	#Now we use the CA key to verify and sign the server certificate. This create the server.crt file
	sudo openssl x509 -req -in /etc/mosquitto/certs/mosquitto_server.csr -CA /etc/mosquitto/certs/mosquitto_ca.crt -CAkey /etc/mosquitto/certs/mosquitto_ca.key -CAcreateserial -out /etc/mosquitto/certs/mosquitto_server.crt -days 360

	echo Updating /etc/mosquitto/mosquitto.conf for SSL\TLS use
	#Update /etc/mosquitto/mosquitto.conf file to use SSL\TLS
	sudo sed -i "s:#cafile /etc:cafile /etc:" /etc/mosquitto/mosquitto.conf
	sudo sed -i "s:#keyfile /etc:keyfile /etc:" /etc/mosquitto/mosquitto.conf
	sudo sed -i "s:#certfile /etc:certfile /etc:" /etc/mosquitto/mosquitto.conf
	sudo sed -i "s:#tls_version tlsv1.1:tls_version tlsv1.1:" /etc/mosquitto/mosquitto.conf
	
	########## MANUAL UPDATE ##########
	#sudo vim /etc/mosquitto/mosquitto.conf
	#
	#Uncomment these lines:
	#	cafile /etc/mosquitto/certs/mosquitto_ca.crt
	#	keyfile /etc/mosquitto/certs/mosquitto_server.key
	#	certfile /etc/mosquitto/certs/mosquitto_server.crt
	#	tls_version tlsv1.1
	#######################################
	
	echo Opening FW ports
	if [ "$OS" = "CentOS Linux" ]; then
		sudo firewall-cmd --zone=public --add-port=8883/tcp --permanent
		sudo firewall-cmd --reload
	elif [ "$OS" = "Raspbian GNU/Linux" ]; then
		sudo ufw allow 8883
	fi

	sudo chmod 644 /etc/mosquitto/certs/*
		
	### Then use mosquitto_server.crt to connect the server from testing clients
	
	#IMPORTANT!!!
	#The common name you choose on the certificate MUST match your test
	#Common Name (e.g. server FQDN or YOUR name) []:nalkins.cloud
	#That means you need to solve networking issues, OR vim /ets/hosts to point nalkins.cloud to 127.0.0.1
	
	#test
	#	mosquitto -c /etc/mosquitto/mosquitto.conf
	#	mosquitto_pub -d --cafile /etc/mosquitto/certs/mosquitto_server.crt --tls-version tlsv1.2 -t topic -m payload -h nalkins.cloud -p 8883 -q 1 -u homebridge -P 12345678
	
	#Now you have a full encrypted working mosquitto server
}
	

function create_bks_file() {
	echo Running create_bks_file function
	
	#Download latest .jar file:
	echo Donwloading bcprov-jdk15on-158.jar
	cd $HOME
	wget https://www.bouncycastle.org/download/bcprov-jdk15on-158.jar
	
	#Next we will neet to create BKS (bouncyCastle) file from .crt, this will be used later in our android project
	#First install Java JDK so we can you keytool
	echo Creating $HOME/$DOMAIN_NAME.crt.bks
	if [ "$OS" = "CentOS Linux" ]; then
		sudo yum -y update
		sudo yum -y install java-1.8.0-openjdk-devel
	elif [ "$OS" = "Raspbian GNU/Linux" ]; then
		sudo apt-get -y update
		sudo apt-get -y install openjdk-8-jdk
		sudo apt-get -y upgrade
	fi
	sudo keytool -importcert -noprompt -v -trustcacerts -file "/etc/mosquitto/certs/mosquitto_server.crt" -alias IntermediateCA -keystore "$HOME/mosquitto.$DOMAIN_NAME.crt.bks" -provider org.bouncycastle.jce.provider.BouncyCastleProvider -providerpath "$HOME/bcprov-jdk15on-158.jar" -storetype BKS -storepass $MOSQUITTO_BKS_FILE_PASS
	###########################################################################################################################
	#OK so now you should have file mosquitto.*.crt.bks on home dir, we will later need to copy this file to our android project
}
	

function mosquitto_server_systemd() {
	echo Running mosquitto_server_systemd function
	
	sudo echo -e "[Unit]\nDescription=Mosquitto MQTT Broker\nDocumentation=man:mosquitto(8)\nDocumentation=man:mosquitto.conf(5)\nConditionPathExists=/etc/mosquitto/mosquitto.conf\nAfter=xdk-daemon.service\n\n[Service]\nExecStart=/usr/local/sbin/mosquitto -c /etc/mosquitto/mosquitto.conf\nExecReload=/bin/kill -HUP \$MAINPID\nUser=mosquitto\nRestart=on-failure\nRestartSec=10\n\n[Install]\nWantedBy=multi-user.target" | sudo tee -a /etc/systemd/system/mosquitto.service
	
	################# MANUAL UPDATE ###################
	#	sudo vim /etc/systemd/system/mosquitto.service
	#	Append this to file
	#[Unit]
	#Description=Mosquitto MQTT Broker
	#Documentation=man:mosquitto(8)
	#Documentation=man:mosquitto.conf(5)
	#ConditionPathExists=/etc/mosquitto/mosquitto.conf
	#After=xdk-daemon.service
	#
	#[Service]
	#ExecStart=/usr/local/sbin/mosquitto -c /etc/mosquitto/mosquitto.conf
	#ExecReload=/bin/kill -HUP $MAINPID
	#User=mosquitto
	#Restart=on-failure
	#RestartSec=10
	#
	#[Install]
	#WantedBy=multi-user.target
	###################################################
	
	#allow user to write log log dir
	sudo chown -R mosquitto:mosquitto /var/log/mosquitto
	
	sudo systemctl daemon-reload
	sudo systemctl enable mosquitto
	sudo systemctl start mosquitto
	
	#test
	sudo systemctl status mosquitto
}

		
function homebridge_installation() {

	echo Running homebridge_installation function
	echo Installing Homebridge via NPM
	if [ "$OS" = "CentOS Linux" ]; then
		sudo yum -y install nodejs
		#test
		node --version
		sudo yum -y install avahi-compat-libdns_sd-devel
		
		# sudo yum install gcc-c++ make Needed when installing solo
		sudo npm install -g homebridge
	elif [ "$OS" = "Raspbian GNU/Linux" ]; then
		cd $HOME
		
		if [ "$VER" -lt 8 ]; then
			#Install C++14 (Skip this part if you are on Raspbian Jessie)

			git clone https://bitbucket.org/sol_prog/raspberry-pi-gcc-binary.git

			cd raspberry-pi-gcc-binary
			tar xf gcc-7.2.0.tar.bz2
			sudo mv gcc-7.2.0 /usr/local
			export PATH=/usr/local/gcc-7.2.0/bin:$PATH
			echo 'export PATH=/usr/local/gcc-7.2.0/bin:$PATH' >> .bashrc
			source .bashrc
			sudo rm -r $HOME/raspberry-pi-gcc-binary/

			#test
			g++-7.2.0 -v
		fi
		sudo apt-get -y install curl
		curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
		sudo apt-get -y install nodejs
		sudo apt-get -y install libavahi-compat-libdnssd-dev

		#test
		node --version
			
		#sudo npm install -g homebridge
		#OR
		sudo npm install -g --unsafe-perm homebridge

		#test
		#homebridge
			
		#If you get error:
		#Error: Cannot find module '../build/Release/dns_sd_bindings'
		#DO:
		sudo npm install --unsafe-perm mdns
		cd /usr/lib/node_modules/homebridge/
		sudo npm rebuild --unsafe-perm
		
	fi

	#test
	#homebridge
		
	#------ link mosquitto server to homebridge server ------

	#sudo npm install -g homebridge-mqtt
	#We will use homebridge-mqtt plugin from https://github.com/cflurin/homebridge-mqtt
	#But we will need to change the code so plugins messages will be of same structure as the rest of our project (We cannot use JSON message structure)
	
	echo Installing homebridge-mqtt
	cd $HOME
	git clone https://github.com/cflurin/homebridge-mqtt.git
	cd $HOME/homebridge-mqtt
	
	############### ------------CHANGE CODE PART HERE----------- ######################
	
	cd /var/lib
	sudo npm install $HOME/homebridge-mqtt
	
	#sudo cp -rf $HOME/homebridge-mqtt /usr/lib/node_modules/homebridge-mqtt
	### PLEASE NOTE - each cahnge on the 'config.json' file do:
		#	sudo cp $HOME/.homebridge/config.json /var/homebridge/
		#	sudo cp -r $HOME/.homebridge/persist /var/homebridge
		#	sudo chmod -R 0777 /var/homebridge
	mkdir $HOME/.homebridge
	sudo echo -e '{\t\n\t"bridge": {\n\t\t"name": "Homebridge",\n\t\t"username": "D2:22:3D:F4:AA:30",\n\t\t"port": 52645,\n\t\t"pin": "056-71-945"\n\t},\n\t\n\t"platforms": [\n\t\t{\n\t\t"platform": "mqtt",\n\t\t"name": "mqtt",\n\t\t"url": "mqtt://localhost:1883",\n\t\t"topic_type": "multiple",\n\t\t"topic_prefix": "homebridge",\n\t\t"username": "homebridge",\n\t\t"password": "12345678"\n\t\t}\n\t]\n}' | sudo tee -a $HOME/.homebridge/config.json
	sudo cp $HOME/.homebridge/config.json /var/homebridge/
	
	################# MANUAL UPDATE ###################
	#	cd $HOME/.homebridge
	#	vim config.json
	#	
	#{	
	#	"bridge": {
	#		"name": "Homebridge",
	#		"username": "D2:22:3D:F4:AA:30",
	#		"port": 52645,
	#		"pin": "056-71-945"
	#	},
	#	
	#	"platforms": [
	#		{
	#		"platform": "mqtt",
	#		"name": "mqtt",
	#		"url": "mqtt://localhost:1883",
	#		"topic_type": "multiple",
	#		"topic_prefix": "homebridge",
	#		"username": "homebridge",
	#		"password": "12345678"
	#		}
	#	]
	#}
	###################################################
	
	#test
	#	mosquitto_pub -d -h localhost -p 1883 -t homebridge/to/get -m '{"name": "*"}' -u homebridge -P 12345678
}
		

function homebridge_server_systemd() {
	echo Running homebridge_server_systemd function
	sudo echo -e "# Defaults / Configuration options for homebridge\n# The following settings tells homebridge where to find the config.json file and where to persist the data (i.e. pairing and others)\nHOMEBRIDGE_OPTS=-U /var/homebridge\n\n# If you uncomment the following line, homebridge will log more \n# You can display this via systemd's journalctl: journalctl -f -u homebridge\nDEBUG=*" | sudo tee /etc/default/homebridge

	################# MANUAL UPDATE ###################
	#	sudo vim /etc/default/homebridge
	#	
	## Defaults / Configuration options for homebridge
	## The following settings tells homebridge where to find the config.json file and where to persist the data (i.e. pairing and others)
	#HOMEBRIDGE_OPTS=-U /var/homebridge
	#
	## If you uncomment the following line, homebridge will log more 
	## You can display this via systemd's journalctl: journalctl -f -u homebridge
	#DEBUG=*
	###################################################	

	sudo echo -e "[Unit]\nDescription=Node.js HomeKit Server \nAfter=syslog.target network-online.target\n\n[Service]\nType=simple\nUser=homebridge\nEnvironmentFile=/etc/default/homebridge\nExecStart=/usr/bin/homebridge \$HOMEBRIDGE_OPTS\nRestart=on-failure\nRestartSec=10\nKillMode=process\n\n[Install]\nWantedBy=multi-user.target" | sudo tee /etc/systemd/system/homebridge.service

	################# MANUAL UPDATE ###################
	#	sudo vim /etc/systemd/system/homebridge.service
	#	
	#[Unit]
	#Description=Node.js HomeKit Server 
	#After=syslog.target network-online.target
	#
	#[Service]
	#Type=simple
	#User=homebridge
	#EnvironmentFile=/etc/default/homebridge
	#ExecStart=/usr/bin/homebridge $HOMEBRIDGE_OPTS
	#Restart=on-failure
	#RestartSec=10
	#KillMode=process
	#
	#[Install]
	#WantedBy=multi-user.target
	###################################################
		
	sudo mkdir /var/homebridge
	sudo cp $HOME/.homebridge/config.json /var/homebridge/
	sudo cp -r $HOME/.homebridge/persist /var/homebridge
	sudo chmod -R 0777 /var/homebridge
	sudo chown -R homebridge:homebridge /var/homebridge/
	
	sudo systemctl daemon-reload
	sudo systemctl enable homebridge
	sudo systemctl start homebridge

	#test
	systemctl status homebridge
	
	#Log homebridge by running
	#journalctl -f -u homebridge
}
	

function mqtt2db_service_systemd() {

	echo Running mqtt2db_service_systemd function
	if [ "$OS" = "CentOS Linux" ]; then
		sudo echo -e "[Unit]\nDescription=MQTT 2 DB Client\nAfter=mosquitto.service mariadb.service\n\n[Service]\nType=simple\nExecStart=\nExecStart=/usr/bin/python3.6 /etc/mqtt2db/mqtt2db.py\nExecReload=/bin/kill -HUP $MAINPID\nUser=mqtt2db\nRestart=on-failure\nRestartSec=10\n\n[Install]\nWantedBy=multi-user.target" | sudo tee /etc/systemd/system/mqtt2db.service
	elif [ "$OS" = "Raspbian GNU/Linux" ]; then
		sudo echo -e "[Unit]\nDescription=MQTT 2 DB Client\nAfter=mosquitto.service mariadb.service\n\n[Service]\nType=simple\nExecStart=\nExecStart=/usr/bin/python3.5 /etc/mqtt2db/mqtt2db.py\nExecReload=/bin/kill -HUP $MAINPID\nUser=mqtt2db\nRestart=on-failure\nRestartSec=10\n\n[Install]\nWantedBy=multi-user.target" | sudo tee /etc/systemd/system/mqtt2db.service
	fi

	################# MANUAL UPDATE ###################
	#sudo vim /etc/systemd/system/mqtt2db.service
	#
	#[Unit]
	#Description=MQTT 2 DB Client
	#Requires=mosquitto.service mariadb.service
	#After=mosquitto.service
	#
	#[Service]
	#Type=simple
	#ExecStart=
	#ExecStart=/usr/bin/python3.6 /etc/mqtt2db/mqtt2db.py
	#ExecReload=/bin/kill -HUP $MAINPID
	#User=mqtt2db
	#Restart=on-failure
	#RestartSec=10
	#
	#[Install]
	#WantedBy=multi-user.target
	###################################################
	
	echo Setup run file and logs
	sudo mkdir /etc/mqtt2db/
	
	#### CLONE MQTT2DB.py SCRIPT TO /etc/mqtt2db/
	
	sudo chown mqtt2db:mqtt2db /etc/mqtt2db/*.py
	sudo mkdir /var/log/mqtt2db/
	sudo chown mqtt2db:mqtt2db /var/log/mqtt2db/
	
	echo Installing paho-mqtt mysqlclient libraries
	sudo pip3.6 install paho-mqtt mysqlclient
	
	sudo systemctl daemon-reload
	sudo systemctl enable mqtt2db
	sudo systemctl start mqtt2db
	
	#test
	sudo systemctl status mqtt2db
}


function mqtt_simulators_systemd() {

	echo Running NalkinsCloud-MQTT-Automation-Simulators function
	# Create testing user
	sudo useradd --system mqtt_simulator
	
	if [ "$OS" = "CentOS Linux" ]; then
		sudo echo -e "[Unit]\nDescription=MQTT DHT Simulation service\nRequires=mosquitto.service\nAfter=mosquitto.service\n\n[Service]\nExecStart=/usr/bin/python3.6 /etc/NalkinsCloud-MQTT-Automation-Simulators/test_dht.py\nExecReload=/bin/kill -HUP $MAINPID\nUser=mqtt_simulator\nRestart=on-failure\nRestartSec=10\n\n[Install]\nWantedBy=multi-user.target" | sudo tee /etc/systemd/system/mqtt_dht_simulator.service
		sudo echo -e "[Unit]\nDescription=MQTT DHT Simulation service\nRequires=mosquitto.service\nAfter=mosquitto.service\n\n[Service]\nExecStart=/usr/bin/python3.6 /etc/NalkinsCloud-MQTT-Automation-Simulators/test_switch.py\nExecReload=/bin/kill -HUP $MAINPID\nUser=mqtt_simulator\nRestart=on-failure\nRestartSec=10\n\n[Install]\nWantedBy=multi-user.target" | sudo tee /etc/systemd/system/mqtt_switch_simulator.service
	elif [ "$OS" = "Raspbian GNU/Linux" ]; then
		sudo echo -e "[Unit]\nDescription=MQTT DHT Simulation service\nRequires=mosquitto.service\nAfter=mosquitto.service\n\n[Service]\nExecStart=/usr/bin/python3.5 /etc/NalkinsCloud-MQTT-Automation-Simulators/test_dht.py\nExecReload=/bin/kill -HUP $MAINPID\nUser=mqtt_simulator\nRestart=on-failure\nRestartSec=10\n\n[Install]\nWantedBy=multi-user.target" | sudo tee /etc/systemd/system/mqtt_dht_simulator.service
		sudo echo -e "[Unit]\nDescription=MQTT DHT Simulation service\nRequires=mosquitto.service\nAfter=mosquitto.service\n\n[Service]\nExecStart=/usr/bin/python3.5 /etc/NalkinsCloud-MQTT-Automation-Simulators/test_switch.py\nExecReload=/bin/kill -HUP $MAINPID\nUser=mqtt_simulator\nRestart=on-failure\nRestartSec=10\n\n[Install]\nWantedBy=multi-user.target" | sudo tee /etc/systemd/system/mqtt_switch_simulator.service
	fi
	
	################ Temperature (DHT) tester MANUAL UPDATE ################
	#sudo vim /etc/systemd/system/mqtt_dht_simulator.service
	#
	#[Unit]
	#Description=MQTT DHT Simulation service
	#Requires=mosquitto.service
	#After=mosquitto.service
	#
	#[Service]
	#ExecStart=/usr/bin/python3.6 /etc/NalkinsCloud-MQTT-Automation-Simulators/test_dht.py
	#ExecReload=/bin/kill -HUP $MAINPID
	#User=mqtt_simulator
	#Restart=on-failure
	#RestartSec=10
	#
	#[Install]
	#WantedBy=multi-user.target
	################################################################################
	
	################ Switch tester MANUAL UPDATE ################
	#sudo vim /etc/systemd/system/mqtt_switch_simulator.service
	#	
	#	[Unit]
	#Description=MQTT DHT Simulation service
	#Requires=mosquitto.service
	#After=mosquitto.service
	#
	#[Service]
	#ExecStart=/usr/bin/python3.6 /etc/NalkinsCloud-MQTT-Automation-Simulators/test_switch.py
	#ExecReload=/bin/kill -HUP $MAINPID
	#User=mqtt_simulator
	#Restart=on-failure
	#RestartSec=10
	#
	#[Install]
	#WantedBy=multi-user.target
	
	cd /etc
	sudo git clone https://github.com/ArieLevs/NalkinsCloud-MQTT-Automation-Simulators.git

	cd /etc/NalkinsCloud-MQTT-Automation-Simulators/
	
	sudo sed -i "s/mosquitto_dht_pass = ''/mosquitto_dht_pass = '$DB_DHT_SIMULATE_PASS'/" /etc/NalkinsCloud-MQTT-Automation-Simulators/configs.py
	sudo sed -i "s/mosquitto_switch_pass = ''/mosquitto_switch_pass = '$DB_SWITCH_SIMULATE_PASS'/" /etc/NalkinsCloud-MQTT-Automation-Simulators/configs.py
	
	# Inset to DB 
	sudo mysql --user="$DB_ROOT_USER" --password="$DB_ROOT_PASS" --database="mosquitto" --execute="INSERT INTO devices (device_id, password, is_enabled, model, type, date_created, last_update_date, last_connection) VALUES ('$DB_DHT_SIMULATE_USER', '$DB_DHT_SIMULATE_PASS', '1', 'ESP8266', 'dht', null, null, null);"
	sudo mysql --user="$DB_ROOT_USER" --password="$DB_ROOT_PASS" --database="mosquitto" --execute="INSERT INTO acls (device_id, topic, rw, is_enabled, date_created, last_update_date) VALUES ('$DB_DHT_SIMULATE_USER', '$DB_DHT_SIMULATE_USER/#', 2, 1, null, null);"
	sudo mysql --user="$DB_ROOT_USER" --password="$DB_ROOT_PASS" --database="mosquitto" --execute="INSERT INTO devices (device_id, password, is_enabled, model, type, date_created, last_update_date, last_connection) VALUES ('$DB_SWITCH_SIMULATE_USER', '$DB_SWITCH_SIMULATE_PASS', '1', 'ESP8266', 'switch', null, null, null);"
	sudo mysql --user="$DB_ROOT_USER" --password="$DB_ROOT_PASS" --database="mosquitto" --execute="INSERT INTO acls (device_id, topic, rw, is_enabled, date_created, last_update_date) VALUES ('$DB_SWITCH_SIMULATE_USER', '$DB_SWITCH_SIMULATE_USER/#', 2, 1, null, null);"
	
	sudo chown -R mqtt_simulator:mqtt_simulator /etc/NalkinsCloud-MQTT-Automation-Simulators/
	
	sudo systemctl daemon-reload
	sudo systemctl enable mqtt_dht_simulator.service
	sudo systemctl enable mqtt_switch_simulator.service
	sudo systemctl start mqtt_dht_simulator.service
	sudo systemctl start mqtt_switch_simulator.service
	
	#test
	sudo systemctl status mqtt_dht_simulator.service
	sudo systemctl status mqtt_switch_simulator.service
}

main "$@"




####### UTILITIES #####
# View certificate info:
#	openssl x509 -in certname.cer -noout -text
#
#SHA1 check
#	openssl x509 -noout -fingerprint -sha1 -inform pem -in [certificate-file.crt]
#	
#SHA256 check
#	openssl x509 -noout -fingerprint -sha256 -inform pem -in [certificate-file.crt]
#
######################