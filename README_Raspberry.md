# Raspberry pi installation

download [RASPBIAN STRETCH LITE](https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2019-04-09/),
newer versions available [here](https://www.raspberrypi.org/downloads/raspbian/) 
but are not supported (docker installation issues),
  
Create micro-sd with that image, 
([Check this for MacOS](https://www.raspberrypi.org/documentation/installation/installing-images/mac.md), 
or use [Rufus](https://rufus.ie/) for windows).  
Based on: Linux raspberrypi 4.9.59-v7+ # armv7l GNU/Linux

## Prepare os
Connect the Raspberry Pi to a monitor and keyboard,  
Or copy an empty file named `ssh` to the root of the raspberry SD to allow ssh connections by default:

Default login user is `pi` and password is `raspberry`, Change the password:  
Type `passwd`  
Add user to sudoers and start ssh service
```
sudo usermod -aG sudo pi
sudo systemctl enable ssh
sudo systemctl start ssh
```

If you wish to use Wi-Fi connection please [Connect Raspberry using Wi-Fi](https://www.raspberrypi.org/documentation/configuration/wireless/wireless-cli.md),  
Else connect Raspberry via LAN cable to one of your router ports.  
 
* optional: install VIM editor (Internet connection needed) `sudo apt-get install vim`  
  Allow mouse right click to past clipboard to terminal on vim editor
```
sudo vim /usr/share/vim/vim81/defaults.vim
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
Then `sudo reboot`  
Now SSH to the Respberry with 192.168.0.10, Then you could leave your pi near the router

secure the connection:
```
cd $HOME
ssh-keygen
```
OK so now we have two files: id_rsa and id_rsa.pub at `$HOME/.ssh` directory
	
The id_rsa (private key) should be moved to the client (To each machine you will be connecting the Raspberry from, AND KEPT SECURE)
```
cat $HOME/.ssh/id_rsa.pub >> $HOME/.ssh/authorized_keys #add the key
chmod 600 $HOME/.ssh/authorized_keys
```
Disable password connection `sudo vim /etc/ssh/sshd_config`  
Change `ChallengeResponseAuthentification no` to `PasswordAuthentification no` and save the file.  
Finally run `sudo service ssh reload`

* If using [putty](http://www.putty.org/) to ssh, open puttygen and convert the private key (id_rsa) to .ppk file (import key then save as private key)
	
Set up firewall:
```
sudo apt-get install ufw
sudo ufw allow ssh
sudo ufw enable
```