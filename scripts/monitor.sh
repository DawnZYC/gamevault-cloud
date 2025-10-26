#!/bin/bash

# ==========================================
# GameVault 微服务监控脚本
# ==========================================

set -e

# 颜色定义
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

# 检查 Docker 是否运行
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker 未运行或无法访问"
        exit 1
    fi
}

# 检查服务健康状态
check_service_health() {
    local service_name=$1
    local port=$2
    local health_path=${3:-"/actuator/health"}
    
    log_info "检查 $service_name 服务健康状态..."
    
    if curl -s -f "http://localhost:$port$health_path" > /dev/null 2>&1; then
        log_success "$service_name 服务运行正常 (端口: $port)"
        return 0
    else
        log_error "$service_name 服务异常 (端口: $port)"
        return 1
    fi
}

# 检查 Docker 容器状态
check_container_status() {
    log_info "检查 Docker 容器状态..."
    
    # 获取所有 gamevault 相关容器
    local containers=$(docker ps --filter "name=gamevault" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}")
    
    if [ -n "$containers" ]; then
        echo "$containers"
        
        # 检查是否有容器退出
        local exited_containers=$(docker ps -a --filter "name=gamevault" --filter "status=exited" --format "{{.Names}}")
        if [ -n "$exited_containers" ]; then
            log_warning "以下容器已退出:"
            echo "$exited_containers"
        fi
    else
        log_warning "未找到 gamevault 相关容器"
    fi
}

# 检查服务端口
check_ports() {
    log_info "检查服务端口占用情况..."
    
    local ports=(80 8080 8081 8082 8083 8084 8089 5432 6379 8848 9000)
    
    for port in "${ports[@]}"; do
        if netstat -tuln | grep -q ":$port "; then
            log_success "端口 $port 正在监听"
        else
            log_warning "端口 $port 未监听"
        fi
    done
}

# 检查磁盘空间
check_disk_space() {
    log_info "检查磁盘空间..."
    
    local usage=$(df -h /opt/gamevault 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//')
    
    if [ -n "$usage" ]; then
        if [ "$usage" -gt 90 ]; then
            log_error "磁盘空间不足: ${usage}% 已使用"
        elif [ "$usage" -gt 80 ]; then
            log_warning "磁盘空间警告: ${usage}% 已使用"
        else
            log_success "磁盘空间正常: ${usage}% 已使用"
        fi
    else
        log_warning "无法检查磁盘空间"
    fi
}

# 检查内存使用
check_memory() {
    log_info "检查内存使用情况..."
    
    local memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    log_info "内存使用率: ${memory_usage}%"
    
    if (( $(echo "$memory_usage > 90" | bc -l) )); then
        log_error "内存使用率过高: ${memory_usage}%"
    elif (( $(echo "$memory_usage > 80" | bc -l) )); then
        log_warning "内存使用率较高: ${memory_usage}%"
    else
        log_success "内存使用正常: ${memory_usage}%"
    fi
}

# 检查日志文件
check_logs() {
    log_info "检查最近的错误日志..."
    
    local log_dir="/opt/gamevault/logs"
    
    if [ -d "$log_dir" ]; then
        # 查找最近 5 分钟的错误日志
        find "$log_dir" -name "*.log" -mmin -5 -exec grep -l "ERROR\|FATAL" {} \; 2>/dev/null | while read -r logfile; do
            if [ -f "$logfile" ]; then
                log_warning "发现错误日志: $logfile"
                echo "最近的错误:"
                tail -5 "$logfile" | grep "ERROR\|FATAL" || true
            fi
        done
    else
        log_warning "日志目录不存在: $log_dir"
    fi
}

# 显示服务状态摘要
show_summary() {
    log_info "=== GameVault 服务状态摘要 ==="
    
    # 检查各个微服务
    local services=(
        "Gateway:8080"
        "Auth:8081"
        "Shopping:8082"
        "Forum:8083"
        "Developer:8084"
        "Social:8089"
    )
    
    local healthy_count=0
    local total_count=${#services[@]}
    
    for service in "${services[@]}"; do
        IFS=':' read -r name port <<< "$service"
        if check_service_health "$name" "$port" > /dev/null 2>&1; then
            ((healthy_count++))
        fi
    done
    
    echo ""
    log_info "健康服务: $healthy_count/$total_count"
    
    if [ "$healthy_count" -eq "$total_count" ]; then
        log_success "所有微服务运行正常！"
    elif [ "$healthy_count" -gt 0 ]; then
        log_warning "部分服务异常，请检查日志"
    else
        log_error "所有服务都异常！"
    fi
}

# 主函数
main() {
    echo "=========================================="
    echo "    GameVault 微服务监控脚本"
    echo "=========================================="
    echo ""
    
    check_docker
    check_container_status
    echo ""
    
    check_ports
    echo ""
    
    check_disk_space
    check_memory
    echo ""
    
    check_logs
    echo ""
    
    show_summary
    echo ""
    
    log_info "监控完成"
}

# 如果直接运行脚本
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
