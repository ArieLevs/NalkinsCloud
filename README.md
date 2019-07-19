NalkinsCloud
============
This is an IOT Automation project, 
it will provide the ability to monitor and control indoor\outdoor devices from anywhere.
Project uses server side written in python, 
hardware written in C++ based on the ESP8266 chip, 
android application in Java, and small NodeJS server to support IOS clients.

![](docs/NalkingCloudDiagram.png)

Getting started
---------------
What will you do:
* Choose Hardware   - Use [Raspberry Pi](https://www.raspberrypi.org/learning/hardware-guide/) 
    with [Raspbian](https://www.raspberrypi.org/downloads/raspbian/)
    or VM/PC with [Centos7](https://www.centos.org/download/) as your server.
* Rest API          - Setup [Django](https://www.djangoproject.com/).
* Database          - Setup [MariaDB server](https://mariadb.org/) to support all components.
* MQTT Broker       - Setup [Mosquitto server](https://mosquitto.org/), And set full TLS encryption.
* Mosquitto Auth    - Integrate [Mosquitto Auth-Plug](https://github.com/jpmens/mosquitto-auth-plug) to Mosquitto.
* Message Listener  - Setting up mqtt2db service, that will act as a listener injecting messages to database.
* Homebridge        - Setup [Homebridge Server](https://github.com/nfarina/homebridge) 
    With [MQTT support](https://github.com/cflurin/homebridge-mqtt) 
    so you could use iOS with this project.
* IOT Microchip     - Use various custom devices, that you will build yourself, 
    And clone [NalkinsCloud-ESP8266](https://github.com/ArieLevs/NalkinsCloud-ESP8266) to ESP8266.
* Android           - Clone [NalkinsCloud-Android](https://github.com/ArieLevs/NalkinsCloud-Android), 
    build apk and start controlling your devices.
* iOS               - Use Apple homekit application to control devices.


Installation
------------
All services and code in this example will setup on the same machine, Centos7 or Raspberry Pi 4.9.59-v7+

Start by installing Raspberry pi, 
download [RASPBIAN STRETCH LITE](https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2019-04-09/),
newer versions available [here](https://www.raspberrypi.org/downloads/raspbian/) but are not supported (docker installation issues),  
And create micro-sd with that image, 
([Check this for MacOS](https://www.raspberrypi.org/documentation/installation/installing-images/mac.md), 
or use [Rufus](https://rufus.ie/) for windows).  
Based on: Linux raspberrypi 4.9.59-v7+ # armv7l GNU/Linux

For setting up the project on Centos7 OS [Download iso image](https://www.centos.org/download/),
If you need assistance to make the USB installation [use this guide](https://wiki.centos.org/HowTos/InstallFromUSBkey).  
Based on: CentOS Linux 7 Kernel: Linux 3.10.0-693.5.2.el7.x86_64

- For additional assistance please search on how to install the OS

#### If you choose Raspberry Pi you will need to configure it for SSH use
Please read [this guild](https://github.com/ArieLevs/NalkinsCloud/blob/master/README_Raspberry.md)

### Before you begin
If you use registered domain name and not dynamic IP address, 
I strongly recommend using Letsencrypt certificates instead of self-signed,
If you do not have registered domain, 
I recommend using DDNS services as [no-ip](https://www.noip.com/remote-access), 
This will allow you to use your own domain name pointing to your local WAN address,
by installing an agent on the server (or even your router), 
the agent will constantly sync your dynamic ip address,
so you will have access from public internet.

### Project installation
First [install Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) on your machine.  
Clone repository:
```bash
git clone https://github.com/ArieLevs/NalkinsCloud.git
```

* You can update `vim NalkinsCloud/group_vars/all`, if vars are not updated, defaults will be installed.
* Update `inventory` file, with relevant address of the destination installation,
  So if the host was set to `192.168.0.10` as shown before, set this value.
```bash
ansible-playbook --inventory-file inventory \
    --ask-become-pass --become --user [USERNAME] \
    -e"mosquitto_host=[MOSQUITTO_HOST_GROUP] \
    database_host=[DB_HOST_GROUP] \
    django_hoss=[DJANGO_HOST_GROUP] \
    mqtt_simulators_host=[SIMULATORS_HOST_GROUP]" \
    NalkinsCloud/nalkinscloud_deploy.yml \
    --key-file "[SSH_KEY]" -v
```

* if using default init raspberry installation use:
```bash
ansible-playbook --inventory-file inventory \
    --user pi --ask-pass \
    -e mosquitto_host=nalkinscloud_mosquitto \
    -e database_host=nalkinscloud_database \
    -e django_host=nalkinscloud_django \
    -e mqtt_simulators_host=nalkinscloud_simulators \
    nalkinscloud_deploy.yml -v
```

#### Important:
Once installation finished successfully, save all passwords from **NalkinsCloud/group_vars/all** file, 
I recommend using password management application like [MacPass](https://github.com/MacPass/MacPass) 
or [KeePass](https://keepass.info/) for windows, 
Then you **PERMANENTLY** remove these password.

Post Installation
-----------------
Ansible will store a .bks file at `/tmp/[MOSUITTO_HOST]/etc/ssl/certs` on your local machine (by default),  
This file will later be needed in order for the android app to work.

Go to `Application` page in django admin, *Please change domain with relevant IP\Domain*.
	https://www.nalkins.cloud/admin/oauth2_provider/application/add/ 
```
Choose:
	Client type: Confidential
	Authorization grant type: Resource owner password-based
	Name: Android (To your choice)
	
	And save
```
We have just created an application so django can serve clients  
Please note for 'Client id' and 'Client secret' which are important for our clients to receive tokens.

### Setting up ESP8266 device
Please walkthrough [NalkinsCloud-ESP8266](https://github.com/ArieLevs/NalkinsCloud-ESP8266)

### Android Application
Please walkthrough [NalkinsCloud-Android](https://github.com/ArieLevs/NalkinsCloud-Android)
