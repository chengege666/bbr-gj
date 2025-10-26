#!/bin/bash

# VPS一键管理脚本 v0.1
# 作者: 智能助手
# 最后更新: 2025-10-27

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # 重置颜色

# 显示菜单函数
show_menu() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "          VPS 脚本管理菜单 v0.1           "
    echo "=========================================="
    echo -e "${NC}"
    echo "1. 系统信息查询"
    echo "2. 系统更新"
    echo "3. 系统清理"
    echo "4. 基础工具"
    echo "5. BBR管理"
    echo "6. Docker管理"
    echo "7. 系统工具"
    echo "0. 退出脚本"
    echo "=========================================="
}

# -------------------------------
# root 权限检查
# -------------------------------
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}❌❌ 错误：请使用 root 权限运行本脚本${RESET}"
        echo "👉 使用方法: sudo bash $0"
        exit 1
    fi
}

# -------------------------------
# 依赖安装
# -------------------------------
install_deps() {
    PKGS="curl wget git speedtest-cli net-tools build-essential iptables"
    if command -v apt >/dev/null 2>&1; then
        apt update -y
        apt install -y $PKGS
    elif command -v yum >/dev/null 2>&1; then
        yum install -y $PKGS
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y $PKGS
    else
        echo -e "${YELLOW}⚠️ 未知系统，请手动安装依赖: $PKGS${RESET}"
        read -n1 -p "按任意键继续菜单..."
    fi
}

check_deps() {
    for CMD in curl wget git speedtest-cli iptables; do
        if ! command -v $CMD >/dev/null 2>&1; then
            echo -e "${YELLOW}未检测到 $CMD，正在尝试安装依赖...${RESET}"
            install_deps
            break
        fi
    done
}

# 检查BBR状态函数
check_bbr() {
    # 检查是否启用了BBR
    local bbr_enabled=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    local bbr_module=$(lsmod | grep bbr)
    
    # 获取默认队列算法
    local default_qdisc=$(sysctl net.core.default_qdisc | awk '{print $3}')
    
    # 获取BBR参数
    local bbr_params=$(sysctl -a 2>/dev/null | grep -E "bbr|tcp_congestion_control" | grep -v '^net.core' | sort)
    
    # 检查BBR版本
    local bbr_version=""
    if [[ "$bbr_enabled" == *"bbr"* ]]; then
        if [[ "$bbr_enabled" == "bbr" ]]; then
            bbr_version="BBR v1"
        elif [[ "$bbr_enabled" == "bbr2" ]]; then
            bbr_version="BBR v2"
        else
            bbr_version="未知BBR类型"
        fi
        
        # 返回BBR信息
        echo -e "${GREEN}已启用${NC} ($bbr_version)"
        echo -e "${BLUE}默认队列算法: ${NC}$default_qdisc"
        echo -e "${BLUE}BBR参数:${NC}"
        echo "$bbr_params" | while read -r line; do
            echo "  $line"
        done
    elif [[ -n "$bbr_module" ]]; then
        echo -e "${YELLOW}已加载但未启用${NC}"
        echo -e "${BLUE}默认队列算法: ${NC}$default_qdisc"
    else
        echo -e "${RED}未启用${NC}"
        echo -e "${BLUE}默认队列算法: ${NC}$default_qdisc"
    fi
}

# 系统信息查询函数
system_info() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "              系统信息查询                "
    echo "=========================================="
    echo -e "${NC}"

    # 1. 主机名
    echo -e "${BLUE}主机名: ${GREEN}$(hostname)${NC}"

    # 2. 操作系统版本
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        echo -e "${BLUE}操作系统: ${NC}$PRETTY_NAME"
    else
        echo -e "${BLUE}操作系统: ${NC}未知"
    fi

    # 3. 内核版本
    echo -e "${BLUE}内核版本: ${NC}$(uname -r)"

    # 4. CPU信息
    cpu_model=$(grep 'model name' /proc/cpuinfo | head -1 | cut -d ':' -f2 | sed 's/^ *//')
    cpu_cores=$(grep -c '^processor' /proc/cpuinfo)
    echo -e "${BLUE}CPU型号: ${NC}$cpu_model"
    echo -e "${BLUE}CPU核心数: ${NC}$cpu_cores"

    # 5. 内存信息
    total_mem=$(free -m | awk '/Mem:/ {print $2}')
    available_mem=$(free -m | awk '/Mem:/ {print $7}')
    echo -e "${BLUE}总内存: ${NC}${total_mem}MB"
    echo -e "${BLUE}可用内存: ${NC}${available_mem}MB"

    # 6. 硬盘信息
    disk_usage=$(df -h / | awk 'NR==2 {print $5}')
    disk_total=$(df -h / | awk 'NR==2 {print $2}')
    disk_used=$(df -h / | awk 'NR==2 {print $3}')
    echo -e "${BLUE}根分区使用率: ${NC}$disk_usage (已用 ${disk_used} / 总共 ${disk_total})"

    # 7. 公网IPv4地址
    ipv4=$(curl -s --connect-timeout 2 ipv4.icanhazip.com)
    if [ -z "$ipv4" ]; then
        ipv4=$(curl -s --connect-timeout 2 ipv4.ip.sb)
    fi
    if [ -z "$ipv4" ]; then
        ipv4="${RED}无法获取${NC}"
    else
        ipv4="${YELLOW}$ipv4${NC}"
    fi
    echo -e "${BLUE}公网IPv4: $ipv4"

    # 8. 公网IPv6地址
    ipv6=$(curl -s --connect-timeout 2 ipv6.icanhazip.com)
    if [ -z "$ipv6" ]; then
        ipv6=$(curl -s --connect-timeout 2 ipv6.ip.sb)
    fi
    if [ -z "$ipv6" ]; then
        ipv6="${RED}未检测到${NC}"
    else
        ipv6="${YELLOW}$ipv6${NC}"
    fi
    echo -e "${BLUE}公网IPv6: $ipv6"
    
    # 9. BBR状态
    echo -e "${BLUE}BBR状态: ${NC}"
    check_bbr

    # 10. 系统运行时间
    uptime_info=$(uptime -p | sed 's/up //')
    echo -e "${BLUE}系统运行时间: ${NC}$uptime_info"

    # 11. 当前时间（北京时间）
    beijing_time=$(TZ='Asia/Shanghai' date +'%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}北京时间: ${NC}$beijing_time"

    echo -e "${CYAN}"
    echo "=========================================="
    echo -e "${NC}"
    read -p "按回车键返回主菜单..."
}

# 主循环
main() {
    while true; do
        show_menu
        read -p "请输入选项编号: " choice
        
        case $choice in
            1)
                system_info
                ;;
            2|3|4|5|6|7)
                echo -e "${YELLOW}功能正在开发中，敬请期待！${NC}"
                sleep 1
                ;;
            0)
                echo -e "${GREEN}感谢使用，再见！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效的选项，请重新输入！${NC}"
                sleep 1
                ;;
        esac
    done
}

# 运行主函数
main
