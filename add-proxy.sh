#!/bin/bash
mkdir -p bin
wget -O bin/zivpn-proxy https://github.com/OfficialOnePesewa/zivpn-proxy/releases/download/v1.0.0/zivpn-proxy-linux-amd64
chmod +x bin/zivpn-proxy
git add bin/zivpn-proxy
git commit -m "Add ZIVPN device binding proxy binary"
git push origin main
