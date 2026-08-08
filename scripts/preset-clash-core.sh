#!/bin/bash
# 预置OpenClash内核和地理数据库（代理版）

set -e

mkdir -p files/etc/openclash/core

ARCH="${1:-amd64}"
echo "目标架构: $ARCH"

# 使用代理（GitHub Actions 内置代理）
PROXY="https://ghproxy.com/"
# 或者使用其他代理
# PROXY="https://gh.api.99988866.xyz/"
# PROXY="https://github.moeyy.xyz/"

# 定义URL（使用代理）
CLASH_DEV_URL="${PROXY}https://raw.githubusercontent.com/vernesong/OpenClash/core/master/dev/clash-linux-${ARCH}.tar.gz"
CLASH_META_URL="${PROXY}https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-${ARCH}.tar.gz"
GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"

# TUN内核使用GitHub API获取（通过代理）
TUN_API_URL="${PROXY}https://api.github.com/repos/vernesong/OpenClash/contents/master/premium?ref=core"
CLASH_TUN_URL=$(curl -fsSL "$TUN_API_URL" | \
    grep -o '"download_url":"[^"]*"' | \
    grep -o 'https://[^"]*' | \
    grep -v 'v3' | \
    grep "${ARCH}" | \
    head -1)

# 如果代理获取失败，尝试直接获取
if [ -z "$CLASH_TUN_URL" ]; then
    echo "通过代理获取TUN URL失败，尝试直接获取..."
    CLASH_TUN_URL=$(curl -fsSL "https://api.github.com/repos/vernesong/OpenClash/contents/master/premium?ref=core" | \
        grep -o '"download_url":"[^"]*"' | \
        grep -o 'https://[^"]*' | \
        grep -v 'v3' | \
        grep "${ARCH}" | \
        head -1)
fi

echo "TUN内核URL: $CLASH_TUN_URL"

# 下载函数（使用代理）
function download_with_proxy() {
    local url=$1
    local output=$2
    local name=$3
    local max_retries=3
    local retry_count=0
    
    # 如果URL包含ghproxy，直接下载；否则尝试添加代理
    if [[ ! "$url" =~ "ghproxy" ]] && [[ ! "$url" =~ "github.moeyy" ]]; then
        # 尝试使用代理
        local proxy_url="${PROXY}${url}"
    else
        local proxy_url="$url"
    fi
    
    while [ $retry_count -lt $max_retries ]; do
        echo "正在下载 $name (尝试 $((retry_count+1))/$max_retries)..."
        
        # 使用wget下载
        if wget -q --timeout=60 --tries=2 -O "$output" "$proxy_url" 2>/dev/null; then
            local file_size=$(stat -c%s "$output" 2>/dev/null || stat -f%z "$output" 2>/dev/null || echo "0")
            if [ "$file_size" -gt 1000000 ]; then
                echo "✅ $name 下载成功 (大小: $((file_size/1024/1024))MB)"
                chmod +x "$output" 2>/dev/null || true
                return 0
            else
                echo "⚠️  $name 文件大小异常 ($file_size bytes)"
                rm -f "$output"
            fi
        else
            echo "⚠️  $name 下载失败"
        fi
        
        retry_count=$((retry_count + 1))
        sleep 5
    done
    
    echo "❌ $name 下载失败"
    return 1
}

echo "=========================================="
echo "开始下载 OpenClash 内核和数据库文件"
echo "=========================================="

# 下载dev内核（tar.gz格式）
if wget -q --timeout=60 --tries=2 -O "/tmp/dev.tar.gz" "$CLASH_DEV_URL" 2>/dev/null; then
    if tar xOz "/tmp/dev.tar.gz" > "files/etc/openclash/core/clash" 2>/dev/null; then
        chmod +x "files/etc/openclash/core/clash"
        echo "✅ dev内核 下载成功"
    else
        echo "❌ dev内核 解压失败"
    fi
    rm -f "/tmp/dev.tar.gz"
else
    echo "❌ dev内核 下载失败"
fi

# 下载meta内核（tar.gz格式）
if wget -q --timeout=60 --tries=2 -O "/tmp/meta.tar.gz" "$CLASH_META_URL" 2>/dev/null; then
    if tar xOz "/tmp/meta.tar.gz" > "files/etc/openclash/core/clash_meta" 2>/dev/null; then
        chmod +x "files/etc/openclash/core/clash_meta"
        echo "✅ meta内核 下载成功"
    else
        echo "❌ meta内核 解压失败"
    fi
    rm -f "/tmp/meta.tar.gz"
else
    echo "❌ meta内核 下载失败"
fi

# 下载tun内核（gz格式）
if [ -n "$CLASH_TUN_URL" ]; then
    if wget -q --timeout=60 --tries=2 -O "/tmp/tun.gz" "$CLASH_TUN_URL" 2>/dev/null; then
        if gunzip -c "/tmp/tun.gz" > "files/etc/openclash/core/clash_tun" 2>/dev/null; then
            chmod +x "files/etc/openclash/core/clash_tun"
            echo "✅ tun内核 下载成功"
        else
            echo "❌ tun内核 解压失败"
        fi
        rm -f "/tmp/tun.gz"
    else
        echo "❌ tun内核 下载失败"
    fi
else
    echo "❌ tun内核 URL为空，跳过下载"
fi

# 下载GeoIP
if wget -q --timeout=60 --tries=2 -O "files/etc/openclash/GeoIP.dat" "$GEOIP_URL" 2>/dev/null; then
    echo "✅ GeoIP数据库 下载成功"
else
    echo "❌ GeoIP数据库 下载失败"
fi

# 下载GeoSite
if wget -q --timeout=60 --tries=2 -O "files/etc/openclash/GeoSite.dat" "$GEOSITE_URL" 2>/dev/null; then
    echo "✅ GeoSite数据库 下载成功"
else
    echo "❌ GeoSite数据库 下载失败"
fi

echo "=========================================="
echo "下载完成，检查文件..."
ls -lh files/etc/openclash/core/ 2>/dev/null || echo "core目录为空"
ls -lh files/etc/openclash/*.dat 2>/dev/null || echo "dat文件不存在"
echo "=========================================="
