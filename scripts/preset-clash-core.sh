#!/bin/bash
# 预置OpenClash内核和地理数据库（增强版）

set -e

# 创建目录
mkdir -p files/etc/openclash/core

# 架构参数
ARCH="${1:-amd64}"
echo "目标架构: $ARCH"

# 定义URL
CLASH_DEV_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/dev/clash-linux-${ARCH}.tar.gz"
CLASH_META_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-${ARCH}.tar.gz"
GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"

# 获取TUN内核URL（使用更稳定的方法）
CLASH_TUN_URL=$(curl -fsSL "https://api.github.com/repos/vernesong/OpenClash/contents/master/premium?ref=core" | \
    grep -o '"download_url":"[^"]*"' | \
    grep -o 'https://[^"]*' | \
    grep -v 'v3' | \
    grep "${ARCH}" | \
    head -1)

echo "TUN内核URL: $CLASH_TUN_URL"

# 带重试的下载函数（针对tar.gz）
function download_tar_gz() {
    local url=$1
    local output=$2
    local name=$3
    local max_retries=3
    local retry_count=0
    local temp_file="/tmp/temp_${name}.tar.gz"
    
    while [ $retry_count -lt $max_retries ]; do
        echo "正在下载 $name (尝试 $((retry_count+1))/$max_retries)..."
        
        # 下载到临时文件
        if wget -q --timeout=30 --tries=2 -O "$temp_file" "$url"; then
            # 检查文件大小（小于1MB可能不完整）
            local file_size=$(stat -c%s "$temp_file" 2>/dev/null || stat -f%z "$temp_file" 2>/dev/null || echo "0")
            if [ "$file_size" -gt 1000000 ]; then
                # 解压到目标文件
                if tar xOz "$temp_file" > "$output" 2>/dev/null; then
                    chmod +x "$output"
                    echo "✅ $name 下载成功 (大小: $((file_size/1024/1024))MB)"
                    rm -f "$temp_file"
                    return 0
                else
                    echo "⚠️  $name 解压失败，文件可能损坏"
                fi
            else
                echo "⚠️  $name 文件大小异常 ($file_size bytes)"
            fi
        else
            echo "⚠️  $name 下载失败"
        fi
        
        retry_count=$((retry_count + 1))
        rm -f "$temp_file"
        sleep 3
    done
    
    echo "❌ $name 下载失败，已重试 $max_retries 次"
    return 1
}

# 带重试的gunzip下载函数（针对tun内核）
function download_gunzip() {
    local url=$1
    local output=$2
    local name=$3
    local max_retries=3
    local retry_count=0
    local temp_file="/tmp/temp_${name}.gz"
    
    if [ -z "$url" ]; then
        echo "❌ $name URL为空，跳过下载"
        return 1
    fi
    
    while [ $retry_count -lt $max_retries ]; do
        echo "正在下载 $name (尝试 $((retry_count+1))/$max_retries)..."
        
        if wget -q --timeout=30 --tries=2 -O "$temp_file" "$url"; then
            local file_size=$(stat -c%s "$temp_file" 2>/dev/null || stat -f%z "$temp_file" 2>/dev/null || echo "0")
            if [ "$file_size" -gt 1000000 ]; then
                if gunzip -c "$temp_file" > "$output" 2>/dev/null; then
                    chmod +x "$output"
                    echo "✅ $name 下载成功 (大小: $((file_size/1024/1024))MB)"
                    rm -f "$temp_file"
                    return 0
                else
                    echo "⚠️  $name 解压失败"
                fi
            else
                echo "⚠️  $name 文件大小异常 ($file_size bytes)"
            fi
        else
            echo "⚠️  $name 下载失败"
        fi
        
        retry_count=$((retry_count + 1))
        rm -f "$temp_file"
        sleep 3
    done
    
    echo "❌ $name 下载失败"
    return 1
}

# 下载普通文件（GeoIP/GeoSite）
function download_file() {
    local url=$1
    local output=$2
    local name=$3
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        echo "正在下载 $name (尝试 $((retry_count+1))/$max_retries)..."
        
        if wget -q --timeout=30 --tries=2 -O "$output" "$url"; then
            local file_size=$(stat -c%s "$output" 2>/dev/null || stat -f%z "$output" 2>/dev/null || echo "0")
            if [ "$file_size" -gt 1000000 ]; then
                echo "✅ $name 下载成功 (大小: $((file_size/1024/1024))MB)"
                return 0
            else
                echo "⚠️  $name 文件大小异常 ($file_size bytes)"
            fi
        else
            echo "⚠️  $name 下载失败"
        fi
        
        retry_count=$((retry_count + 1))
        rm -f "$output"
        sleep 3
    done
    
    echo "❌ $name 下载失败"
    return 1
}

# 执行下载
echo "=========================================="
echo "开始下载 OpenClash 内核和数据库文件"
echo "=========================================="

# 下载dev内核
download_tar_gz "$CLASH_DEV_URL" "files/etc/openclash/core/clash" "dev内核" || true

# 下载tun内核
download_gunzip "$CLASH_TUN_URL" "files/etc/openclash/core/clash_tun" "tun内核" || true

# 下载meta内核
download_tar_gz "$CLASH_META_URL" "files/etc/openclash/core/clash_meta" "meta内核" || true

# 下载GeoIP
download_file "$GEOIP_URL" "files/etc/openclash/GeoIP.dat" "GeoIP数据库" || true

# 下载GeoSite
download_file "$GEOSITE_URL" "files/etc/openclash/GeoSite.dat" "GeoSite数据库" || true

echo "=========================================="
echo "下载完成，检查文件..."
ls -lh files/etc/openclash/core/ 2>/dev/null || echo "core目录为空"
ls -lh files/etc/openclash/*.dat 2>/dev/null || echo "dat文件不存在"
echo "=========================================="
