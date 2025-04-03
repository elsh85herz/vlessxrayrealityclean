#!/bin/bash

# We clear the console
clear

scriptversion="0.9.1"
xrayversion="1.8.7"

echo "=========================================================================
|       Fast VLESS XTLS Reality script by @MohsenHNSJ (Github)          |
=========================================================================
|                             Thanks to                                 |
| @SasukeFreestyle (Github) for original tutorial => 'XTLS-Iran-Reality'|
=========================================================================
Check out the github page, contribute and suggest ideas/bugs/improvments.

This script uses the xray $xrayversion version!
========================
| Script version $scriptversion |
========================"

# We want to create a folder to store logs of each action for easier debug in case of an error
# We first must check if it already exists or not
# If it does exist, that means the core is already running and installation is not needed
if [ -d "/FastReality" ]
then
    echo "FastReality is already configured! Cheking xray core version..."
    installedxrayversion=$(cat "/FastReality/xrayversion.txt")
    if [ "$installedxrayversion" == "$xrayversion" ]
    then
            echo "Xray core is up-to-date!"
            echo "No action is needed, exiting..."
    else 
            echo "Xray core has updates! updating..."
    fi
    exit
else
    mkdir /FastReality
fi

echo "=========================================================================
|       Updating repositories and installing the required packages      |
|              (This may take a few minutes, Please wait...)            |
========================================================================="
# We update 'apt' repository 
# We need to install 'unzip' package to extract zip files
# We need to install 'openssl' package for generating short id
# We need to install 'sshpass' package to switch user
# We need to install 'qrencode' package for generating and showing the qr code
# This installation must run without confirmation (-y)
sudo apt update &> /FastReality/log.txt
sudo apt -y install unzip openssl sshpass qrencode &>> /FastReality/log.txt

# We generate a random name for the new user
choose() { echo ${1:RANDOM%${#1}:1} $RANDOM; }
username="$({ choose 'abcdefghijklmnopqrstuvwxyz'
  for i in $( seq 1 $(( 6 + RANDOM % 4 )) )
     do
        choose 'abcdefghijklmnopqrstuvwxyz'
     done
 } | sort -R | awk '{printf "%s",$1}')"

# We generate a random password for the new user
# We avoid adding symbols inside the password as it sometimes caused problems, therefore the password lenght is high
choose() { echo ${1:RANDOM%${#1}:1} $RANDOM; }
password="$({ choose '123456789'
  choose 'abcdefghijklmnopqrstuvwxyz'
  choose 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  for i in $( seq 1 $(( 18 + RANDOM % 4 )) )
     do
        choose '123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
     done
 } | sort -R | awk '{printf "%s",$1}')"

echo "=========================================================================
|                  Adding a new user and configuring                    |
========================================================================="
# We create a new user
adduser --gecos "" --disabled-password $username &>> /FastReality/log.txt

# We set a password for the new user
chpasswd <<<"$username:$password"

# We grant root privileges to the new user
usermod -aG sudo $username

# We save the new user credentials to use after switching user
# We first must check if it already exists or not
# If it does exist, we must delete it and make a new one to store new temporary data
if [ -d "/tempfolder" ]
then
    rm -r /tempfolder
    sudo mkdir /tempfolder
else
    sudo mkdir /tempfolder
fi

echo $username > /tempfolder/tempusername.txt
echo $password > /tempfolder/temppassword.txt

# We transfer ownership of the temp and log folder to the new user, so the new user is able to add more logs and delete the senstive information when it's no longer needed
sudo chown -R $username /tempfolder/
sudo chown -R $username /FastReality/

echo "=========================================================================
|                       Optimizing server settings                      |
========================================================================="

# We optimise 'sysctl.conf' file for better performance
sudo echo "net.ipv4.tcp_keepalive_time = 90
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_fastopen = 3
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
fs.file-max = 65535000" >> /etc/sysctl.conf

# We optimise 'limits.conf' file for better performance
sudo echo "* soft     nproc          655350
* hard     nproc          655350
* soft     nofile         655350
* hard     nofile         655350
root soft     nproc          655350
root hard     nproc          655350
root soft     nofile         655350
root hard     nofile         655350" >> /etc/security/limits.conf

# We apply the changes
sudo sysctl -p &>> /FastReality/log.txt

echo "=========================================================================
|                         Creating xray service                         |
========================================================================="

# We create a service file
sudo echo "[Unit]
Description=XTLS Xray-Core a VMESS/VLESS Server
After=network.target nss-lookup.target
[Service]
User=$username
Group=$username
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/home/$username/xray/xray run -config /home/$username/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
StandardOutput=journal
LimitNPROC=100000
LimitNOFILE=1000000
[Install]
WantedBy=multi-user.target" > /etc/systemd/system/xray.service

echo "=========================================================================
|                           Switching user                              |
========================================================================="
# We now switch to the new user
sshpass -p $password ssh -o "StrictHostKeyChecking=no" $username@127.0.0.1

# We read the saved credentials
tempusername=$(</tempfolder/tempusername.txt)
temppassword=$(</tempfolder/temppassword.txt)

# We delete senstive inforamtion
rm /tempfolder/tempusername.txt
rm /tempfolder/temppassword.txt

# We provide password to 'sudo' command and open port 443
echo $temppassword | sudo -S ufw allow 443

# We create directory to hold xray files
mkdir xray

# We navigate to directory we created
cd xray/

echo "=========================================================================
|                 Downloading xray and required files                   |
========================================================================="

# We download latest geoasset file for blocking iranian websites
wget https://github.com/bootmortis/iran-hosted-domains/releases/latest/download/iran.dat &>> /FastReality/log.txt

# We download xray 1.8.6
wget https://github.com/XTLS/Xray-core/releases/download/v1.8.7/Xray-linux-64.zip &>> /FastReality/log.txt

# We extract xray core
unzip Xray-linux-64.zip &>> /FastReality/log.txt

# We remove downloaded file
rm Xray-linux-64.zip

# We generate a random secret for generating a random uuid
choose() { echo ${1:RANDOM%${#1}:1} $RANDOM; }
secret="$({ choose '123456789'
  choose 'abcdefghijklmnopqrstuvwxyz'
  choose 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  for i in $( seq 1 $(( 16 + RANDOM % 4 )) )
     do
        choose '123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
     done
 } | sort -R | awk '{printf "%s",$1}')"

# We generate a random uuid
generateduuid=$(./xray uuid -i $secret)

# We generate public and private keys and temporarily save them
temp=$(./xray x25519)

# We extract private key
temp2="${temp#Private key: }"
privatekey=`echo "${temp2}" | head -1`

# We extract the public key
temp3="${temp2#$privatekey}"
publickey="${temp3#*Public key: }"

# We generate a short id
shortid=$(openssl rand -hex 8)

echo "=========================================================================
|                         Configuring xray                              |
========================================================================="

# We restart the service and enable auto-start
sudo systemctl daemon-reload && sudo systemctl enable xray

# We store the path of the 'config.json' file
configfile=/home/$tempusername/xray/config.json

# We create a 'config.json' file
# We needed a slight change at line 2143 (1981 in the original 'config.json' file) to properly enter double escape character (\\ => \\\\) inside the config file
cat > $configfile << EOL
{
   "log":{
      "loglevel":"warning"
   },
   "policy":{
      "levels":{
         "0":{
            "handshake":3,
            "connIdle":180
         }
      }
   },
   "inbounds":[
      {
         "listen":"0.0.0.0",
         "port":443,
         "protocol":"vless",
         "settings":{
            "clients":[
               {
                  "id":"$generateduuid",
                  "flow":"xtls-rprx-vision"
               }
            ],
            "decryption":"none"
         },
         "streamSettings":{
            "network":"tcp",
            "security":"reality",
            "realitySettings":{
               "show":false,
               "dest":"www.google-analytics.com:443",
               "xver":0,
               "serverNames":[
                  "www.google-analytics.com"
               ],
               "privateKey":"$privatekey",
               "minClientVer":"1.8.0",
               "maxClientVer":"",
               "maxTimeDiff":0,
               "shortIds":[
                  "$shortid"
               ]
            }
         },
         "sniffing":{
            "enabled":true,
            "destOverride":[
               "http",
               "tls",
               "quic"
            ]
         }
      }
   ],
   "outbounds":[
      {
         "protocol":"freedom",
         "tag":"direct"
      },
      {
         "protocol":"blackhole",
         "tag":"block"
      }
   ]
}
EOL

echo "=========================================================================
|                           Starting xray                               |
========================================================================="

# We now start xray service
sudo systemctl start xray && sudo systemctl status xray &>> /FastReality/log.txt

# We get VPS IP
vpsip=$(hostname -I | awk '{ print $1}')

echo "=========================================================================
|                                DONE                                   |
========================================================================="

# We VPS name
hostname=$('hostname')

# We show connection information
echo "
REMARKS: $hostname
ADDRESS: $vpsip
PORT: 443
ID: $generateduuid
FLOW: xtls-rprx-vision
ENCRYPTION: none
NETWORK: TCP
HEAD TYPE: none
TLS: reality
SNI: www.google-analytics.com
FINGERPRINT: randomized
PUBLIC KEY: $publickey
SHORT ID: $shortid
==========
PRIVATE KEY: $privatekey
LOCAL USERNAME: $tempusername
LOCAL PASSWORD : $temppassword
"

echo "=========================================================================
|                               QRCODE                                  |
========================================================================="

serverconfig="vless://$generateduuid@$vpsip:443?security=reality&encryption=none&pbk=$publickey&headerType=none&fp=randomized&type=tcp&flow=xtls-rprx-vision&sni=www.google-analytics.com&sid=$shortid#$hostname"

# We output a QRCode to ease connection
qrencode -t ansiutf8 $serverconfig

# We now save the xray core version we have installed
echo "$xrayversion" > /FastReality/xrayversion.txt
