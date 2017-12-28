NalkinsCloud
============
This is an IOT Automation project, it will provide the ability to monitor and control your indoor\outdoor devices from anywhere.
Project uses server side writen in python, hardware written in c++ based on the ESP8266 chip, android application in Java, and small NodeJS server to support IOS clients.

Getting started
---------------
What will you do:
* Choose server side - Use Raspberrypi Pi or Centos7 as your server.
* Install web server - Setup django running under apache, configure full SSL encryption, and clone python part.
* Install database - Setup MariaDB server to support all components.
* Install MQTT Broker - mosquitto server, integrating to authentication plugin supporting ACLs, and setting full TLS encryption.
* Setup message listener - Setting up mqtt2db service, that will act as a listener to inject messages to database
* Install Homebridge server - With mqtt support so you could use IOS with this project
* Build your hardware - Use various custom devices, that you will build yourself, then clode c++ part to ESP8266


Installation
------------
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

Default login user is 'pi' and password is 'raspberry', Change the password  
After login with 'pi' user type `passwd`  
add user to sudoers
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
OK so now we have two files: ssh_auth_key and ssh_auth_key.pub
	
The ssh_auth_key (private key) should be moved to the client (To each machine you will be connecting the Raspberry from, AND KEPT IT SECURE)
```
mkdir ~/.ssh/
cat ssh_auth_key.pub >> ~/.ssh/authorized_keys #add the key
chmod 600 ~/.ssh/authorized_keys
```
Disable password connection `sudo vim /etc/ssh/sshd_config`  
Change to 'no': `ChallengeResponseAuthentification no` and `PasswordAuthentification no`, save the file  
Finally run `sudo service ssh reload`

* If using [putty](http://www.putty.org/) to ssh, open puttygen and convert it to .ppk file (import key then save as private key)
	
Set up firewall:
```
sudo apt-get install ufw
sudo ufw allow ssh
sudo ufw enable
```
*optional:* (Allow mouse right click to past clipboard to terminal on vim editor)
```
sudo apt-get install vim
sudo vim /usr/share/vim/vim80/defaults.vim
#Append: (Comment each line with ")
	"if has('mouse')
	"  set mouse=r
	"endif
```
Setup Static IP: (Change with your relevant LAN ip)  
`sudo vim /etc/dhcpcd.conf`  
Append to buttom of page:
```
interface eth0
	static ip_address=192.168.0.10/24
	static routers=192.168.0.1
	static domain_name_servers=192.168.0.1
```
`sudo reboot`

Then you could leave you pi near the router and ssh to 192.168.0.10  
SSH to the instance, we will start installing the project

If using Centos7: `sudo yum -y install git`

If using Raspbian: `sudo apt-get -y install git`

Clone setup automation
```
cd $HOME
git clone #### CLONE NALKINS.CLOUD SETUP AUTOMATION
```
Before you run the file, make sure to `vim $HOME/nalkins.cloud.conf` properly *nalkins.cloud.conf* file, Please choose passwords
	
For full automatic project installation on a single node, run nalkins.cloud.automation.sh
```
chmod +x $HOME/nalkins.cloud.automation.sh
./nalkins.cloud.automation.sh
```
	
* **If you wish to install manually _or error uccored_ (and it probably will! prepare yourself :-),
Just got to (URL TO nalkins.cloud.automation.sh) And run line by line accourding to your OS.**

Post Installation
-----------------

Go to 
	https://www.nalkins.cloud/admin/oauth2_provider/application/add/ *Please change domain with relevant IP\Domain*
```
Choose:
	Client type: Confidential
	Authorization grant type: Resource owner password-based
	Name: Android (To your choice)
	
	And save
```
Whe have just created an application so django can serve clients  
Please 

Conclusion
----------

OK so what we've done here,  
We've installed MariaDB server, that will serve both client and devices  
Installed Django application which runs under apache server  
Installed mosquitto server that serve subscruptions and publish of messages  
Installed Homebridge server with mqtt plugin to support IOS homekit app  
And created a service that will inject mqtt messaged to the database  
