#!/bin/bash
set -e  # 遇到错误立即退出

echo "=== AstraMC 部署脚本 ==="

# 1. 保存 SSH 私钥
echo "1. 保存 SSH 私钥..."
cat > /tmp/deploy_key << 'EOF'
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACCweehg4FIvISDA+2a3+09ke2uy28m1afhpJL+tiHOoQAAAAJjJorevyaK3
rwAAAAtzc2gtZWQyNTUxOQAAACCweehg4FIvISDA+2a3+09ke2uy28m1afhpJL+tiHOoQA
AAAEDzV1rRs3yWMlJxK4mjGIDQHXqIHPSMQvx4H6n3q8bg8LB56GDgUi8hIMD7Zrf7T2R7
a7LbybVp+Gkkv62Ic6hAAAAAEDMwMzg4ODYzODBxcS5jb20BAgMEBQ==
-----END OPENSSH PRIVATE KEY-----
EOF

# 2. 设置密钥权限
echo "2. 设置密钥权限..."
chmod 600 /tmp/deploy_key
chown $(whoami):$(whoami) /tmp/deploy_key 2>/dev/null || true

# 3. 配置 SSH 代理
echo "3. 配置 SSH 代理..."
eval $(ssh-agent -s)
ssh-add /tmp/deploy_key

# 4. 测试 GitHub 连接
echo "4. 测试 GitHub 连接..."
ssh -T -o StrictHostKeyChecking=no -i /tmp/deploy_key git@github.com 2>&1 | grep -v "successfully authenticated" || true

# 5. 进入部署目录
echo "5. 进入部署目录 /opt..."
cd /opt

# 6. 克隆仓库
echo "6. 克隆 AstraMC 仓库..."
if [ -d "AstraMC" ]; then
    echo "  检测到已存在的 AstraMC 目录，正在删除..."
    rm -rf AstraMC
fi

GIT_SSH_COMMAND="ssh -i /tmp/deploy_key -o StrictHostKeyChecking=no" \
git clone git@github.com:Freewind72/AstraMC.git

# 7. 进入项目目录
echo "7. 进入项目目录..."
cd AstraMC

# 8. 检查 Dockerfile
echo "8. 检查项目结构..."
ls -la

# 9. 构建 Docker 镜像
echo "9. 构建 Docker 镜像..."
if [ -f "Dockerfile" ]; then
    echo "  找到 Dockerfile，开始构建镜像..."
    docker build -t astramc .
else
    echo "  未找到 Dockerfile，跳过构建步骤"
    echo "  请确保 'astramc' 镜像已存在或使用其他镜像"
fi

# 10. 停止并删除旧容器（如果存在）
echo "10. 清理旧容器..."
docker stop astramc-container 2>/dev/null || true
docker rm astramc-container 2>/dev/null || true

# 11. 运行 Docker 容器
echo "11. 启动 Docker 容器..."
if docker images | grep -q "astramc"; then
    echo "  使用自定义镜像 astramc..."
    docker run -d \
      -p 8080:80 \
      -v $(pwd)/sql:/var/www/html/sql \
      -v $(pwd)/uploads:/var/www/html/uploads \
      --name astramc-container \
      astramc
else
    echo "  使用 PHP Apache 官方镜像..."
    docker run -d \
      -p 8080:80 \
      -v $(pwd):/var/www/html \
      -v $(pwd)/sql:/var/www/html/sql \
      -v $(pwd)/uploads:/var/www/html/uploads \
      --name astramc-container \
      php:apache
fi

# 12. 检查容器状态
echo "12. 检查容器状态..."
sleep 3  # 等待容器启动
docker ps | grep astramc-container

# 13. 清理临时文件
echo "13. 清理临时文件..."
rm -f /tmp/deploy_key
kill $SSH_AGENT_PID 2>/dev/null || true

# 14. 显示部署信息
echo "=== 部署完成 ==="
echo "容器名称: astramc-container"
echo "访问地址: http://localhost:8080"
echo "查看日志: docker logs astramc-container"
echo "停止容器: docker stop astramc-container"
echo "启动容器: docker start astramc-container"
echo "进入容器: docker exec -it astramc-container bash"
