#!/bin/bash
# 预置OpenClash内核和地理数据库

mkdir -p files/etc/openclash/core

CLASH_DEV_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/dev/clash-linux-${1}.tar.gz"
CLASH_TUN_URL=$(curl -fsSL https://api.github.com/repos/vernesong/OpenClash/contents/master/premium\?ref\=core | grep download_url | grep $1 | awk -F '"' '{print $4}' | grep -v 'v3')
CLASH_META_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-${1}.tar.gz"
GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"

echo "正在下载 OpenClash 内核文件..."
wget -qO- $CLASH_DEV_URL | tar xOvz > files/etc/openclash/core/clash
if [ $? -eq 0 ]; then
    echo "✅ dev内核下载成功"
else
    echo "❌ dev内核下载失败"
fi

wget -qO- $CLASH_TUN_URL | gunzip -c > files/etc/openclash/core/clash_tun
if [ $? -eq 0 ]; then
    echo "✅ tun内核下载成功"
else
    echo "❌ tun内核下载失败"
fi

wget -qO- $CLASH_META_URL | tar xOvz > files/etc/openclash/core/clash_meta
if [ $? -eq 0 ]; then
    echo "✅ meta内核下载成功"
else
    echo "❌ meta内核下载失败"
fi

echo "正在下载 GeoIP 和 GeoSite 数据库..."
wget -qO- $GEOIP_URL > files/etc/openclash/GeoIP.dat
if [ $? -eq 0 ]; then
    echo "✅ GeoIP.dat下载成功"
else
    echo "❌ GeoIP.dat下载失败"
fi

wget -qO- $GEOSITE_URL > files/etc/openclash/GeoSite.dat
if [ $? -eq 0 ]; then
    echo "✅ GeoSite.dat下载成功"
else
    echo "❌ GeoSite.dat下载失败"
fi

chmod +x files/etc/openclash/core/clash*
echo "✅ OpenClash 内核和数据库预置完成"
