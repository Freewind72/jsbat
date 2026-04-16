#!/bin/bash

# AstraMC 一键安装脚本
set -e  # 遇到错误时退出

echo "========================================"
echo "    AstraMC 一键安装脚本"
echo "========================================"

# 检查是否以root用户运行
if [ "$EUID" -ne 0 ]; then 
    echo "请使用 root 用户运行此脚本"
    echo "请执行: sudo bash $0"
    exit 1
fi

# 检查必要命令是否存在
for cmd in docker git ssh-agent ssh-add; do
    if ! command -v $cmd &> /dev/null; then
        echo "错误: 未找到 $cmd 命令"
        echo "请先安装 Docker 和 Git"
        exit 1
    fi
done

# 定义变量
WORK_DIR="/opt"
DEPLOY_KEY="/tmp/deploy_key"
REPO_URL="git@github.com:Freewind72/AstraMC.git"
CONTAINER_NAME="astramc-container"
IMAGE_NAME="astramc"
PORT="8080"

# 清理函数
cleanup() {
    echo "正在清理临时文件..."
    if [ -f "$DEPLOY_KEY" ]; then
        rm -f "$DEPLOY_KEY"
    fi
    # 停止并移除ssh-agent
    if [ -n "$SSH_AGENT_PID" ]; then
        kill $SSH_AGENT_PID 2>/dev/null || true
    fi
}

# 设置trap确保脚本退出时清理
trap cleanup EXIT

echo "步骤 1/7: 创建部署密钥..."
cat > "$DEPLOY_KEY" << 'EOF'
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACCweehg4FIvISDA+2a3+09ke2uy28m1afhpJL+tiHOoQAAAAJjJorevyaK3
rwAAAAtzc2gtZWQyNTUxOQAAACCweehg4FIvISDA+2a3+09ke2uy28m1afhpJL+tiHOoQA
AAAEDzV1rRs3yWMlJxK4mjGIDQHXqIHPSMQvx4H6n3q8bg8LB56GDgUi8hIMD7Zrf7T2R7
a7LbybVp+Gkkv62Ic6hAAAAAEDMwMzg4ODYzODBxcS5jb20BAgMEBQ==
-----END OPENSSH PRIVATE KEY-----
EOF

chmod 600 "$DEPLOY_KEY"
echo "✓ 部署密钥已创建"

echo "步骤 2/7: 设置SSH代理..."
eval $(ssh-agent -s) > /dev/null
ssh-add "$DEPLOY_KEY" 2>/dev/null
echo "✓ SSH代理已设置"

echo "步骤 3/7: 切换到工作目录 $WORK_DIR..."
cd "$WORK_DIR"
echo "✓ 已切换到 $WORK_DIR"

echo "步骤 4/7: 克隆代码仓库..."
GIT_SSH_COMMAND="ssh -i $DEPLOY_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
if git clone "$REPO_URL" 2>/dev/null; then
    echo "✓ 代码仓库克隆成功"
else
    echo "✗ 代码仓库克隆失败"
    echo "请检查:"
    echo "1. 部署密钥是否有权限访问仓库"
    echo "2. 网络连接是否正常"
    exit 1
fi

echo "步骤 5/7: 进入项目目录并构建Docker镜像..."
cd AstraMC
if docker build -t "$IMAGE_NAME" . 2>/dev/null; then
    echo "✓ Docker镜像构建成功"
else
    echo "✗ Docker镜像构建失败"
    echo "请检查Dockerfile是否存在且正确"
    exit 1
fi

echo "步骤 6/7: 检查是否已有同名容器运行..."
if docker ps -a --filter "name=$CONTAINER_NAME" | grep -q "$CONTAINER_NAME"; then
    echo "检测到已存在容器 $CONTAINER_NAME"
    read -p "是否停止并删除现有容器? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
        echo "✓ 旧容器已清理"
    else
        echo "请手动处理现有容器后重新运行脚本"
        exit 1
    fi
fi

echo "步骤 7/7: 启动Docker容器..."
# 创建必要的目录
mkdir -p sql uploads

if docker run -d \
    -p "$PORT":80 \
    -v "$(pwd)/sql:/var/www/html/sql" \
    -v "$(pwd)/uploads:/var/www/html/uploads" \
    --name "$CONTAINER_NAME" \
    "$IMAGE_NAME" 2>/dev/null; then
    
    echo "✓ Docker容器启动成功"
    
    # 检查容器状态
    sleep 2
    if docker ps --filter "name=$CONTAINER_NAME" | grep -q "$CONTAINER_NAME"; then
        echo "========================================"
        echo "安装完成!"
        echo "容器名称: $CONTAINER_NAME"
        echo "镜像名称: $IMAGE_NAME"
        echo "访问地址: http://localhost:$PORT"
        echo "数据目录:"
        echo "  - SQL文件: $(pwd)/sql"
        echo "  - 上传文件: $(pwd)/uploads"
        echo ""
        echo "管理命令:"
        echo "  查看日志: docker logs $CONTAINER_NAME"
        echo "  进入容器: docker exec -it $CONTAINER_NAME bash"
        echo "  停止容器: docker stop $CONTAINER_NAME"
        echo "  启动容器: docker start $CONTAINER_NAME"
        echo "  重启容器: docker restart $CONTAINER_NAME"
        echo "========================================"
    else
        echo "⚠ 容器已创建但未运行"
        echo "请检查: docker logs $CONTAINER_NAME"
    fi
else
    echo "✗ Docker容器启动失败"
    exit 1
fi

# 清理临时文件
cleanup
