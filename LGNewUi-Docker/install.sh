#!/bin/bash
set -e

CONFIG_ZIP_URL="https://cdn.jsdelivr.net/gh/Freewind72/jsbat@main/LGNewUi-Docker/LGNewUi.zip"
TEMP_DIR="LGNewUi-Docker"

echo "=========================================="
echo "LGNewUi Docker 部署脚本"
echo "=========================================="

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

echo "移动文件到当前目录..."
cp -r "$TEMP_DIR"/* .
cp -r "$TEMP_DIR"/.* . 2>/dev/null || true

echo "停止并删除旧容器..."
docker stop lgnewui-zeph 2>/dev/null || true
docker rm lgnewui-zeph 2>/dev/null || true

echo "构建并启动新容器..."
docker-compose up -d --build

echo "清理临时文件..."
rm -f LGNewUi.zip
rm -rf "$TEMP_DIR"

echo "=========================================="
echo "部署完成！"
docker ps | grep lgnewui-zeph || echo "容器未运行，请检查日志"
echo "=========================================="