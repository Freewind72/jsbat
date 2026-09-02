#!/bin/bash
set -e

REPO_URL="https://github.com/Freewind72/LGNewUi-Docker.git"
TEMP_DIR="LGNewUi-Docker"
LOADER_URL="https://raw.githubusercontent.com/Freewind72/jsbat/main/LGNewUi-Docker/loaders/ixed.8.0.lin"

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

echo "创建 loaders 目录并下载 SourceGuardian Loader..."
mkdir -p loaders
curl -fsSL "$LOADER_URL" -o loaders/ixed.8.0.lin

echo "停止并删除旧容器..."
docker stop lgnewui-zeph 2>/dev/null || true
docker rm lgnewui-zeph 2>/dev/null || true

echo "构建并启动新容器..."
docker-compose up -d --build

echo "=========================================="
echo "部署完成！"
docker ps | grep lgnewui-zeph || echo "容器未运行，请检查日志"
echo "=========================================="