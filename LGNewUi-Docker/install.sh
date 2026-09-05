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

# ============================================
# 检测服务器位置，选择构建镜像源
# ============================================
echo "检测服务器位置..."
COUNTRY=$(curl -s --connect-timeout 3 https://ipinfo.io/country 2>/dev/null || echo "UNKNOWN")

if [ "$COUNTRY" = "CN" ]; then
    echo "检测到国内服务器，测试镜像源延迟..."
    
    ALIYUN_TIME=$(curl -s -o /dev/null -w "%{time_total}" --connect-timeout 3 -r 0-1023 https://mirrors.aliyun.com 2>/dev/null || echo "999")
    TENCENT_TIME=$(curl -s -o /dev/null -w "%{time_total}" --connect-timeout 3 -r 0-1023 https://mirrors.tencent.com 2>/dev/null || echo "999")
    
    ALIYUN_MS=$(awk "BEGIN {printf \"%.0f\", $ALIYUN_TIME * 1000}")
    TENCENT_MS=$(awk "BEGIN {printf \"%.0f\", $TENCENT_TIME * 1000}")
    
    echo "阿里云镜像 (mirrors.aliyun.com): ${ALIYUN_MS}ms"
    echo "腾讯云镜像 (mirrors.tencent.com): ${TENCENT_MS}ms"
    
    if [ "$ALIYUN_MS" -le "$TENCENT_MS" ]; then
        export APT_MIRROR="mirrors.aliyun.com"
        echo "选择阿里云镜像源"
    else
        export APT_MIRROR="mirrors.tencent.com"
        echo "选择腾讯云镜像源"
    fi
else
    echo "检测到海外服务器 (${COUNTRY})，使用官方源"
    export APT_MIRROR="deb.debian.org"
fi

test_latency() {
    local url=$1
    local time=$(curl -fsSL -r 0-1023 -o /dev/null -w "%{time_total}" --connect-timeout 3 --max-time 3 "$url" 2>/dev/null)
    if [ -n "$time" ] && [ "$time" != "0" ]; then
        local ms=$(awk "BEGIN {printf \"%.0f\", $time * 1000}")
        if [ "$ms" -ge 3000 ]; then
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

echo "CDN1 (jsDelivr)      延迟: ${LATENCY1}ms"
echo "CDN2 (GitHub Raw)     延迟: ${LATENCY2}ms"
echo "CDN3 (jasonzeng)      延迟: ${LATENCY3}ms"
echo "CDN4 (gh-proxy)       延迟: ${LATENCY4}ms"
echo "CDN5 (gh-proxy v4)    延迟: ${LATENCY5}ms"
echo "CDN6 (gh-proxy v6)    延迟: ${LATENCY6}ms"
echo "CDN7 (gh-proxy cdn)   延迟: ${LATENCY7}ms"
echo "CDN8 (gh-proxy axisnow) 延迟: ${LATENCY8}ms"

# 找出最低延迟作为推荐
MIN_LATENCY=$LATENCY1
BEST_CDN="1"
if [ "$LATENCY2" -lt "$MIN_LATENCY" ]; then MIN_LATENCY=$LATENCY2; BEST_CDN="2"; fi
if [ "$LATENCY3" -lt "$MIN_LATENCY" ]; then MIN_LATENCY=$LATENCY3; BEST_CDN="3"; fi
if [ "$LATENCY4" -lt "$MIN_LATENCY" ]; then MIN_LATENCY=$LATENCY4; BEST_CDN="4"; fi
if [ "$LATENCY5" -lt "$MIN_LATENCY" ]; then MIN_LATENCY=$LATENCY5; BEST_CDN="5"; fi
if [ "$LATENCY6" -lt "$MIN_LATENCY" ]; then MIN_LATENCY=$LATENCY6; BEST_CDN="6"; fi
if [ "$LATENCY7" -lt "$MIN_LATENCY" ]; then MIN_LATENCY=$LATENCY7; BEST_CDN="7"; fi
if [ "$LATENCY8" -lt "$MIN_LATENCY" ]; then MIN_LATENCY=$LATENCY8; BEST_CDN="8"; fi

echo ""
echo "请选择下载线路 (推荐 CDN${BEST_CDN}):"
echo "  [1] jsDelivr         ${LATENCY1}ms"
echo "  [2] GitHub Raw       ${LATENCY2}ms"
echo "  [3] jasonzeng        ${LATENCY3}ms"
echo "  [4] gh-proxy         ${LATENCY4}ms"
echo "  [5] gh-proxy v4      ${LATENCY5}ms"
echo "  [6] gh-proxy v6      ${LATENCY6}ms"
echo "  [7] gh-proxy cdn     ${LATENCY7}ms"
echo "  [8] gh-proxy axisnow ${LATENCY8}ms"
echo -n "输入数字 (1-8) 或直接回车选择推荐: "
read -r CHOICE

case "${CHOICE:-$BEST_CDN}" in
    1) CONFIG_ZIP_URL="$CDN1"; CDN_NAME="CDN1 (jsDelivr)" ;;
    2) CONFIG_ZIP_URL="$CDN2"; CDN_NAME="CDN2 (GitHub Raw)" ;;
    3) CONFIG_ZIP_URL="$CDN3"; CDN_NAME="CDN3 (jasonzeng)" ;;
    4) CONFIG_ZIP_URL="$CDN4"; CDN_NAME="CDN4 (gh-proxy)" ;;
    5) CONFIG_ZIP_URL="$CDN5"; CDN_NAME="CDN5 (gh-proxy v4)" ;;
    6) CONFIG_ZIP_URL="$CDN6"; CDN_NAME="CDN6 (gh-proxy v6)" ;;
    7) CONFIG_ZIP_URL="$CDN7"; CDN_NAME="CDN7 (gh-proxy cdn)" ;;
    8) CONFIG_ZIP_URL="$CDN8"; CDN_NAME="CDN8 (gh-proxy axisnow)" ;;
    *) echo "无效输入，使用推荐 CDN${BEST_CDN}"; CONFIG_ZIP_URL="$CDN${BEST_CDN}" ;;
esac

echo "已选择: $CDN_NAME"

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

if [ ! -f .env ]; then
    echo "错误：未检测到 .env 配置文件，安装终止"
    echo "请确保项目包中包含 .env 文件"
    exit 1
fi

echo "停止并删除旧容器..."
docker compose down 2>/dev/null || true

echo "构建并启动新容器..."
docker-compose up -d --build

echo "清理临时文件..."
echo "白名单保留: docker-compose.yml, Dockerfile, .env"
if [ -f LGNewUi.zip ]; then
    unzip -l LGNewUi.zip 2>/dev/null | tail -n +4 | head -n -2 | awk '{print $NF}' | while read -r file; do
        case "$file" in
            docker-compose.yml|Dockerfile|.env)
                echo "保留: $file"
                ;;
            *)
                echo "删除: $file"
                rm -f "$file"
                ;;
        esac
    done
    rm -f LGNewUi.zip
fi
rm -f install.sh

echo "=========================================="
echo "部署完成！"
docker ps | grep lgnewui_zeph || echo "容器未运行，请检查日志"
echo "=========================================="