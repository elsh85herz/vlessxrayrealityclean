#!/bin/bash

# Fast VLESS XTLS Reality script (cleaned for RU use)

export DEBIAN_FRONTEND=noninteractive

echo "==================================================================="
echo "|                    Updating and Installing tools                |"
echo "==================================================================="
apt update && apt upgrade -y
apt install qrencode curl wget unzip sudo -y

UUID=$(uuidgen)
USERNAME=$(tr -dc a-z </dev/urandom | head -c 8)
XRAY_DIR="/home/$USERNAME/xray"
XRAY_URL=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep browser_download_url | grep linux-64 | cut -d '"' -f 4)
XRAY_FILE=$(basename "$XRAY_URL")
SNI="www.google-analytics.com"
SHORT_ID=$(openssl rand -hex 8)

echo "==================================================================="
echo "|                 Creating user and working directory             |"
echo "==================================================================="
useradd -m -s /bin/bash "$USERNAME"
mkdir -p "$XRAY_DIR"
cd "$XRAY_DIR" || exit 1

echo "==================================================================="
echo "|                    Downloading xray and required files          |"
echo "==================================================================="
wget "$XRAY_URL"
tar -xvzf "$XRAY_FILE"
rm "$XRAY_FILE"

echo "==================================================================="
echo "|                    Generating reality keys                      |"
echo "==================================================================="
KEYS=$(./xray x25519)
PRIVATE_KEY=$(echo "$KEYS" | grep "Private" | awk '{print $3}')
PUBLIC_KEY=$(echo "$KEYS" | grep "Public" | awk '{print $3}')

echo "==================================================================="
echo "|                         Configuring xray                        |"
echo "==================================================================="
cat <<EOF >"$XRAY_DIR/config.json"
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "$SNI:443",
          "xver": 0,
          "serverNames": ["$SNI"],
          "privateKey": "$PRIVATE_KEY",
          "minClientVer": "1.8.0",
          "maxClientVer": "",
          "maxTimeDiff": 0,
          "shortIds": ["$SHORT_ID"]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ]
}
EOF

echo "==================================================================="
echo "|                           Creating service                      |"
echo "==================================================================="
cat <<EOF >/etc/systemd/system/xray.service
[Unit]
Description=Xray Service
After=network.target

[Service]
User=$USERNAME
ExecStart=$XRAY_DIR/xray run -c $XRAY_DIR/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable xray
systemctl start xray

echo "==================================================================="
echo "|                          Service Started                        |"
echo "==================================================================="

REALITY_LINK="vless://$UUID@$(curl -s ifconfig.me):443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$SNI&fp=randomized&pbk=$PUBLIC_KEY&sid=$SHORT_ID&type=tcp&headerType=none#Reality"

echo -e "\nREMARKS: $HOSTNAME"
echo "ADDRESS: $(curl -s ifconfig.me)"
echo "PORT: 443"
echo "ID: $UUID"
echo "FLOW: xtls-rprx-vision"
echo "ENCRYPTION: none"
echo "NETWORK: TCP"
echo "HEAD TYPE: none"
echo "TLS: reality"
echo "SNI: $SNI"
echo "FINGERPRINT: randomized"
echo "PUBLIC KEY: $PUBLIC_KEY"
echo "SHORT ID: $SHORT_ID"
echo "=========="
echo "PRIVATE KEY: $PRIVATE_KEY"
echo "LOCAL USERNAME: $USERNAME"
echo "LOCAL PASSWORD : $(openssl rand -hex 12)"
echo -e "\n==================================================================="
echo "|                               QRCODE                            |"
echo "==================================================================="
qrencode -t ansiutf8 "$REALITY_LINK"

echo -e "\nDONE"
