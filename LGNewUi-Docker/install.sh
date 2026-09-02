#!/bin/bash
set -e

REPO_URL="https://github.com/Freewind72/LGNewUi-Docker.git"
TEMP_DIR="LGNewUi-Docker"
ZIP_URL="https://cdn.jsdelivr.net/gh/Freewind72/jsbat@main/LGNewUi-Docker/loaders.zip"

echo "=========================================="
echo "LGNewUi Docker 部署脚本"
echo "=========================================="

if [ -d "$TEMP_DIR" ]; then
    echo "清理已存在的临时目录..."
    rm -rf "$TEMP_DIR"
fi

echo "从 GitHub 拉取 Docker 配置文件..."
git clone "$REPO_URL"

echo "移动文件到当前目录..."
cp -r "$TEMP_DIR"/* .
cp -r "$TEMP_DIR"/.* . 2>/dev/null || true

echo "清理临时目录..."
rm -rf "$TEMP_DIR"

if [ -f "loaders/ixed.8.0.lin" ]; then
    echo "检测到 loaders/ixed.8.0.lin 已存在，跳过下载..."
else
    echo "创建 loaders 目录..."
    mkdir -p loaders

    if command -v unzip >/dev/null 2>&1; then
        echo "下载并解压 loaders.zip..."
        curl -fsSL "$ZIP_URL" -o loaders.zip
        unzip -o loaders.zip -d .
        rm -f loaders.zip
    else
        echo "未检测到 unzip，尝试使用 Python 解压..."
        if command -v python3 >/dev/null 2>&1; then
            curl -fsSL "$ZIP_URL" -o loaders.zip
            python3 -c "import zipfile; zipfile.ZipFile('loaders.zip').extractall('.')"
            rm -f loaders.zip
        else
            echo "错误：未安装 unzip 或 python3，无法解压 loaders.zip"
            echo "请手动安装 unzip：apt-get install unzip"
            exit 1
        fi
    fi
fi

echo "停止并删除旧容器..."
docker stop lgnewui-zeph 2>/dev/null || true
docker rm lgnewui-zeph 2>/dev/null || true

echo "构建并启动新容器..."
docker-compose up -d --build

echo "=========================================="
echo "部署完成！"
docker ps | grep lgnewui-zeph || echo "容器未运行，请检查日志"
echo "=========================================="
