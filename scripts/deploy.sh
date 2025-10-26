#!/bin/bash

# GameVault 微服务部署脚本
# 用于在 EC2 Ubuntu 上部署整个微服务系统

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "请不要使用 root 用户运行此脚本"
        exit 1
    fi
}

# 检查系统要求
check_system() {
    log_info "检查系统要求..."
    
    # 检查操作系统
    if ! grep -q "Ubuntu" /etc/os-release; then
        log_error "此脚本仅支持 Ubuntu 系统"
        exit 1
    fi
    
    # 检查内存
    MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$MEMORY_GB" -lt 4 ]; then
        log_warning "建议至少 4GB 内存，当前: ${MEMORY_GB}GB"
    fi
    
    # 检查磁盘空间
    DISK_GB=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
    if [ "$DISK_GB" -lt 20 ]; then
        log_warning "建议至少 20GB 磁盘空间，当前可用: ${DISK_GB}GB"
    fi
    
    log_success "系统检查完成"
}

# 安装 Docker
install_docker() {
    log_info "安装 Docker..."
    
    if command -v docker &> /dev/null; then
        log_info "Docker 已安装，跳过安装步骤"
        return
    fi
    
    # 更新包索引
    sudo apt-get update
    
    # 安装必要的包
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # 添加 Docker 官方 GPG 密钥
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # 设置仓库
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # 安装 Docker Engine
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # 将当前用户添加到 docker 组
    sudo usermod -aG docker $USER
    
    # 启动 Docker 服务
    sudo systemctl start docker
    sudo systemctl enable docker
    
    log_success "Docker 安装完成"
}

# 安装 Docker Compose
install_docker_compose() {
    log_info "检查 Docker Compose..."
    
    if command -v docker compose &> /dev/null; then
        log_success "Docker Compose 已安装"
        return
    fi
    
    # 安装 Docker Compose V2
    sudo apt-get install -y docker-compose-plugin
    
    log_success "Docker Compose 安装完成"
}

# 安装其他必要工具
install_tools() {
    log_info "安装必要工具..."
    
    sudo apt-get update
    sudo apt-get install -y \
        curl \
        wget \
        git \
        htop \
        tree \
        unzip \
        jq \
        ufw
    
    log_success "工具安装完成"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."
    
    # 启用 UFW
    sudo ufw --force enable
    
    # 允许 SSH
    sudo ufw allow ssh
    
    # 允许 HTTP 和 HTTPS
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    
    # 允许应用端口 (可选，如果直接访问)
    sudo ufw allow 8080/tcp comment "GameVault Gateway"
    
    log_success "防火墙配置完成"
}

# 创建应用目录
create_directories() {
    log_info "创建应用目录..."
    
    # 创建主目录
    sudo mkdir -p /opt/gamevault
    sudo chown $USER:$USER /opt/gamevault
    
    # 创建数据目录
    sudo mkdir -p /opt/gamevault/data/{postgres,redis,nacos,minio}
    sudo mkdir -p /opt/gamevault/logs
    sudo mkdir -p /opt/gamevault/uploads
    sudo mkdir -p /opt/gamevault/ssl
    
    # 设置权限
    sudo chown -R $USER:$USER /opt/gamevault
    
    log_success "目录创建完成"
}

# 创建环境配置文件
create_env_config() {
    log_info "创建环境配置..."
    
    cat > /opt/gamevault/.env << EOF
# GameVault 生产环境配置

# 数据库配置
POSTGRES_DB=gamevault
POSTGRES_USER=gamevault_user
POSTGRES_PASSWORD=gamevault_pass

# Redis 配置
REDIS_PASSWORD=redis_pass

# Nacos 配置
NACOS_AUTH_TOKEN=SecretKey012345678901234567890123456789012345678901234567890123456789

# MinIO 配置
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin123

# 应用配置
SPRING_PROFILES_ACTIVE=prod
TZ=Asia/Singapore

# 日志级别
LOG_LEVEL=INFO
EOF

    log_success "环境配置创建完成"
}

# 创建 systemd 服务文件
create_systemd_service() {
    log_info "创建 systemd 服务..."
    
    sudo tee /etc/systemd/system/gamevault.service > /dev/null << EOF
[Unit]
Description=GameVault Microservices
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/gamevault
ExecStart=/usr/bin/docker compose -f docker-compose.prod.yml up -d
ExecStop=/usr/bin/docker compose -f docker-compose.prod.yml down
TimeoutStartSec=0
User=$USER
Group=$USER

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable gamevault.service
    
    log_success "systemd 服务创建完成"
}

# 创建监控脚本
create_monitoring_script() {
    log_info "创建监控脚本..."
    
    cat > /opt/gamevault/monitor.sh << 'EOF'
#!/bin/bash

# GameVault 服务监控脚本

echo "=== GameVault 服务状态 ==="
echo "时间: $(date)"
echo

echo "=== Docker 容器状态 ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo
echo "=== 服务健康检查 ==="

# 检查网关
if curl -s -f http://localhost:8080/actuator/health > /dev/null; then
    echo "✅ Gateway: 健康"
else
    echo "❌ Gateway: 不健康"
fi

# 检查认证服务
if curl -s -f http://localhost:8081/actuator/health > /dev/null; then
    echo "✅ Auth: 健康"
else
    echo "❌ Auth: 不健康"
fi

# 检查购物服务
if curl -s -f http://localhost:8082/actuator/health > /dev/null; then
    echo "✅ Shopping: 健康"
else
    echo "❌ Shopping: 不健康"
fi

# 检查论坛服务
if curl -s -f http://localhost:8083/actuator/health > /dev/null; then
    echo "✅ Forum: 健康"
else
    echo "❌ Forum: 不健康"
fi

# 检查开发者服务
if curl -s -f http://localhost:8084/actuator/health > /dev/null; then
    echo "✅ Developer: 健康"
else
    echo "❌ Developer: 不健康"
fi

# 检查社交服务
if curl -s -f http://localhost:8089/actuator/health > /dev/null; then
    echo "✅ Social: 健康"
else
    echo "❌ Social: 不健康"
fi

echo
echo "=== 系统资源使用 ==="
echo "内存使用:"
free -h

echo
echo "磁盘使用:"
df -h /

echo
echo "Docker 资源使用:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
EOF

    chmod +x /opt/gamevault/monitor.sh
    
    log_success "监控脚本创建完成"
}

# 创建备份脚本
create_backup_script() {
    log_info "创建备份脚本..."
    
    cat > /opt/gamevault/backup.sh << 'EOF'
#!/bin/bash

# GameVault 数据备份脚本

BACKUP_DIR="/opt/gamevault/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

echo "开始备份 GameVault 数据..."

# 备份 PostgreSQL 数据
echo "备份数据库..."
docker exec gamevault-postgres pg_dumpall -U gamevault_user > $BACKUP_DIR/postgres_backup_$DATE.sql

# 备份 Redis 数据
echo "备份 Redis 数据..."
docker exec gamevault-redis redis-cli --rdb /data/dump.rdb
docker cp gamevault-redis:/data/dump.rdb $BACKUP_DIR/redis_backup_$DATE.rdb

# 备份上传文件
echo "备份上传文件..."
tar -czf $BACKUP_DIR/uploads_backup_$DATE.tar.gz -C /opt/gamevault uploads/

# 备份配置文件
echo "备份配置文件..."
tar -czf $BACKUP_DIR/config_backup_$DATE.tar.gz -C /opt/gamevault docker-compose.prod.yml .env nginx/

echo "备份完成: $BACKUP_DIR"
EOF

    chmod +x /opt/gamevault/backup.sh
    
    log_success "备份脚本创建完成"
}

# 主函数
main() {
    log_info "开始部署 GameVault 微服务系统..."
    
    check_root
    check_system
    install_docker
    install_docker_compose
    install_tools
    configure_firewall
    create_directories
    create_env_config
    create_systemd_service
    create_monitoring_script
    create_backup_script
    
    log_success "部署准备完成！"
    log_info "请将以下文件复制到 /opt/gamevault/ 目录："
    log_info "- docker-compose.prod.yml"
    log_info "- nginx/ 目录"
    log_info "- scripts/ 目录"
    log_info ""
    log_info "然后运行以下命令启动服务："
    log_info "cd /opt/gamevault"
    log_info "docker compose -f docker-compose.prod.yml up -d"
    log_info ""
    log_info "或者使用 systemd 服务："
    log_info "sudo systemctl start gamevault"
    log_info ""
    log_info "监控服务状态："
    log_info "/opt/gamevault/monitor.sh"
}

# 运行主函数
main "$@"
