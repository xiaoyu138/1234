#!/bin/bash

# =================配置区域=================
# 请在GitHub上修改下面的用户和仓库名为你自己的
GITHUB_USER="xiaoyu138"
REPO_NAME="1234"
BRANCH="main"
# =========================================

echo "=================================================="
echo "   XMRig 自动化部署脚本 - 正在开始安装..."
echo "=================================================="

# 1. 检查并安装基础依赖
echo "[*] 更新系统并安装依赖 (wget, tar, curl)..."
if [ -x "$(command -v apt-get)" ]; then
    sudo apt-get update -qq
    sudo apt-get install -y -qq wget tar curl
elif [ -x "$(command -v yum)" ]; then
    sudo yum update -y -q
    sudo yum install -y -q wget tar curl
fi

# 2. 下载 XMRig 官方静态内核
# 使用官方 GitHub Releases 保证安全性
VERSION="6.22.2"
FILE="xmrig-${VERSION}-linux-static-x64.tar.gz"
DOWNLOAD_URL="https://github.com/xmrig/xmrig/releases/download/v${VERSION}/${FILE}"

echo "[*] 正在下载 XMRig v${VERSION}..."
if [ ! -d "miner" ]; then
    mkdir miner
fi
cd miner

if [ ! -f "xmrig" ]; then
    wget -q --show-progress $DOWNLOAD_URL
    echo "[*] 解压中..."
    tar -xf $FILE
    # 将解压出的文件移动到当前目录
    cp xmrig-${VERSION}/xmrig .
    rm -rf xmrig-${VERSION}*
    rm -f $FILE
fi

# 3. 下载配置文件
# 从你的 GitHub 仓库拉取 config.json
CONFIG_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO_NAME}/${BRANCH}/config.json"
echo "[*] 从 GitHub 拉取配置文件: ${CONFIG_URL}"
curl -sSL $CONFIG_URL -o config.json

# 检查配置文件是否下载成功
if grep -q "83ipf" config.json; then
    echo "[+] 配置文件验证成功 (钱包地址已确认)"
else
    echo "[-] 错误: 配置文件下载失败或内容不正确，请检查 GitHub 用户名和仓库名是否正确！"
    exit 1
fi

# 4. 配置 Huge Pages (提升算力)
echo "[*] 正在配置 Huge Pages..."
sudo sysctl -w vm.nr_hugepages=128 > /dev/null

# 5. 设置 Systemd 服务 (开机自启 + 后台运行)
SERVICE_FILE="/etc/systemd/system/mining_service.service"
WORK_DIR=$(pwd)

echo "[*] 创建 Systemd 服务..."
sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=Mining Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$WORK_DIR
ExecStart=$WORK_DIR/xmrig --config=$WORK_DIR/config.json
Restart=always
RestartSec=15s
Nice=10
CPUWeight=80

[Install]
WantedBy=multi-user.target
EOF

# 6. 启动服务
echo "[*] 启动服务..."
chmod +x xmrig
sudo systemctl daemon-reload
sudo systemctl enable mining_service.service
sudo systemctl start mining_service.service

# 7. 检查状态
sleep 3
if systemctl is-active --quiet mining_service.service; then
    echo "=================================================="
    echo "   [成功] 挖矿程序已在后台运行！"
    echo "   - 查看日志命令: sudo journalctl -u mining_service -f"
    echo "   - 停止运行命令: sudo systemctl stop mining_service"
    echo "=================================================="
else
    echo "[-] 服务启动失败，请使用 'sudo journalctl -u mining_service' 检查错误。"
fi
