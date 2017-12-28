NalkinsCloud
============
This is an IOT Automation project, it will provide the ability to monitor and control your indoor\outdoor devices from anywhere.
Project uses server side writen in python, hardware written in c++ based on the ESP8266 chip, android application in Java, and small NodeJS server to support IOS 

Getting started
----------------
What will you do:
* Choose server side - Use Raspberrypi Pi or Centos7 as your server.
* Install web server - Setup django running under apache, configure full SSL encryption, and clone python part.
* Install database - Setup MariaDB server to support all components.
* Install MQTT Broker - mosquitto server, integrating to authentication plugin supporting ACLs, and setting full TLS encryption.
* Setup message listener - Setting up mqtt2db service, that will act as a listener to inject messages to database
* Install Homebridge server - With mqtt support so you could use IOS with this project
* Build your hardware - Use various custom devices, that you will build yourself, then clode c++ part to ESP8266

## Installation
All services and code will setup on the same machine, Centos7 or Raspberrypi 4.9.59-v7+

Start by installing Raspberrypi, download 'RASPBIAN STRETCH LITE' from https://www.raspberrypi.org/downloads/raspbian/
And create micro-sd with that image (Rufus is recomended)
Based on: Linux raspberrypi 4.9.59-v7+ # armv7l GNU/Linux

For Setting up the project on Centos7 OS, Download image: https://www.centos.org/download/
If you need asistance to make the USB installation use this guide https://wiki.centos.org/HowTos/InstallFromUSBkey
Based on: CentOS Linux 7 Kernel: Linux 3.10.0-693.5.2.el7.x86_64

- For additional assiatance please search on how to install the OS

### If you choose Raspberrypi you will need to configure it for ssh use
Connect the Raspberrypi to a monitor and keyboard, once OS is up:

Default login user is 'pi' and password is 'raspberry'
Change tha password, After login with 'pi' user type `passwd`  
add use to sudoers
```
usermod -aG sudo pi
sudo systemctl enable ssh
sudo systemctl start ssh
```
secure the connection:
```
cd $HOME
ssh-keygen
```
OK so now we have two files:
	ssh_auth_key and ssh_auth_key.pub
	
The ssh_auth_key (private key) should be moved to the client (To each machine you will be connecting the Raspberry from, AND KEPT IT SECURE)
```
mkdir ~/.ssh/
cat ssh_auth_key.pub >> ~/.ssh/authorized_keys #add the key
chmod 600 ~/.ssh/authorized_keys
```
#Disable password connection
sudo vim /etc/ssh/sshd_config

#Change these to 'no'
#	ChallengeResponseAuthentification no
#	PasswordAuthentification no

sudo service ssh reload
```
If using putty to connect, open puttygen and convert it to .ppk file (import key then save as private key)
