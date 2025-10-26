# GameVault 微服务部署指南

## 📋 概述

本指南将帮助你在 EC2 Ubuntu 上部署 GameVault 微服务系统，包括完整的 CI/CD 流程。

## 🏗️ 系统架构

### 微服务列表
- **gamevault-gateway** (8080) - API 网关
- **gamevault-auth** (8081) - 认证服务
- **gamevault-shopping** (8082) - 购物服务
- **gamevault-forum** (8083) - 论坛服务
- **gamevault-developer** (8084) - 开发者服务
- **gamevault-social** (8089) - 社交服务

### 基础设施服务
- **PostgreSQL** (5432) - 主数据库
- **Redis** (6379) - 缓存服务
- **Nacos** (8848) - 服务注册发现
- **MinIO** (9000) - 对象存储
- **Nginx** (80/443) - 反向代理

## 🚀 快速部署

### 1. EC2 实例要求

**最低配置：**
- CPU: 2 vCPU
- 内存: 4GB RAM
- 存储: 20GB SSD
- 操作系统: Ubuntu 20.04 LTS 或更高版本

**推荐配置：**
- CPU: 4 vCPU
- 内存: 8GB RAM
- 存储: 50GB SSD
- 操作系统: Ubuntu 22.04 LTS

### 2. 一键部署

```bash
# 1. 克隆仓库
git clone https://github.com/your-username/gamevault-cloud.git
cd gamevault-cloud

# 2. 运行部署脚本
chmod +x scripts/deploy.sh
./scripts/deploy.sh

# 3. 复制部署文件
sudo cp -r . /opt/gamevault/
sudo chown -R $USER:$USER /opt/gamevault

# 4. 启动服务
cd /opt/gamevault
docker compose -f docker-compose.prod.yml up -d
```

### 3. 验证部署

```bash
# 检查服务状态
/opt/gamevault/monitor.sh

# 检查网关健康状态
curl http://your-ec2-ip/health

# 检查所有服务
curl http://your-ec2-ip/api/auth/health
```

## 🔧 详细配置

### 1. 环境变量配置

编辑 `/opt/gamevault/.env` 文件：

```bash
# 数据库配置
POSTGRES_DB=gamevault
POSTGRES_USER=gamevault_user
POSTGRES_PASSWORD=your_secure_password

# Redis 配置
REDIS_PASSWORD=your_redis_password

# Nacos 配置
NACOS_AUTH_TOKEN=your_nacos_token

# MinIO 配置
MINIO_ROOT_USER=your_minio_user
MINIO_ROOT_PASSWORD=your_minio_password
```

### 2. 数据库初始化

```bash
# 进入 PostgreSQL 容器
docker exec -it gamevault-postgres psql -U gamevault_user -d gamevault

# 创建数据库
CREATE DATABASE gamevault_auth;
CREATE DATABASE gamevault_social;
CREATE DATABASE gamevault_shopping;
CREATE DATABASE gamevault_forum;
CREATE DATABASE gamevault_developer;
```

### 3. SSL 证书配置

```bash
# 创建 SSL 目录
mkdir -p /opt/gamevault/nginx/ssl

# 生成自签名证书（仅用于测试）
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /opt/gamevault/nginx/ssl/key.pem \
  -out /opt/gamevault/nginx/ssl/cert.pem

# 更新 nginx 配置启用 HTTPS
```

## 🔄 CI/CD 配置

### 1. GitHub Secrets 配置

在 GitHub 仓库设置中添加以下 Secrets：

```
EC2_HOST=your-ec2-public-ip
EC2_USER=ubuntu
EC2_SSH_KEY=your-private-ssh-key
GITHUB_TOKEN=your-github-token
```

### 2. 工作流程

**CI 流程：**
1. 代码质量检查
2. 单元测试
3. 安全扫描
4. 构建 Docker 镜像
5. 推送到 GitHub Container Registry

**CD 流程：**
1. 自动部署到 EC2
2. 健康检查
3. 服务监控
4. 回滚机制

### 3. 手动部署

```bash
# 拉取最新镜像
docker compose -f docker-compose.prod.yml pull

# 重启服务
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml up -d

# 清理旧镜像
docker image prune -f
```

## 📊 监控和维护

### 1. 服务监控

```bash
# 查看服务状态
/opt/gamevault/monitor.sh

# 查看日志
docker logs gamevault-gateway
docker logs gamevault-auth
# ... 其他服务

# 查看资源使用
docker stats
```

### 2. 数据备份

```bash
# 自动备份
/opt/gamevault/backup.sh

# 手动备份数据库
docker exec gamevault-postgres pg_dumpall -U gamevault_user > backup.sql

# 备份上传文件
tar -czf uploads_backup.tar.gz /opt/gamevault/uploads/
```

### 3. 日志管理

```bash
# 查看应用日志
tail -f /opt/gamevault/logs/*.log

# 清理旧日志
find /opt/gamevault/logs -name "*.log" -mtime +30 -delete
```

## 🔒 安全配置

### 1. 防火墙设置

```bash
# 允许必要端口
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### 2. SSL/TLS 配置

```bash
# 使用 Let's Encrypt 证书
sudo apt install certbot
sudo certbot certonly --standalone -d your-domain.com

# 更新 nginx 配置
sudo nano /opt/gamevault/nginx/nginx.conf
```

### 3. 数据库安全

```bash
# 修改默认密码
# 限制数据库访问
# 启用 SSL 连接
```

## 🚨 故障排除

### 1. 常见问题

**服务启动失败：**
```bash
# 检查日志
docker logs gamevault-gateway

# 检查端口占用
netstat -tlnp | grep :8080

# 检查资源使用
free -h
df -h
```

**数据库连接失败：**
```bash
# 检查数据库状态
docker exec gamevault-postgres pg_isready

# 检查网络连接
docker network ls
docker network inspect gamevault-cloud_gamevault-network
```

**内存不足：**
```bash
# 增加交换空间
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### 2. 性能优化

**JVM 参数调优：**
```bash
# 编辑 docker-compose.prod.yml
environment:
  JAVA_OPTS: "-Xms1g -Xmx2g -XX:+UseG1GC"
```

**数据库优化：**
```bash
# 调整 PostgreSQL 配置
# 增加连接池大小
# 优化查询
```

## 📚 相关文档

- [Docker Compose 文档](https://docs.docker.com/compose/)
- [Spring Cloud Gateway 文档](https://spring.io/projects/spring-cloud-gateway)
- [Nacos 文档](https://nacos.io/docs/latest/quick-start/)
- [PostgreSQL 文档](https://www.postgresql.org/docs/)

## 🤝 支持

如果遇到问题，请：

1. 查看日志文件
2. 检查服务状态
3. 参考故障排除部分
4. 提交 Issue 到 GitHub 仓库

---

**注意：** 本部署方案适用于生产环境，请根据实际需求调整配置参数。
