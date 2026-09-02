#!/bin/bash
set -e

REPO_URL="https://github.com/Freewind72/LGNewUi-Docker.git"
TEMP_DIR="LGNewUi-Docker"

echo "=========================================="
echo "LGNewUi Docker 部署脚本"
echo "=========================================="

if [ -d "$TEMP_DIR" ]; then
    echo "检测到已存在的临时目录，正在清理..."
    rm -rf "$TEMP_DIR"
fi

echo "正在从 GitHub 拉取最新代码..."
git clone "$REPO_URL"

echo "正在移动文件到当前目录..."
cp -r "$TEMP_DIR"/* .
cp -r "$TEMP_DIR"/.* . 2>/dev/null || true

echo "正在清理临时目录..."
rm -rf "$TEMP_DIR"

echo "正在停止并删除旧容器..."
docker stop lgnewui-zeph 2>/dev/null || true
docker rm lgnewui-zeph 2>/dev/null || true

echo "正在构建并启动新容器..."
docker-compose up -d --build

echo "=========================================="
echo "部署完成！"
echo "容器状态:"
docker ps | grep lgnewui-zeph || echo "容器未运行，请检查日志"
echo "=========================================="