#!/bin/bash
set -e

CDN1="https://cdn.jsdelivr.net/gh/Freewind72/jsbat@main/LGNewUi-Docker/LGNewUi.zip"
CDN2="https://raw.githubusercontent.com/Freewind72/jsbat/main/LGNewUi-Docker/LGNewUi.zip"
CDN3="https://gh.jasonzeng.dev/https://raw.githubusercontent.com/Freewind72/jsbat/main/LGNewUi-Docker/LGNewUi.zip"
CDN4="https://gh-proxy.org/https://github.com/Freewind72/jsbat/blob/main/LGNewUi-Docker/LGNewUi.zip"
CDN5="https://v4.gh-proxy.org/https://github.com/Freewind72/jsbat/blob/main/LGNewUi-Docker/LGNewUi.zip"
CDN6="https://v6.gh-proxy.org/https://github.com/Freewind72/jsbat/blob/main/LGNewUi-Docker/LGNewUi.zip"
CDN7="https://cdn.gh-proxy.org/https://github.com/Freewind72/jsbat/blob/main/LGNewUi-Docker/LGNewUi.zip"
CDN8="https://axisnow.gh-proxy.org/https://github.com/Freewind72/jsbat/blob/main/LGNewUi-Docker/LGNewUi.zip"

echo "=========================================="
echo "LGNewUi Docker 部署脚本"
echo "=========================================="

echo "检测运行环境..."

if ! command -v docker >/dev/null 2>&1; then
    echo "错误：未检测到 Docker，请先安装 Docker"
    exit 1
fi

if command -v docker compose >/dev/null 2>&1; then
    echo "Docker Compose: 已安装 (docker compose)"
elif command -v docker-compose >/dev/null 2>&1; then
    echo "Docker Compose: 已安装 (docker-compose)"
else
    echo "Docker Compose 未安装，正在自动安装..."
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -fsSL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

    if command -v docker compose >/dev/null 2>&1; then
        echo "Docker Compose 安装成功 (docker compose)"
    elif command -v docker-compose >/dev/null 2>&1; then
        echo "Docker Compose 安装成功 (docker-compose)"
    else
        echo "自动安装失败，请手动安装："
        echo "  mkdir -p /usr/local/lib/docker/cli-plugins"
        echo "  curl -fsSL https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m) -o /usr/local/lib/docker/cli-plugins/docker-compose"
        echo "  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose"
        exit 1
    fi
fi

echo "环境检测通过"

test_latency() {
    local url=$1
    local time=$(curl -fsSL -r 0-1023 -o /dev/null -w "%{time_total}" --connect-timeout 5 --max-time 5 "$url" 2>/dev/null)
    if [ -n "$time" ] && [ "$time" != "0" ]; then
        local ms=$(awk "BEGIN {printf \"%.0f\", $time * 1000}")
        if [ "$ms" -ge 5000 ]; then
            echo 99999
        else
            echo "$ms"
        fi
    else
        echo 99999
    fi
}

echo "正在检测下载源延迟..."
LATENCY1=$(test_latency "$CDN1")
LATENCY2=$(test_latency "$CDN2")
LATENCY3=$(test_latency "$CDN3")
LATENCY4=$(test_latency "$CDN4")
LATENCY5=$(test_latency "$CDN5")
LATENCY6=$(test_latency "$CDN6")
LATENCY7=$(test_latency "$CDN7")
LATENCY8=$(test_latency "$CDN8")

echo "CDN1 (jsDelivr) 延迟: ${LATENCY1}ms"
echo "CDN2 (GitHub Raw) 延迟: ${LATENCY2}ms"
echo "CDN3 (jasonzeng) 延迟: ${LATENCY3}ms"
echo "CDN4 (gh-proxy) 延迟: ${LATENCY4}ms"
echo "CDN5 (gh-proxy v4) 延迟: ${LATENCY5}ms"
echo "CDN6 (gh-proxy v6) 延迟: ${LATENCY6}ms"
echo "CDN7 (gh-proxy cdn) 延迟: ${LATENCY7}ms"
echo "CDN8 (gh-proxy axisnow) 延迟: ${LATENCY8}ms"

MIN_LATENCY=$LATENCY1
CONFIG_ZIP_URL="$CDN1"
CDN_NAME="CDN1 (jsDelivr)"

if [ "$LATENCY2" -lt "$MIN_LATENCY" ]; then
    MIN_LATENCY=$LATENCY2
    CONFIG_ZIP_URL="$CDN2"
    CDN_NAME="CDN2 (GitHub Raw)"
fi

if [ "$LATENCY3" -lt "$MIN_LATENCY" ]; then
    MIN_LATENCY=$LATENCY3
    CONFIG_ZIP_URL="$CDN3"
    CDN_NAME="CDN3 (jasonzeng)"
fi

if [ "$LATENCY4" -lt "$MIN_LATENCY" ]; then
    MIN_LATENCY=$LATENCY4
    CONFIG_ZIP_URL="$CDN4"
    CDN_NAME="CDN4 (gh-proxy)"
fi

if [ "$LATENCY5" -lt "$MIN_LATENCY" ]; then
    MIN_LATENCY=$LATENCY5
    CONFIG_ZIP_URL="$CDN5"
    CDN_NAME="CDN5 (gh-proxy v4)"
fi

if [ "$LATENCY6" -lt "$MIN_LATENCY" ]; then
    MIN_LATENCY=$LATENCY6
    CONFIG_ZIP_URL="$CDN6"
    CDN_NAME="CDN6 (gh-proxy v6)"
fi

if [ "$LATENCY7" -lt "$MIN_LATENCY" ]; then
    MIN_LATENCY=$LATENCY7
    CONFIG_ZIP_URL="$CDN7"
    CDN_NAME="CDN7 (gh-proxy cdn)"
fi

if [ "$LATENCY8" -lt "$MIN_LATENCY" ]; then
    MIN_LATENCY=$LATENCY8
    CONFIG_ZIP_URL="$CDN8"
    CDN_NAME="CDN8 (gh-proxy axisnow)"
fi

echo "选择 $CDN_NAME"

extract_zip() {
    local zip_file=$1
    if command -v unzip >/dev/null 2>&1; then
        unzip -o "$zip_file" -d .
    else
        if command -v python3 >/dev/null 2>&1; then
            python3 -c "import zipfile; zipfile.ZipFile('$zip_file').extractall('.')"
        else
            echo "错误：未安装 unzip 或 python3，无法解压"
            echo "请手动安装 unzip：apt-get install unzip"
            exit 1
        fi
    fi
}

echo "下载 Docker 配置文件..."
curl -fsSL "$CONFIG_ZIP_URL" -o LGNewUi.zip

echo "解压 Docker 配置文件..."
extract_zip LGNewUi.zip

echo "停止并删除旧容器..."
docker compose down 2>/dev/null || true

echo "构建并启动新容器..."
docker-compose up -d --build

echo "清理临时文件..."
rm -f LGNewUi.zip
rm -f install.sh

echo "=========================================="
echo "部署完成！"
docker ps | grep lgnewui_zeph || echo "容器未运行，请检查日志"
echo "=========================================="