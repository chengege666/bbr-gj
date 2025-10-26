#!/bin/bash

# VPS一键管理脚本 v0.3
# 作者: 智能助手
# 最后更新: 2025-10-27

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # 重置颜色

# -------------------------------
# root 权限检查
# -------------------------------
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}❌❌ 错误：请使用 root 权限运行本脚本${NC}"
        echo "👉 使用方法: sudo bash $0"
        exit 1
    fi
}

# -------------------------------
# 依赖安装
# -------------------------------
install_deps() {
    PKGS="curl wget git net-tools"
    if command -v apt >/dev/null 2>&1; then
        echo -e "${YELLOW}正在更新软件包列表...${NC}"
        apt update -y
        echo -e "${YELLOW}正在安装依赖: $PKGS${NC}"
        apt install -y $PKGS
    elif command -v yum >/dev/null 2>&1; then
        echo -e "${YELLOW}正在安装依赖: $PKGS${NC}"
        yum install -y $PKGS
    elif command -v dnf >/dev/null 2>&1; then
        echo -e "${YELLOW}正在安装依赖: $PKGS${NC}"
        dnf install -y $PKGS
    else
        echo -e "${YELLOW}⚠️ 未知系统，请手动安装依赖: $PKGS${NC}"
        read -n1 -p "按任意键继续菜单..."
    fi
}

check_deps() {
    for CMD in curl wget git; do
        if ! command -v $CMD >/dev/null 2>&1; then
            echo -e "${YELLOW}未检测到 $CMD，正在尝试安装依赖...${NC}"
            install_deps
            break
        fi
    done
}

# 显示菜单函数
show_menu() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "          VPS 脚本管理菜单 v0.3           "
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

# 系统更新函数
system_update() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "              系统更新功能                "
    echo "=========================================="
    echo -e "${NC}"
    
    # 检查系统类型
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu系统
        echo -e "${BLUE}检测到 Debian/Ubuntu 系统${NC}"
        echo -e "${YELLOW}开始更新系统...${NC}"
        echo ""
        
        # 更新软件包列表
        echo -e "${BLUE}[步骤1/3] 更新软件包列表...${NC}"
        apt update
        echo ""
        
        # 升级软件包
        echo -e "${BLUE}[步骤2/3] 升级软件包...${NC}"
        apt upgrade -y
        echo ""
        
        # 清理不再需要的包
        echo -e "${BLUE}[步骤3/3] 清理系统...${NC}"
        apt autoremove -y
        apt autoclean
        echo ""
        
        echo -e "${GREEN}系统更新完成！${NC}"
        
    elif [ -f /etc/redhat-release ]; then
        # CentOS/RHEL系统
        echo -e "${BLUE}检测到 CentOS/RHEL 系统${NC}"
        echo -e "${YELLOW}开始更新系统...${NC}"
        echo ""
        
        # 更新软件包
        echo -e "${BLUE}[步骤1/2] 更新软件包...${NC}"
        yum update -y
        echo ""
        
        # 清理缓存
        echo -e "${BLUE}[步骤2/2] 清理系统...${NC}"
        yum clean all
        yum autoremove -y
        echo ""
        
        echo -e "${GREEN}系统更新完成！${NC}"
        
    else
        echo -e "${RED}不支持的系统类型！${NC}"
        echo -e "${YELLOW}仅支持 Debian/Ubuntu 和 CentOS/RHEL 系统。${NC}"
    fi
    
    echo -e "${CYAN}"
    echo "=========================================="
    echo -e "${NC}"
    read -p "按回车键返回主菜单..."
}

# 系统清理函数
system_clean() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "              系统清理功能                "
    echo "=========================================="
    echo -e "${NC}"
    
    # 显示警告信息
    echo -e "${YELLOW}⚠️ 警告：系统清理操作将删除不必要的文件，请谨慎操作！${NC}"
    echo ""
    
    # 确认操作
    read -p "是否继续执行系统清理？(y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}已取消系统清理操作${NC}"
        read -p "按回车键返回主菜单..."
        return
    fi
    
    # 检查系统类型
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu系统
        echo -e "${BLUE}检测到 Debian/Ubuntu 系统${NC}"
        echo -e "${YELLOW}开始清理系统...${NC}"
        echo ""
        
        # 清理APT缓存
        echo -e "${BLUE}[步骤1/4] 清理APT缓存...${NC}"
        apt clean
        echo ""
        
        # 清理旧内核
        echo -e "${BLUE}[步骤2/4] 清理旧内核...${NC}"
        apt autoremove --purge -y
        echo ""
        
        # 清理日志文件
        echo -e "${BLUE}[步骤3/4] 清理日志文件...${NC}"
        journalctl --vacuum-time=1d
        find /var/log -type f -regex ".*\.gz$" -delete
        find /var/log -type f -regex ".*\.[0-9]$" -delete
        echo ""
        
        # 清理临时文件
        echo -e "${BLUE}[步骤4/4] 清理临时文件...${NC}"
        rm -rf /tmp/*
        rm -rf /var/tmp/*
        echo ""
        
        echo -e "${GREEN}系统清理完成！${NC}"
        
    elif [ -f /etc/redhat-release ]; then
        # CentOS/RHEL系统
        echo -e "${BLUE}检测到 CentOS/RHEL 系统${NC}"
        echo -e "${YELLOW}开始清理系统...${NC}"
        echo ""
        
        # 清理YUM缓存
        echo -e "${BLUE}[步骤1/4] 清理YUM缓存...${NC}"
        yum clean all
        echo ""
        
        # 清理旧内核
        echo -e "${BLUE}[步骤2/4] 清理旧内核...${NC}"
        package-cleanup --oldkernels --count=1 -y
        echo ""
        
        # 清理日志文件
        echo -e "${BLUE}[步骤3/4] 清理日志文件...${NC}"
        journalctl --vacuum-time=1d
        find /var/log -type f -regex ".*\.gz$" -delete
        find /var/log -type f -regex ".*\.[0-9]$" -delete
        echo ""
        
        # 清理临时文件
        echo -e "${BLUE}[步骤4/4] 清理临时文件...${NC}"
        rm -rf /tmp/*
        rm -rf /var/tmp/*
        echo ""
        
        echo -e "${GREEN}系统清理完成！${NC}"
        
    else
        echo -e "${RED}不支持的系统类型！${NC}"
        echo -e "${YELLOW}仅支持 Debian/Ubuntu 和 CentOS/RHEL 系统。${NC}"
    fi
    
    echo -e "${CYAN}"
    echo "=========================================="
    echo -e "${NC}"
    read -p "按回车键返回主菜单..."
}

# 基础工具安装函数
basic_tools() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "              基础工具安装                "
    echo "=========================================="
    echo -e "${NC}"
    
    # 定义常用工具列表
    DEBIAN_TOOLS="htop vim tmux net-tools dnsutils lsof tree zip unzip"
    REDHAT_TOOLS="htop vim tmux net-tools bind-utils lsof tree zip unzip"
    
    # 检查系统类型
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu系统
        echo -e "${BLUE}检测到 Debian/Ubuntu 系统${NC}"
        echo -e "${YELLOW}开始安装基础工具...${NC}"
        echo ""
        
        # 更新软件包列表
        echo -e "${BLUE}[步骤1/2] 更新软件包列表...${NC}"
        apt update -y
        echo ""
        
        # 安装工具
        echo -e "${BLUE}[步骤2/2] 安装基础工具...${NC}"
        apt install -y $DEBIAN_TOOLS
        echo ""
        
        echo -e "${GREEN}基础工具安装完成！${NC}"
        echo -e "${YELLOW}已安装工具: $DEBIAN_TOOLS${NC}"
        
    elif [ -f /etc/redhat-release ]; then
        # CentOS/RHEL系统
        echo -e "${BLUE}检测到 CentOS/RHEL 系统${NC}"
        echo -e "${YELLOW}开始安装基础工具...${NC}"
        echo ""
        
        # 安装工具
        echo -e "${BLUE}[步骤1/1] 安装基础工具...${NC}"
        yum install -y epel-release
        yum install -y $REDHAT_TOOLS
        echo ""
        
        echo -e "${GREEN}基础工具安装完成！${NC}"
        echo -e "${YELLOW}已安装工具: $REDHAT_TOOLS${NC}"
        
    else
        echo -e "${RED}不支持的系统类型！${NC}"
        echo -e "${YELLOW}仅支持 Debian/Ubuntu 和 CentOS/RHEL 系统。${NC}"
    fi
    
    echo -e "${CYAN}"
    echo "=========================================="
    echo -e "${NC}"
    read -p "按回车键返回主菜单..."
}

# ====================================================================
# +++ 高级Docker管理模块 (v2.1) +++
# ====================================================================

# 检查jq并安装
check_jq() {
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}检测到需要使用 jq 工具来处理JSON配置，正在尝试安装...${RESET}"
        if command -v apt >/dev/null 2>&1; then
            apt update && apt install -y jq
        elif command -v yum >/dev/null 2>&1; then
            yum install -y jq
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y jq
        fi
        if ! command -v jq &> /dev/null; then
            echo -e "${RED}jq 安装失败，相关功能可能无法使用。${RESET}"
            return 1
        fi
        echo -e "${GREEN}jq 安装成功。${RESET}"
    fi
    return 0
}

# 编辑daemon.json的辅助函数
edit_daemon_json() {
    local key=$1
    local value=$2
    DAEMON_FILE="/etc/docker/daemon.json"
    
    check_jq || return 1
    
    if [ ! -f "$DAEMON_FILE" ]; then
        echo "{}" > "$DAEMON_FILE"
    fi
    
    # 使用jq来修改json文件
    tmp_json=$(jq ".${key} = ${value}" "$DAEMON_FILE")
    echo "$tmp_json" > "$DAEMON_FILE"
    
    echo -e "${GREEN}配置文件 $DAEMON_FILE 已更新。${RESET}"
    echo -e "${YELLOW}正在重启Docker以应用更改...${RESET}"
    systemctl restart docker
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Docker重启成功。${RESET}"
    else
        echo -e "${RED}Docker重启失败，请手动检查: systemctl status docker${RESET}"
    fi
}

# 安装/更新Docker
install_update_docker() {
    echo -e "${CYAN}正在使用官方脚本安装/更新 Docker...${RESET}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh --mirror Aliyun
    rm get-docker.sh
    systemctl enable docker
    systemctl start docker
    if command -v docker >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Docker 安装/更新并启动成功！${RESET}"
    else
        echo -e "${RED}❌❌ Docker 安装/更新失败，请检查日志。${RESET}"
    fi
}

# 卸载Docker
uninstall_docker() {
    echo -e "${RED}警告：此操作将彻底卸载Docker并删除所有数据（容器、镜像、卷）！${RESET}"
    read -p "确定要继续吗？(y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${GREEN}操作已取消。${RESET}"
        return
    fi
    
    systemctl stop docker
    if command -v apt >/dev/null 2>&1; then
        apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        apt-get autoremove -y
    elif command -v yum >/dev/null 2>&1; then
        yum remove -y docker-ce docker-ce-cli containerd.io
    elif command -v dnf >/dev/null 2>&1; then
        dnf remove -y docker-ce docker-ce-cli containerd.io
    fi
    
    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd
    echo -e "${GREEN}Docker 已彻底卸载。${RESET}"
}

# Docker子菜单：容器管理 (v2.1 修复返回逻辑)
container_management_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== Docker 容器管理 ===${RESET}"
        docker ps -a
        echo "------------------------------------------------"
        echo "1. 启动容器    2. 停止容器    3. 重启容器"
        echo "4. 查看日志    5. 进入容器    6. 删除容器"
        echo "0. 返回上级菜单"
        read -p "请选择操作: " choice
        
        # 检查是否是返回操作
        if [[ "$choice" == "0" ]]; then
            break
        fi

        # 检查是否是需要容器ID的有效操作
        if [[ "$choice" =~ ^[1-6]$ ]]; then
            read -p "请输入容器ID或名称 (留空则取消): " container
            if [ -z "$container" ]; then
                continue # 取消操作，返回子菜单循环
            fi

            case "$choice" in
                1) docker start "$container" ;;
                2) docker stop "$container" ;;
                3) docker restart "$container" ;;
                4) docker logs "$container" ;;
                5) docker exec -it "$container" /bin/sh -c "[ -x /bin/bash ] && /bin/bash || /bin/sh" ;;
                6) docker rm "$container" ;;
            esac
            read -n1 -p "操作完成。按任意键继续..."
        else
            echo -e "${RED}无效选择，请输入 0-6 之间的数字。${RESET}"
            sleep 2
        fi
    done
}


# Docker子菜单：镜像管理
image_management_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== Docker 镜像管理 ===${RESET}"
        docker images
        echo "------------------------------------------------"
        echo "1. 拉取镜像    2. 删除镜像    3. 查看历史"
        echo "0. 返回上级菜单"
        read -p "请选择操作: " choice
        
        case "$choice" in
            1) 
                read -p "请输入要拉取的镜像名称 (例如: ubuntu:latest): " image_name
                [ -n "$image_name" ] && docker pull "$image_name"
                ;;
            2) 
                read -p "请输入要删除的镜像ID或名称: " image_id
                [ -n "$image_id" ] && docker rmi "$image_id"
                ;;
            3)
                read -p "请输入要查看历史的镜像ID或名称: " image_id
                [ -n "$image_id" ] && docker history "$image_id"
                ;;
            0) break ;;
            *) echo -e "${RED}无效选择${RESET}" ;;
        esac
        read -n1 -p "按任意键继续..."
    done
}

# 主Docker菜单
docker_menu() {
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}未检测到 Docker 环境！${RESET}"
        read -p "是否现在安装 Docker? (y/n): " install_docker
        if [[ "$install_docker" == "y" || "$install_docker" == "Y" ]]; then
            install_update_docker
        fi
        return
    fi
    
    while true; do
        clear
        echo -e "${CYAN}Docker管理${RESET}"
        if systemctl is-active --quiet docker; then
            containers=$(docker ps -a --format '{{.ID}}' | wc -l)
            images=$(docker images -q | wc -l)
            networks=$(docker network ls -q | wc -l)
            volumes=$(docker volume ls -q | wc -l)
            echo -e "${GREEN}环境已经安装 容器: ${containers} 镜像: ${images} 网络: ${networks} 卷: ${volumes}${RESET}"
        else
            echo -e "${RED}Docker服务未运行！请先启动Docker。${RESET}"
        fi
        echo "------------------------------------------------"
        echo "1.  安装/更新Docker环境"
        echo "2.  查看Docker全局状态 (docker system df)"
        echo "3.  Docker容器管理"
        echo "4.  Docker镜像管理"
        echo "5.  Docker网络管理"
        echo "6.  Docker卷管理"
        echo "7.  清理无用的Docker资源 (prune)"
        echo "8.  更换Docker镜像源"
        echo "9.  编辑daemon.json文件"
        echo "11. 开启Docker-ipv6访问"
        echo "12. 关闭Docker-ipv6访问"
        echo "19. 备份/还原Docker环境"
        echo "20. 卸载Docker环境"
        echo "0.  返回主菜单"
        echo "------------------------------------------------"
        read -p "请输入你的选择: " choice

        case "$choice" in
            1) install_update_docker ;;
            2) docker system df ;;
            3) container_management_menu ;;
            4) image_management_menu ;;
            5) docker network ls && echo "网络管理功能待扩展" ;;
            6) docker volume ls && echo "卷管理功能待扩展" ;;
            7) 
                read -p "这将删除所有未使用的容器、网络、镜像，确定吗? (y/N): " confirm
                [[ "$confirm" == "y" || "$confirm" == "Y" ]] && docker system prune -af --volumes
                ;;
            8)
                echo "请选择镜像源:"
                echo "1. 阿里云 (推荐国内)"
                echo "2. 网易"
                echo "3. 中科大"
                echo "4. Docker官方 (国外)"
                read -p "输入选择: " mirror_choice
                mirror_url=""
                case "$mirror_choice" in
                    1) mirror_url='"https://mirror.aliyuncs.com"' ;;
                    2) mirror_url='"http://hub-mirror.c.163.com"' ;;
                    3) mirror_url='"https://docker.mirrors.ustc.edu.cn"' ;;
                    4) mirror_url='""' ;;
                    *) echo "无效选择"; continue ;;
                esac
                edit_daemon_json '"registry-mirrors"' "[$mirror_url]"
                ;;
            9)
                [ -f /etc/docker/daemon.json ] || echo "{}" > /etc/docker/daemon.json
                editor=${EDITOR:-vi}
                $editor /etc/docker/daemon.json
                ;;
            11) edit_daemon_json '"ipv6"' "true" ;;
            12) edit_daemon_json '"ipv6"' "false" ;;
            19) 
                echo "功能开发中..." 
                ;;
            20) uninstall_docker ;;
            0) break ;;
            *) echo -e "${RED}无效选项${RESET}" ;;
        esac
        read -n1 -p "按任意键返回Docker菜单..."
    done
}

# -------------------------------
# Docker管理主菜单
# -------------------------------
docker_menu() {
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}未检测到 Docker 环境！${NC}"
        read -p "是否现在安装 Docker? (y/n): " install_docker
        if [[ "$install_docker" == "y" || "$install_docker" == "Y" ]]; then
            install_update_docker
        else
            return
        fi
    fi
    
    while true; do
        clear
        echo -e "${CYAN}Docker管理${NC}"
        if systemctl is-active --quiet docker; then
            containers=$(docker ps -a --format '{{.ID}}' | wc -l)
            images=$(docker images -q | wc -l)
            networks=$(docker network ls -q | wc -l)
            volumes=$(docker volume ls -q | wc -l)
            echo -e "${GREEN}环境已经安装 容器: ${containers} 镜像: ${images} 网络: ${networks} 卷: ${volumes}${NC}"
        else
            echo -e "${RED}Docker服务未运行！请先启动Docker。${NC}"
        fi
        echo "------------------------------------------------"
        echo "1.  安装/更新Docker环境"
        echo "2.  查看Docker全局状态 (docker system df)"
        echo "3.  Docker容器管理"
        echo "4.  Docker镜像管理"
        echo "5.  Docker网络管理"
        echo "6.  Docker卷管理"
        echo "7.  清理无用的Docker资源 (prune)"
        echo "8.  更换Docker镜像源"
        echo "9.  编辑daemon.json文件"
        echo "10. 开启Docker-ipv6访问"
        echo "11. 关闭Docker-ipv6访问"
        echo "12. 备份/还原Docker环境"
        echo "13. 卸载Docker环境"
        echo "0.  返回主菜单"
        echo "------------------------------------------------"
        read -p "请输入你的选择: " choice

        case "$choice" in
            1) install_update_docker ;;
            2) docker system df ;;
            3) container_management_menu ;;
            4) image_management_menu ;;
            5) network_management_menu ;;
            6) volume_management_menu ;;
            7) 
                read -p "这将删除所有未使用的容器、网络、镜像，确定吗? (y/N): " confirm
                [[ "$confirm" == "y" || "$confirm" == "Y" ]] && docker system prune -af --volumes
                ;;
            8)
                echo "请选择镜像源:"
                echo "1. 阿里云 (推荐国内)"
                echo "2. 网易"
                echo "3. 中科大"
                echo "4. Docker官方 (国外)"
                read -p "输入选择: " mirror_choice
                mirror_url=""
                case "$mirror_choice" in
                    1) mirror_url='"https://mirror.aliyuncs.com"' ;;
                    2) mirror_url='"http://hub-mirror.c.163.com"' ;;
                    3) mirror_url='"https://docker.mirrors.ustc.edu.cn"' ;;
                    4) mirror_url='""' ;;
                    *) echo "无效选择"; continue ;;
                esac
                edit_daemon_json '"registry-mirrors"' "[$mirror_url]"
                ;;
            9)
                [ -f /etc/docker/daemon.json ] || echo "{}" > /etc/docker/daemon.json
                editor=${EDITOR:-vi}
                $editor /etc/docker/daemon.json
                ;;
            10) edit_daemon_json '"ipv6"' "true" ;;
            11) edit_daemon_json '"ipv6"' "false" ;;
            12) 
                echo "功能开发中..."
                ;;
            13) uninstall_docker ;;
            0) break ;;
            *) echo -e "${RED}无效选项${NC}" ;;
        esac
        read -n1 -p "按任意键返回Docker菜单..."
    done
}
