#!/bin/bash



# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # 重置颜色

# 结果文件路径
RESULT_FILE="/tmp/bbr_test_results.txt"

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

# -------------------------------
# 显示主菜单函数
# -------------------------------
show_menu() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "       CGG-VPS 脚本管理菜单 v1.0           "
    echo "=========================================="
    echo -e "${NC}"
    echo "1. 系统信息查询"
    echo "2. 系统更新"
    echo "3. 系统清理"
    echo "4. 基础工具"
    echo "5. BBR管理"
    echo "6. Docker管理"
    echo "7. 系统工具"
    echo "8. VPS测试IP网络"
    echo "0. 退出脚本"
    echo "=========================================="
}

# -------------------------------
# 系统信息查询函数
# -------------------------------
system_info() {
    clear; echo -e "${CYAN}"; echo "=========================================="; echo "              系统信息查询                "; echo "=========================================="; echo -e "${NC}"
    echo -e "${BLUE}主机名: ${GREEN}$(hostname)${NC}"
    if [ -f /etc/os-release ]; then source /etc/os-release; echo -e "${BLUE}操作系统: ${NC}$PRETTY_NAME"; else echo -e "${BLUE}操作系统: ${NC}未知"; fi
    echo -e "${BLUE}内核版本: ${NC}$(uname -r)"
    cpu_model=$(grep 'model name' /proc/cpuinfo | head -1 | cut -d ':' -f2 | sed 's/^ *//')
    cpu_cores=$(grep -c '^processor' /proc/cpuinfo)
    echo -e "${BLUE}CPU型号: ${NC}$cpu_model"; echo -e "${BLUE}CPU核心数: ${NC}$cpu_cores"
    total_mem=$(free -m | awk '/Mem:/ {print $2}'); available_mem=$(free -m | awk '/Mem:/ {print $7}')
    echo -e "${BLUE}总内存: ${NC}${total_mem}MB"; echo -e "${BLUE}可用内存: ${NC}${available_mem}MB"
    disk_usage=$(df -h / | awk 'NR==2 {print $5}'); disk_total=$(df -h / | awk 'NR==2 {print $2}'); disk_used=$(df -h / | awk 'NR==2 {print $3}')
    echo -e "${BLUE}根分区使用率: ${NC}$disk_usage (已用 ${disk_used} / 总共 ${disk_total})"
    ipv4=$(curl -s --connect-timeout 2 ipv4.icanhazip.com); if [ -z "$ipv4" ]; then ipv4=$(curl -s --connect-timeout 2 ipv4.ip.sb); fi
    if [ -z "$ipv4" ]; then ipv4="${RED}无法获取${NC}"; else ipv4="${YELLOW}$ipv4${NC}"; fi; echo -e "${BLUE}公网IPv4: $ipv4"
    ipv6=$(curl -s --connect-timeout 2 ipv6.icanhazip.com); if [ -z "$ipv6" ]; then ipv6=$(curl -s --connect-timeout 2 ipv6.ip.sb); fi
    if [ -z "$ipv6" ]; then ipv6="${RED}未检测到${NC}"; else ipv6="${YELLOW}$ipv6${NC}"; fi; echo -e "${BLUE}公网IPv6: $ipv6"
    echo -e "${BLUE}BBR状态: ${NC}"; check_bbr
    uptime_info=$(uptime -p | sed 's/up //'); echo -e "${BLUE}系统运行时间: ${NC}$uptime_info"
    beijing_time=$(TZ='Asia/Shanghai' date +'%Y-%m-%d %H:%M:%S'); echo -e "${BLUE}北京时间: ${NC}$beijing_time"
    echo -e "${CYAN}"; echo "=========================================="; echo -e "${NC}"; read -p "按回车键返回主菜单..."
}
# -------------------------------
# 系统更新函数
# -------------------------------
system_update() {
    clear; echo -e "${CYAN}"; echo "=========================================="; echo "              系统更新功能                "; echo "=========================================="; echo -e "${NC}"
    if [ -f /etc/debian_version ]; then
        echo -e "${BLUE}检测到 Debian/Ubuntu 系统${NC}"; echo -e "${YELLOW}开始更新系统...${NC}"; echo ""
        echo -e "${BLUE}[步骤1/3] 更新软件包列表...${NC}"; apt update; echo ""
        echo -e "${BLUE}[步骤2/3] 升级软件包...${NC}"; apt upgrade -y; echo ""
        echo -e "${BLUE}[步骤3/3] 清理系统...${NC}"; apt autoremove -y; apt autoclean; echo ""
        echo -e "${GREEN}系统更新完成！${NC}"
    elif [ -f /etc/redhat-release ]; then
        echo -e "${BLUE}检测到 CentOS/RHEL 系统${NC}"; echo -e "${YELLOW}开始更新系统...${NC}"; echo ""
        echo -e "${BLUE}[步骤1/2] 更新软件包...${NC}"; yum update -y; echo ""
        echo -e "${BLUE}[步骤2/2] 清理系统...${NC}"; yum clean all; yum autoremove -y; echo ""
        echo -e "${GREEN}系统更新完成！${NC}"
    else
        echo -e "${RED}不支持的系统类型！${NC}"; echo -e "${YELLOW}仅支持 Debian/Ubuntu 和 CentOS/RHEL 系统。${NC}"
    fi
    echo -e "${CYAN}"; echo "=========================================="; echo -e "${NC}"; read -p "按回车键返回主菜单..."
}
# -------------------------------
# 系统清理函数
# -------------------------------
system_clean() {
    clear; echo -e "${CYAN}"; echo "=========================================="; echo "              系统清理功能                "; echo "=========================================="; echo -e "${NC}"
    echo -e "${YELLOW}⚠️ 警告：系统清理操作将删除不必要的文件，请谨慎操作！${NC}"; echo ""
    read -p "是否继续执行系统清理？(y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then echo -e "${YELLOW}已取消系统清理操作${NC}"; read -p "按回车键返回主菜单..."; return; fi
    if [ -f /etc/debian_version ]; then
        echo -e "${BLUE}检测到 Debian/Ubuntu 系统${NC}"; echo -e "${YELLOW}开始清理系统...${NC}"; echo ""
        echo -e "${BLUE}[步骤1/4] 清理APT缓存...${NC}"; apt clean; echo ""
        echo -e "${BLUE}[步骤2/4] 清理旧内核...${NC}"; apt autoremove --purge -y; echo ""
        echo -e "${BLUE}[步骤3/4] 清理日志文件...${NC}"; journalctl --vacuum-time=1d; find /var/log -type f -regex ".*\.gz$" -delete; find /var/log -type f -regex ".*\.[0-9]$" -delete; echo ""
        echo -e "${BLUE}[步骤4/4] 清理临时文件...${NC}"; rm -rf /tmp/*; rm -rf /var/tmp/*; echo ""
        echo -e "${GREEN}系统清理完成！${NC}"
    elif [ -f /etc/redhat-release ]; then
        echo -e "${BLUE}检测到 CentOS/RHEL 系统${NC}"; echo -e "${YELLOW}开始清理系统...${NC}"; echo ""
        echo -e "${BLUE}[步骤1/4] 清理YUM缓存...${NC}"; yum clean all; echo ""
        echo -e "${BLUE}[步骤2/4] 清理旧内核...${NC}"; package-cleanup --oldkernels --count=1 -y; echo ""
        echo -e "${BLUE}[步骤3/4] 清理日志文件...${NC}"; journalctl --vacuum-time=1d; find /var/log -type f -regex ".*\.gz$" -delete; find /var/log -type f -regex ".*\.[0-9]$" -delete; echo ""
        echo -e "${BLUE}[步骤4/4] 清理临时文件...${NC}"; rm -rf /tmp/*; rm -rf /var/tmp/*; echo ""
        echo -e "${GREEN}系统清理完成！${NC}"
    else
        echo -e "${RED}不支持的系统类型！${NC}"; echo -e "${YELLOW}仅支持 Debian/Ubuntu 和 CentOS/RHEL 系统。${NC}"
    fi
    echo -e "${CYAN}"; echo "=========================================="; echo -e "${NC}"; read -p "按回车键返回主菜单..."
}
# -------------------------------
# 基础工具安装函数
# -------------------------------
basic_tools() {
    clear; echo -e "${CYAN}"; echo "=========================================="; echo "              基础工具安装                "; echo "=========================================="; echo -e "${NC}"
    DEBIAN_TOOLS="htop vim tmux net-tools dnsutils lsof tree zip unzip"
    REDHAT_TOOLS="htop vim tmux net-tools bind-utils lsof tree zip unzip"
    if [ -f /etc/debian_version ]; then
        echo -e "${BLUE}检测到 Debian/Ubuntu 系统${NC}"; echo -e "${YELLOW}开始安装基础工具...${NC}"; echo ""
        echo -e "${BLUE}[步骤1/2] 更新软件包列表...${NC}"; apt update -y; echo ""
        echo -e "${BLUE}[步骤2/2] 安装基础工具...${NC}"; apt install -y $DEBIAN_TOOLS; echo ""
        echo -e "${GREEN}基础工具安装完成！${NC}"; echo -e "${YELLOW}已安装工具: $DEBIAN_TOOLS${NC}"
    elif [ -f /etc/redhat-release ]; then
        echo -e "${BLUE}检测到 CentOS/RHEL 系统${NC}"; echo -e "${YELLOW}开始安装基础工具...${NC}"; echo ""
        echo -e "${BLUE}[步骤1/1] 安装基础工具...${NC}"; yum install -y epel-release; yum install -y $REDHAT_TOOLS; echo ""
        echo -e "${GREEN}基础工具安装完成！${NC}"; echo -e "${YELLOW}已安装工具: $REDHAT_TOOLS${NC}"
    else
        echo -e "${RED}不支持的系统类型！${NC}"; echo -e "${YELLOW}仅支持 Debian/Ubuntu 和 CentOS/RHEL 系统。${NC}"
    fi
    echo -e "${CYAN}"; echo "=========================================="; echo -e "${NC}"; read -p "按回车键返回主菜单..."
}

# -------------------------------
# BBR 管理主菜单
# -------------------------------
bbr_management() {
    while true; do
        clear
        echo -e "${CYAN}"
        echo "=========================================="
        echo "                 BBR管理                  "
        echo "=========================================="
        echo -e "${NC}"
        # 实时显示BBR状态
        echo -e "${BLUE}当前BBR状态: ${NC}"
        check_bbr # 调用您已有的检查函数
        echo "------------------------------------------"
        echo "1. BBR 综合测速 (BBR, BBR Plus, BBRv2, BBRv3)"
        echo "2. 安装/切换 BBR 内核 (使用 ylx2016 脚本)"
        echo "3. 查看系统详细信息 (含BBR状态)"
        echo "0. 返回主菜单"
        echo "=========================================="

        read -p "请输入你的选择: " bbr_choice

        case $bbr_choice in
            1)
                bbr_test_menu
                ;;
            2)
                run_bbr_switch
                ;;
            3)
                show_sys_info
                ;;
            0)
                echo "返回主菜单..."
                break
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                read -p "按回车键继续..."
                ;;
        esac
    done
}

# -------------------------------
# 核心功能：BBR 测速
# -------------------------------
run_test() {
    MODE=$1
    echo -e "${CYAN}>>> 切换到 $MODE 并测速...${RESET}" 
    
    # 切换算法
    case $MODE in
        "BBR") 
            modprobe tcp_bbr >/dev/null 2>&1
            sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1
            sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1
            ;;
        "BBR Plus") 
            modprobe tcp_bbrplus >/dev/null 2>&1
            sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1
            sysctl -w net.ipv4.tcp_congestion_control=bbrplus >/dev/null 2>&1
            ;;
        "BBRv2") 
            modprobe tcp_bbrv2 >/dev/null 2>&1
            sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1
            sysctl -w net.ipv4.tcp_congestion_control=bbrv2 >/dev/null 2>&1
            ;;
        "BBRv3") 
            modprobe tcp_bbrv3 >/dev/null 2>&1
            sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1
            sysctl -w net.ipv4.tcp_congestion_control=bbrv3 >/dev/null 2>&1
            ;;
        *) # 增加一个默认情况以防意外输入，虽然测速模式通常是固定的
            echo -e "${YELLOW}未知 BBR 模式: $MODE${RESET}"
            ;;
    esac
    
    # 执行测速
    RAW=$(speedtest-cli --simple 2>/dev/null)
    if [ -z "$RAW" ]; then
        echo -e "${YELLOW}⚠️ speedtest-cli 失败，尝试替代方法...${RESET}" 
        RAW=$(curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python - --simple 2>/dev/null)
    fi

    if [ -z "$RAW" ]; then
        echo -e "${RED}$MODE 测速失败${RESET}" | tee -a "$RESULT_FILE" 
        echo ""
        return
    fi

    PING=$(echo "$RAW" | grep "Ping" | awk '{print $2}')
    DOWNLOAD=$(echo "$RAW" | grep "Download" | awk '{print $2}')
    UPLOAD=$(echo "$RAW" | grep "Upload" | awk '{print $2}')

    echo -e "${GREEN}$MODE | Ping: ${PING}ms | Down: ${DOWNLOAD} Mbps | Up: ${UPLOAD} Mbps${RESET}" | tee -a "$RESULT_FILE" 
    echo ""
}

# -------------------------------
# 功能 1: BBR 综合测速
# -------------------------------
bbr_test_menu() {
    echo -e "${CYAN}=== 开始 BBR 综合测速 ===${RESET}"
    > "$RESULT_FILE"
    
    # 无条件尝试所有算法
    for MODE in "BBR" "BBR Plus" "BBRv2" "BBRv3"; do
        run_test "$MODE"
    done
    
    echo -e "${CYAN}=== 测试完成，结果汇总 (${RESULT_FILE}) ===${RESET}"
    if [ -f "$RESULT_FILE" ] && [ -s "$RESULT_FILE" ]; then
        cat "$RESULT_FILE"
    else
        echo -e "${YELLOW}无测速结果${RESET}"
    fi
    echo ""
    read -n1 -p "按任意键返回菜单..."
}

# -------------------------------
# 功能 2: 安装/切换 BBR 内核
# -------------------------------
run_bbr_switch() {
    echo -e "${CYAN}正在下载并运行 BBR 切换脚本... (来自 ylx2016/Linux-NetSpeed)${RESET}"
    wget -O tcp.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌❌ 下载或运行脚本失败，请检查网络连接${RESET}"
    fi
    read -n1 -p "按任意键返回菜单..."
}

# -------------------------------
# 功能 3: 系统信息 (增强版，包含BBR类型和GLIBC版本)
# -------------------------------
show_sys_info() {
    echo -e "${CYAN}=== 系统详细信息 ===${RESET}"
    
    # 操作系统信息
    echo -e "${GREEN}操作系统:${RESET} $(cat /etc/os-release | grep PRETTY_NAME | cut -d "=" -f 2 | tr -d '"' 2>/dev/null || echo '未知')"
    echo -e "${GREEN}系统架构:${RESET} $(uname -m)"
    echo -e "${GREEN}内核版本:${RESET} $(uname -r)"
    echo -e "${GREEN}主机名:${RESET} $(hostname)"
    
    # CPU信息
    echo -e "${GREEN}CPU型号:${RESET} $(grep -m1 'model name' /proc/cpuinfo | awk -F': ' '{print $2}' 2>/dev/null || echo '未知')"
    echo -e "${GREEN}CPU核心数:${RESET} $(grep -c 'processor' /proc/cpuinfo 2>/dev/null || echo '未知')"
    echo -e "${GREEN}CPU频率:${RESET} $(grep -m1 'cpu MHz' /proc/cpuinfo | awk -F': ' '{print $2}' 2>/dev/null || echo '未知') MHz"
    
    # 内存信息
    MEM_TOTAL=$(free -h | grep Mem | awk '{print $2}' 2>/dev/null || echo '未知')
    MEM_USED=$(free -h | grep Mem | awk '{print $3}' 2>/dev/null || echo '未知')
    MEM_FREE=$(free -h | grep Mem | awk '{print $4}' 2>/dev/null || echo '未知')
    echo -e "${GREEN}内存总量:${RESET} $MEM_TOTAL | ${GREEN}已用:${RESET} $MEM_USED | ${GREEN}可用:${RESET} $MEM_FREE"
    
    # Swap信息
    SWAP_TOTAL=$(free -h | grep Swap | awk '{print $2}' 2>/dev/null || echo '未知')
    SWAP_USED=$(free -h | grep Swap | awk '{print $3}' 2>/dev/null || echo '未知')
    SWAP_FREE=$(free -h | grep Swap | awk '{print $4}' 2>/dev/null || echo '未知')
    echo -e "${GREEN}Swap总量:${RESET} $SWAP_TOTAL | ${GREEN}已用:${RESET} $SWAP_USED | ${GREEN}可用:${RESET} $SWAP_FREE"
    
    # 磁盘信息
    echo -e "${GREEN}磁盘使用情况:${RESET}"
    df -h | grep -E '^(/dev/|Filesystem)' | head -5
    
    # 网络信息
    echo -e "${GREEN}公网IPv4:${RESET} $(curl -s4 ifconfig.me 2>/dev/null || echo '获取失败')"
    echo -e "${GREEN}公网IPv6:${RESET} $(curl -s6 ifconfig.me 2>/dev/null || echo '获取失败')"
    echo -e "${GREEN}内网IP:${RESET} $(hostname -I 2>/dev/null || ip addr show | grep -E 'inet (192\.168|10\.|172\.)' | head -1 | awk '{print $2}' || echo '未知')"
    
    # BBR信息
    CURRENT_BBR=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    CURRENT_QDISC=$(sysctl net.core.default_qdisc 2>/dev/null | awk '{print $3}')
    echo -e "${GREEN}当前拥塞控制算法:${RESET} $CURRENT_BBR"
    echo -e "${GREEN}当前队列规则:${RESET} $CURRENT_QDISC"
    
    # GLIBC信息
    GLIBC_VERSION=$(ldd --version 2>/dev/null | head -n1 | awk '{print $NF}')
    if [ -z "$GLIBC_VERSION" ]; then
        GLIBC_VERSION="未知"
    fi
    echo -e "${GREEN}GLIBC版本:${RESET} $GLIBC_VERSION"
    
    # 系统运行状态
    echo -e "${GREEN}系统运行时间:${RESET} $(uptime -p 2>/dev/null || uptime | awk '{print $3,$4,$5}' | sed 's/,//g')"
    echo -e "${GREEN}系统负载:${RESET} $(uptime | awk -F'load average: ' '{print $2}' 2>/dev/null || echo '未知')"
    echo -e "${GREEN}当前登录用户:${RESET} $(who | wc -l 2>/dev/null || echo '未知')"
    
    # 进程信息
    echo -e "${GREEN}运行进程数:${RESET} $(ps aux | wc -l 2>/dev/null || echo '未知')"
    
    echo ""
    read -n1 -p "按任意键返回菜单..."
}

# Docker 相关函数 (修复版)
check_docker_status() {
    if command -v docker >/dev/null 2>&1; then
        if systemctl is-active docker >/dev/null 2>&1; then
            containers=$(docker ps -aq 2>/dev/null | wc -l)
            images=$(docker images -q 2>/dev/null | wc -l)
            networks=$(docker network ls -q 2>/dev/null | wc -l)
            volumes=$(docker volume ls -q 2>/dev/null | wc -l)
            echo "环境已经安装 容器:${containers} 镜像:${images} 网络:${networks} 卷:${volumes}"
        else
            echo "Docker已安装但服务未启动"
        fi
    else
        echo "Docker未安装"
    fi
}

install_update_docker() {
    clear
    echo "正在安装/更新Docker环境..."
    if command -v apt >/dev/null 2>&1; then
        apt update -y
        apt install -y curl wget
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl wget
    fi
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm -f get-docker.sh
    systemctl start docker
    systemctl enable docker
    if systemctl is-active docker >/dev/null 2>&1; then
        echo -e "${GREEN}Docker安装成功！${NC}"
    else
        echo -e "${RED}Docker安装失败，请检查日志${NC}"
    fi
    read -p "按回车键继续..."
}

show_docker_status() {
    clear
    echo "=== Docker全局状态 ==="
    docker system df
    echo ""
    echo "=== 运行中的容器 ==="
    docker ps
    read -p "按回车键继续..."
}

docker_volume_management() {
    while true; do
        clear
        echo "=== Docker 卷管理 ==="
        docker volume ls
        echo ""
        echo "1. 创建卷"; echo "2. 删除卷"; echo "3. 清理未使用的卷"; echo "0. 返回上级菜单"; echo ""
        read -p "请选择操作: " choice
        case $choice in
            1) read -p "请输入卷名称: " volume_name; docker volume create "$volume_name" ;;
            2) read -p "请输入卷名称或ID: " volume_name; docker volume rm "$volume_name" ;;
            3) docker volume prune -f ;;
            0) break ;;
            *) echo "无效选择，请重新输入" ;;
        esac
        echo ""; read -p "按回车键继续..."
    done
}

docker_container_management() {
    while true; do
        clear
        echo "=== Docker容器管理 ==="
        docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}"
        echo ""
        echo "1. 启动容器"; echo "2. 停止容器"; echo "3. 重启容器"; echo "4. 查看容器日志"; echo "5. 进入容器终端"; echo "6. 删除容器"; echo "7. 查看容器详情"; echo "0. 返回上级菜单"; echo ""
        read -p "请选择操作: " choice
        case $choice in
            1) read -p "请输入容器名称或ID: " container; docker start "$container" ;;
            2) read -p "请输入容器名称或ID: " container; docker stop "$container" ;;
            3) read -p "请输入容器名称或ID: " container; docker restart "$container" ;;
            4) read -p "请输入容器名称或ID: " container; docker logs "$container" ;;
            5) read -p "请输入容器名称或ID: " container; docker exec -it "$container" /bin/bash || docker exec -it "$container" /bin/sh ;;
            6) read -p "请输入容器名称或ID: " container; docker rm "$container" ;;
            7) read -p "请输入容器名称或ID: " container; docker inspect "$container" ;;
            0) break ;;
            *) echo "无效选择，请重新输入" ;;
        esac
        echo ""; read -p "按回车键继续..."
    done
}

docker_image_management() {
    while true; do
        clear
        echo "=== Docker镜像管理 ==="
        docker images
        echo ""
        echo "1. 拉取镜像"; echo "2. 删除镜像"; echo "3. 查看镜像历史"; echo "4. 导出镜像"; echo "5. 导入镜像"; echo "0. 返回上级菜单"; echo ""
        read -p "请选择操作: " choice
        case $choice in
            1) read -p "请输入镜像名称(如ubuntu:latest): " image; docker pull "$image" ;;
            2) read -p "请输入镜像ID或名称: " image; docker rmi "$image" ;;
            3) read -p "请输入镜像ID或名称: " image; docker history "$image" ;;
            4) read -p "请输入镜像名称: " image; read -p "请输入导出文件名(如image.tar): " filename; docker save -o "$filename" "$image" ;;
            5) read -p "请输入导入的文件名: " filename; docker load -i "$filename" ;;
            0) break ;;
            *) echo "无效选择，请重新输入" ;;
        esac
        echo ""; read -p "按回车键继续..."
    done
}

docker_network_management() {
    while true; do
        clear
        echo "=== Docker网络管理 ==="
        docker network ls
        echo ""
        echo "1. 创建网络"; echo "2. 删除网络"; echo "3. 查看网络详情"; echo "4. 连接容器到网络"; echo "5. 从网络断开容器"; echo "0. 返回上级菜单"; echo ""
        read -p "请选择操作: " choice
        case $choice in
            1) read -p "请输入网络名称: " network; read -p "请输入网络驱动(bridge/overlay等): " driver; docker network create --driver "$driver" "$network" ;;
            2) read -p "请输入网络名称或ID: " network; docker network rm "$network" ;;
            3) read -p "请输入网络名称或ID: " network; docker network inspect "$network" ;;
            4) read -p "请输入容器名称或ID: " container; read -p "请输入网络名称或ID: " network; docker network connect "$network" "$container" ;;
            5) read -p "请输入容器名称或ID: " container; read -p "请输入网络名称或ID: " network; docker network disconnect "$network" "$container" ;;
            0) break ;;
            *) echo "无效选择，请重新输入" ;;
        esac
        echo ""; read -p "按回车键继续..."
    done
}

clean_docker_resources() {
    clear
    echo "正在清理无用的Docker资源..."
    echo "1. 清理停止的容器、未使用的网络和构建缓存..."; docker system prune -f
    echo "2. 清理所有未使用的镜像..."; docker image prune -af
    echo "3. 清理未使用的卷..."; docker volume prune -f
    echo -e "${GREEN}Docker资源清理完成！${NC}"
    read -p "按回车键继续..."
}

change_docker_registry() {
    clear
    echo "请选择Docker镜像源:"
    echo "1. Docker官方源(国外，恢复默认)"; echo "2. 阿里云镜像源(国内推荐)"; echo "3. 中科大镜像源"; echo "4. 网易镜像源"; echo "5. 腾讯云镜像源"
    read -p "请输入选择(1-5): " registry_choice
    local registry_url=""
    case $registry_choice in
        1) ;;
        2) registry_url="https://registry.cn-hangzhou.aliyuncs.com" ;;
        3) registry_url="https://docker.mirrors.ustc.edu.cn" ;;
        4) registry_url="http://hub-mirror.c.163.com" ;;
        5) registry_url="https://mirror.ccs.tencentyun.com" ;;
        *) echo "无效选择，操作已取消。"; return ;;
    esac
    mkdir -p /etc/docker
    if [ -z "$registry_url" ]; then
        echo '{}' > /etc/docker/daemon.json
        echo "已恢复默认镜像源"
    else
        cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": ["$registry_url"]
}
EOF
        echo "已设置镜像源：$registry_url"
    fi
    echo "正在重启Docker服务..."
    systemctl restart docker
    echo -e "${GREEN}Docker服务已重启，镜像源设置完成${NC}"
    read -p "按回车键继续..."
}

edit_daemon_json() {
    clear
    if [ ! -f /etc/docker/daemon.json ]; then
        mkdir -p /etc/docker; echo "{}" > /etc/docker/daemon.json
    fi
    if ! command -v vi >/dev/null 2>&1 && ! command -v vim >/dev/null 2>&1; then
        echo -e "${RED}未安装 vi/vim 编辑器，请手动编辑 /etc/docker/daemon.json${NC}"; return
    fi
    echo -e "${YELLOW}使用 vi 编辑器编辑 /etc/docker/daemon.json 文件...${NC}"
    vi /etc/docker/daemon.json
    echo "正在重启Docker服务..."
    systemctl restart docker
    echo -e "${GREEN}daemon.json配置已更新，Docker服务已重启${NC}"
    read -p "按回车键继续..."
}

enable_docker_ipv6() {
    clear
    echo "正在启用Docker IPv6访问..."
    if [ ! -f /proc/net/if_inet6 ]; then
        echo -e "${RED}系统不支持IPv6，无法开启Docker IPv6访问。${NC}"; read -p "按回车键继续..."; return
    fi
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << EOF
{
  "ipv6": true,
  "fixed-cidr-v6": "fd00:db8:1::/64"
}
EOF
    echo "正在重启Docker服务..."
    systemctl restart docker
    echo -e "${GREEN}Docker IPv6访问已开启 (内网地址段: fd00:db8:1::/64)${NC}"
    read -p "按回车键继续..."
}

disable_docker_ipv6() {
    clear
    echo "正在禁用Docker IPv6访问..."
    if [ -f /etc/docker/daemon.json ]; then
        if command -v jq >/dev/null 2>&1; then
            jq 'del(.ipv6) | del(.["fixed-cidr-v6"])' /etc/docker/daemon.json > /tmp/daemon.json && mv /tmp/daemon.json /etc/docker/daemon.json
        else
            echo -e "${YELLOW}警告：未安装 jq，使用 sed 移除配置。${NC}"
            sed -i '/"ipv6": true,/d' /etc/docker/daemon.json
            sed -i '/"fixed-cidr-v6":/d' /etc/docker/daemon.json
        fi
    fi
    echo "正在重启Docker服务..."
    systemctl restart docker
    echo -e "${GREEN}Docker IPv6访问已关闭${NC}"
    read -p "按回车键继续..."
}

backup_restore_docker() {
    clear
    echo "=== Docker环境备份/迁移/还原 ==="
    echo "1. 备份所有容器为镜像"; echo "2. 导出所有镜像"; echo "3. 备份Docker数据卷"; echo "4. 从备份恢复 (手动操作)"; echo "0. 返回上级菜单"; echo ""
    read -p "请选择操作: " choice
    case $choice in
        1)
            echo "正在备份所有容器为镜像..."
            for container in $(docker ps -aq); do name=$(docker inspect --format='{{.Name}}' $container | sed 's/^\///'); docker commit "$container" "${name}-backup:latest"; done
            echo -e "${GREEN}容器备份完成${NC}"
            ;;
        2)
            read -p "请输入导出目录(默认/tmp): " backup_dir; backup_dir=${backup_dir:-/tmp}; mkdir -p "$backup_dir"
            echo "正在导出所有镜像到 $backup_dir ..."
            for image in $(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>"); do filename=$(echo "$image" | tr '/:' '_').tar; docker save -o "$backup_dir/$filename" "$image"; done
            echo -e "${GREEN}镜像导出完成到 $backup_dir 目录${NC}"
            ;;
        3)
            read -p "请输入备份目录(默认/tmp): " backup_dir; backup_dir=${backup_dir:-/tmp}; mkdir -p "$backup_dir/docker-volumes"
            echo "正在备份Docker数据卷到 $backup_dir/docker-volumes ..."
            for volume in $(docker volume ls -q); do docker run --rm -v "$volume:/source:ro" -v "$backup_dir/docker-volumes:/backup" alpine tar czf "/backup/${volume}.tar.gz" -C /source .; done
            echo -e "${GREEN}数据卷备份完成${NC}"
            ;;
        4) echo -e "${YELLOW}恢复功能需要手动操作，请参考Docker文档：${NC}"; echo " - 导入镜像: docker load -i image.tar"; echo " - 恢复卷: 将备份的.tar.gz解压到目标卷中" ;;
        0) return ;;
        *) echo "无效选择" ;;
    esac
    read -p "按回车键继续..."
}

uninstall_docker() {
    clear
    echo -e "${RED}警告：此操作将彻底卸载Docker并删除所有数据！${NC}"
    read -p "确定要卸载Docker吗？(y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then echo -e "${YELLOW}卸载操作已取消${NC}"; read -p "按回车键继续..."; return; fi
    echo "正在停止和删除所有容器..."; docker stop $(docker ps -aq) 2>/dev/null; docker rm $(docker ps -aq) 2>/dev/null
    echo "正在删除所有镜像和卷..."; docker rmi $(docker images -q) 2>/dev/null; docker volume rm $(docker volume ls -q) 2>/dev/null
    echo "正在删除所有网络..."; docker network rm $(docker network ls | grep -v "bridge\|host\|none" | awk 'NR>1 {print $1}') 2>/dev/null
    if command -v apt >/dev/null 2>&1; then
        apt purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; apt autoremove -y
    elif command -v yum >/dev/null 2>&1; then
        yum remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi
    rm -rf /var/lib/docker; rm -rf /var/lib/containerd; rm -rf /etc/docker
    echo -e "${GREEN}Docker环境已彻底卸载${NC}"
    read -p "按回车键继续..."
}

docker_management_menu() {
    while true; do
        clear
        echo -e "${CYAN}"; echo "=========================================="; echo "                Docker管理                "; echo "=========================================="; echo -e "${NC}"
        check_docker_status
        echo ""; echo "1. 安装/更新Docker环境"; echo "2. 查看Docker全局状态"; echo "3. Docker容器管理"; echo "4. Docker镜像管理"; echo "5. Docker网络管理"; echo "6. Docker卷管理"; echo "7. 清理无用的Docker资源"; echo "8. 更换Docker源"; echo "9. 编辑daemon.json文件"; echo "10. 开启Docker-IPv6访问"; echo "11. 关闭Docker-IPv6访问"; echo "12. 备份/迁移/还原Docker环境"; echo "13. 卸载Docker环境"; echo "0. 返回主菜单"; echo "=========================================="; echo ""
        read -p "请输入你的选择: " choice
        case $choice in
            1) install_update_docker ;; 2) show_docker_status ;; 3) docker_container_management ;; 4) docker_image_management ;; 5) docker_network_management ;; 6) docker_volume_management ;; 7) clean_docker_resources ;; 8) change_docker_registry ;; 9) edit_daemon_json ;; 10) enable_docker_ipv6 ;; 11) disable_docker_ipv6 ;; 12) backup_restore_docker ;; 13) uninstall_docker ;;
            0) echo "返回主菜单..."; break ;;
            *) echo -e "${RED}无效选择，请重新输入${NC}"; read -p "按回车键继续..." ;;
        esac
    done
}

# ====================================================================
# +++ 系统工具功能实现 +++
# ====================================================================

# -------------------------------
# 1. 高级防火墙管理 (占位菜单 - 保持不变)
# -------------------------------
advanced_firewall_menu() {
    while true; do
        clear
        echo -e "${CYAN}"
        echo "=========================================="
        echo "              高级防火墙管理              "
        echo "=========================================="
        if command -v iptables &>/dev/null; then
            echo -e "${BLUE}当前防火墙 (iptables/nftables) 状态:${NC}"
            iptables -L INPUT -n --line-numbers 2>/dev/null | head -n 5
        fi
        echo "------------------------------------------"
        echo -e "${NC}"
        echo "1. 开放指定端口        2. 关闭指定端口"
        echo "3. 开放所有端口        4. 关闭所有端口"
        echo "------------------------------------------"
        echo "5. IP白名单            6. IP黑名单"
        echo "7. 清除指定IP          8. 启动/停止防火墙 (占位)"
        echo "------------------------------------------"
        echo "11. 允许PING           12. 禁止PING"
        echo "13. 启动DDOS防御       14. 关闭DDOS防御"
        echo "------------------------------------------"
        echo "15. 阻止指定国家IP       16. 仅允许指定国家IP"
        echo "17. 解除指定国家IP限制   18. 查看当前规则 (占位)"
        echo "------------------------------------------"
        echo "0. 返回上级选单"
        echo "=========================================="

        read -p "请输入你的选择: " fw_choice

        case $fw_choice in
            1|2|3|4) echo -e "${YELLOW}功能占位：端口操作。请填充您的 Firewalld/UFW/Iptables 端口操作命令。${NC}" ;;
            5|6|7) echo -e "${YELLOW}功能占位：IP黑白名单。请填充您的 Firewalld/UFW/Iptables IP 白名单/黑名单命令。${NC}" ;;
            8) echo -e "${YELLOW}功能占位：启停防火墙。请填充您的 systemctl stop/start firewalld 或 ufw disable/enable 命令。${NC}" ;;
            11|12) echo -e "${YELLOW}功能占位：PING控制。请填充您的 Firewalld/Iptables 针对 ICMP 协议的操作命令。${NC}" ;;
            13|14) echo -e "${YELLOW}功能占位：DDOS防御。请填充您的 DDOS 防御（如：配置限速、安装工具）的启动/关闭命令。${NC}" ;;
            15|16|17) echo -e "${YELLOW}功能占位：国家IP限制。请填充您的 IP 库查询和基于 iptables/ipset 的国家 IP 限制命令。${NC}" ;;
            18) echo -e "${YELLOW}功能占位：查看规则。请填充您的 iptables -L -n 或 firewall-cmd --list-all 命令。${NC}" ;;
            0) return ;;
            *) echo -e "${RED}无效的选项，请重新输入！${NC}"; sleep 1 ;;
        esac
        
        if [ "$fw_choice" != "0" ]; then
            read -p "按回车键继续..."
        fi
    done
}

# -------------------------------
# 2. 修改登录密码
# -------------------------------
change_login_password() {
    clear
    echo -e "${CYAN}=========================================="
    echo "              修改登录密码                "
    echo "=========================================="
    echo -e "${NC}"
    echo -e "${YELLOW}⚠️ 注意：此操作将修改当前用户的密码。${NC}"
    
    # 始终修改当前执行脚本的用户的密码，即 root
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}错误：请使用 root 权限运行本脚本。${NC}"
        read -p "按回车键继续..."
        return
    fi
    
    # 使用 passwd 命令修改密码
    passwd root
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 密码修改成功！${NC}"
    else
        echo -e "${RED}❌ 密码修改失败，请检查输入或系统日志。${NC}"
    fi
    
    read -p "按回车键继续..."
}

# -------------------------------
# 3. 修改 SSH 连接端口
# -------------------------------
change_ssh_port() {
    clear
    echo -e "${CYAN}=========================================="
    echo "            修改 SSH 连接端口             "
    echo "=========================================="
    echo -e "${NC}"
    
    current_port=$(grep -E '^Port\s' /etc/ssh/sshd_config | awk '{print $2}' | head -1)
    if [ -z "$current_port" ]; then
        current_port=22
    fi
    echo -e "${BLUE}当前 SSH 端口: ${YELLOW}$current_port${NC}"
    
    read -p "请输入新的 SSH 端口号 (1024-65535, 留空取消): " new_port
    
    if [ -z "$new_port" ]; then
        echo -e "${YELLOW}操作已取消。${NC}"
        read -p "按回车键继续..."
        return
    fi

    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1024 ] || [ "$new_port" -gt 65535 ]; then
        echo -e "${RED}无效的端口号！端口必须是 1024 到 65535 之间的数字。${NC}"
        read -p "按回车键继续..."
        return
    fi
    
    if [ "$new_port" -eq "$current_port" ]; then
        echo -e "${YELLOW}新端口与当前端口相同，无需修改。${NC}"
        read -p "按回车键继续..."
        return
    fi
    
    echo -e "${YELLOW}正在备份 /etc/ssh/sshd_config 到 /etc/ssh/sshd_config.bak...${NC}"
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    
    echo -e "${YELLOW}正在修改 SSH 配置文件...${NC}"
    # 确保注释掉所有 Port 行，并添加新的 Port
    sed -i "/^Port\s/d" /etc/ssh/sshd_config
    echo "Port $new_port" >> /etc/ssh/sshd_config
    
    # 尝试更新防火墙规则
    echo -e "${YELLOW}正在尝试更新防火墙规则 (开放新端口)...${NC}"
    if command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --zone=public --add-port=$new_port/tcp --permanent >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
        echo -e "${GREEN}✅ Firewalld 已开放新端口 $new_port/tcp${NC}"
    elif command -v ufw >/dev/null 2>&1; then
        ufw allow $new_port/tcp >/dev/null 2>&1
        echo -e "${GREEN}✅ UFW 已开放新端口 $new_port/tcp${NC}"
    elif command -v iptables >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️ 发现 Iptables，请手动添加持久化规则，本脚本不自动添加。${NC}"
    else
        echo -e "${YELLOW}⚠️ 未发现 Firewalld 或 UFW，请手动配置防火墙开放新端口 $new_port。${NC}"
    fi

    # 尝试重启 SSH 服务
    echo -e "${YELLOW}正在重启 SSH 服务...${NC}"
    if systemctl restart sshd; then
        echo -e "${GREEN}✅ SSH 端口修改完成！请使用新端口 ${new_port} 重新连接。${NC}"
        echo -e "${RED}!!! 警告：请立即打开一个新的终端窗口，并测试新端口是否能够连接。如果连接失败，请通过 VNC/控制台恢复 /etc/ssh/sshd_config.bak 文件。 !!!${NC}"
    else
        echo -e "${RED}❌ SSH 服务重启失败！请检查日志。已回滚配置文件...${NC}"
        mv /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
        systemctl restart sshd # 尝试恢复后再次重启
    fi

    read -p "按回车键继续..."
}

# -------------------------------
# 4. 切换优先 IPV4/IPV6
# -------------------------------
toggle_ipv_priority() {
    clear
    echo -e "${CYAN}=========================================="
    echo "            切换 IPV4/IPV6 优先           "
    echo "=========================================="
    echo -e "${NC}"
    
    GAI_CONF="/etc/gai.conf"
    
    echo "请选择优先使用的网络协议："
    echo "1. 优先使用 IPv4"
    echo "2. 优先使用 IPv6"
    echo "0. 取消操作"
    read -p "请输入选项编号: " choice
    
    case $choice in
        1)
            # 优先 IPv4 (取消对 ::ffff:0:0/96 的优先，并设置 ::/0 的优先级低于 IPv4)
            echo -e "${YELLOW}正在配置优先使用 IPv4...${NC}"
            
            # 备份原始文件
            [ -f "$GAI_CONF" ] && cp "$GAI_CONF" "$GAI_CONF.bak"
            
            # 移除或注释掉所有 priority 行
            sed -i '/^#\s*precedence/!s/^\s*precedence/# precedence/g' "$GAI_CONF" 2>/dev/null
            touch "$GAI_CONF" # 如果文件不存在则创建
            sed -i '/^precedence\s*::ffff:0:0\/96/d' "$GAI_CONF"

            # 写入优先 IPv4 的配置
            echo "precedence ::ffff:0:0/96  100" >> "$GAI_CONF"
            
            echo -e "${GREEN}✅ 配置完成。系统将优先使用 IPv4。${NC}"
            ;;
        2)
            # 优先 IPv6 (确保默认优先级，同时不给 IPv4 专门的优先权)
            echo -e "${YELLOW}正在配置优先使用 IPv6 (恢复默认)...${NC}"
            
            # 备份原始文件
            [ -f "$GAI_CONF" ] && cp "$GAI_CONF" "$GAI_CONF.bak"

            # 移除或注释掉所有 priority 行
            sed -i '/^#\s*precedence/!s/^\s*precedence/# precedence/g' "$GAI_CONF" 2>/dev/null
            touch "$GAI_CONF" # 如果文件不存在则创建
            sed -i '/^precedence\s*::ffff:0:0\/96/d' "$GAI_CONF"

            echo -e "${GREEN}✅ 配置完成。系统将按默认配置优先解析 IPv6。${NC}"
            ;;
        0)
            echo -e "${YELLOW}操作已取消。${NC}"
            read -p "按回车键继续..."
            return
            ;;
        *)
            echo -e "${RED}无效的选项。${NC}"
            read -p "按回车键继续..."
            return
            ;;
    esac
    
    echo -e "${YELLOW}配置更改已应用。${NC}"
    read -p "按回车键继续..."
}

# -------------------------------
# 5. 修改主机名
# -------------------------------
change_hostname() {
    clear
    echo -e "${CYAN}=========================================="
    echo "                修改主机名                "
    echo "=========================================="
    echo -e "${NC}"
    
    current_hostname=$(hostname)
    echo -e "${BLUE}当前主机名: ${YELLOW}$current_hostname${NC}"
    
    read -p "请输入新的主机名 (留空取消): " new_hostname
    
    if [ -z "$new_hostname" ]; then
        echo -e "${YELLOW}操作已取消。${NC}"
        read -p "按回车键继续..."
        return
    fi
    
    if command -v hostnamectl >/dev/null 2>&1; then
        echo -e "${YELLOW}正在使用 hostnamectl 修改主机名...${NC}"
        hostnamectl set-hostname "$new_hostname"
    else
        echo -e "${YELLOW}正在修改 /etc/hostname 文件...${NC}"
        echo "$new_hostname" > /etc/hostname
        /bin/hostname "$new_hostname" # 立即生效
    fi
    
    # 检查并更新 /etc/hosts 文件
    if grep -q "$current_hostname" /etc/hosts; then
        echo -e "${YELLOW}正在更新 /etc/hosts 文件...${NC}"
        sed -i "s/$current_hostname/$new_hostname/g" /etc/hosts
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 主机名修改成功！新主机名: ${new_hostname}${NC}"
        echo -e "${YELLOW}请重新连接 SSH 会话以看到提示符更改。${NC}"
    else
        echo -e "${RED}❌ 主机名修改失败，请检查系统日志。${NC}"
    fi
    
    read -p "按回车键继续..."
}

# -------------------------------
# 6. 系统时区调整
# -------------------------------
change_system_timezone() {
    clear
    echo -e "${CYAN}=========================================="
    echo "              系统时区调整                "
    echo "=========================================="
    echo -e "${NC}"
    
    current_timezone=$(timedatectl show --property=Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo "未知")
    echo -e "${BLUE}当前时区: ${YELLOW}$current_timezone${NC}"
    
    echo "常用时区选项："
    echo "1. 亚洲/上海 (Asia/Shanghai) - 北京时间"
    echo "2. 亚洲/东京 (Asia/Tokyo)"
    echo "3. 欧洲/伦敦 (Europe/London)"
    echo "4. 美国/纽约 (America/New_York)"
    echo "0. 取消操作"
    read -p "请输入选项编号或直接输入时区名称 (如 Asia/Singapore): " choice
    
    case $choice in
        1) new_timezone="Asia/Shanghai" ;;
        2) new_timezone="Asia/Tokyo" ;;
        3) new_timezone="Europe/London" ;;
        4) new_timezone="America/New_York" ;;
        0) echo -e "${YELLOW}操作已取消。${NC}"; read -p "按回车键继续..."; return ;;
        *) new_timezone="$choice" ;; # 允许用户输入自定义时区
    esac
    
    if [ ! -f "/usr/share/zoneinfo/$new_timezone" ]; then
        echo -e "${RED}❌ 无效的时区名称: $new_timezone。请检查输入。${NC}"
        read -p "按回车键继续..."
        return
    fi
    
    if command -v timedatectl >/dev/null 2>&1; then
        echo -e "${YELLOW}正在使用 timedatectl 设置时区到 $new_timezone...${NC}"
        timedatectl set-timezone "$new_timezone"
    else
        echo -e "${YELLOW}正在手动设置时区到 $new_timezone...${NC}"
        ln -sf "/usr/share/zoneinfo/$new_timezone" /etc/localtime
        if [ -f /etc/timezone ]; then
            echo "$new_timezone" > /etc/timezone
        fi
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 时区设置成功！新时区: $new_timezone${NC}"
        # 再次显示当前时间确认
        current_time=$(date +'%Y-%m-%d %H:%M:%S %Z')
        echo -e "${BLUE}当前系统时间: ${YELLOW}$current_time${NC}"
    else
        echo -e "${RED}❌ 时区设置失败，请检查系统日志。${NC}"
    fi
    
    read -p "按回车键继续..."
}

# -------------------------------
# 7. 修改虚拟内存大小 (Swap)
# -------------------------------
manage_swap() {
    clear
    echo -e "${CYAN}=========================================="
    echo "            修改虚拟内存 (Swap)           "
    echo "=========================================="
    echo -e "${NC}"
    
    # 检查当前 Swap 状态
    current_swap=$(free -m | awk '/Swap:/ {print $2}')
    echo -e "${BLUE}当前 Swap 总大小: ${YELLOW}${current_swap}MB${NC}"
    
    read -p "请输入新的 Swap 文件大小 (MB，输入 0 表示禁用，留空取消): " swap_size_mb
    
    if [ -z "$swap_size_mb" ]; then
        echo -e "${YELLOW}操作已取消。${NC}"
        read -p "按回车键继续..."
        return
    fi

    if ! [[ "$swap_size_mb" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}无效输入！请输入纯数字大小 (MB)。${NC}"
        read -p "按回车键继续..."
        return
    fi
    
    SWAP_FILE="/swapfile"
    
    if [ "$swap_size_mb" -eq 0 ]; then
        # 禁用 Swap
        echo -e "${YELLOW}正在禁用和删除 Swap 文件...${NC}"
        if swapoff "$SWAP_FILE" 2>/dev/null; then
            echo -e "${GREEN}✅ 已禁用 Swap。${NC}"
        fi
        if rm -f "$SWAP_FILE"; then
            echo -e "${GREEN}✅ 已删除 Swap 文件 $SWAP_FILE。${NC}"
        fi
        
        # 从 fstab 中移除
        sed -i '\/swapfile/d' /etc/fstab
        echo -e "${GREEN}✅ Swap 已清理完成。${NC}"
    elif [ "$swap_size_mb" -gt 0 ]; then
        # 创建或调整 Swap
        echo -e "${YELLOW}正在创建/调整 Swap 文件到 ${swap_size_mb}MB...${NC}"
        
        # 禁用现有 Swap
        swapoff "$SWAP_FILE" 2>/dev/null
        
        # 创建新的 Swap 文件 (block size = 1M)
        if command -v fallocate >/dev/null 2>&1; then
            fallocate -l "${swap_size_mb}M" "$SWAP_FILE"
        else
            dd if=/dev/zero of="$SWAP_FILE" bs=1M count="$swap_size_mb"
        fi
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ Swap 文件创建失败！${NC}"
            read -p "按回车键继续..."
            return
        fi

        chmod 600 "$SWAP_FILE"
        mkswap "$SWAP_FILE"
        swapon "$SWAP_FILE"
        
        # 更新 fstab (确保只有一行)
        sed -i '\/swapfile/d' /etc/fstab
        echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
        
        # 设置 Swappiness
        sysctl vm.swappiness=10
        echo "vm.swappiness=10" >> /etc/sysctl.conf

        echo -e "${GREEN}✅ Swap 创建/调整成功！新大小：$(free -m | awk '/Swap:/ {print $2}')MB${NC}"
    fi

    read -p "按回车键继续..."
}


# -------------------------------
# 8. 重启服务器
# -------------------------------
reboot_server() {
    clear
    echo -e "${CYAN}=========================================="
    echo "                重启服务器                "
    echo "=========================================="
    echo -e "${NC}"
    
    echo -e "${RED}!!! 警告：此操作将立即重启您的服务器！ !!!${NC}"
    read -p "确定要重启吗？(y/N): " confirm
    
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        echo -e "${YELLOW}正在发送重启命令...${NC}"
        # 使用 shutdown 命令提供倒计时和警告
        shutdown -r now "System reboot initiated by script"
    else
        echo -e "${YELLOW}操作已取消。${NC}"
    fi
    
    read -p "按回车键继续..."
}

# -------------------------------
# 9. 卸载本脚本
# -------------------------------
uninstall_script() {
    clear
    echo -e "${CYAN}=========================================="
    echo "                卸载本脚本                "
    echo "=========================================="
    echo -e "${NC}"
    
    # 获取当前脚本的绝对路径
    SCRIPT_PATH=$(readlink -f "$0")
    
    echo -e "${RED}!!! 警告：此操作将删除脚本文件：$SCRIPT_PATH !!!${NC}"
    read -p "确定要删除本脚本文件吗？(y/N): " confirm
    
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        echo -e "${YELLOW}正在删除脚本文件...${NC}"
        rm -f "$SCRIPT_PATH"
        
        # 尝试删除可能创建的临时文件
        rm -f "$RESULT_FILE"
        
        echo -e "${GREEN}✅ 脚本卸载完成！${NC}"
        echo -e "${YELLOW}程序即将退出。请手动清除您的终端历史记录。${NC}"
        exit 0 # 立即退出脚本执行
    else
        echo -e "${YELLOW}操作已取消。${NC}"
    fi
    
    read -p "按回车键继续..."
}

# -------------------------------
# 系统工具主菜单 (更新，调用实际函数)
# -------------------------------
system_tools_menu() {
    while true; do
        clear
        echo -e "${CYAN}"
        echo "=========================================="
        echo "              系统工具菜单                "
        echo "=========================================="
        echo -e "${NC}"
        echo "1. 高级防火墙管理"
        echo "2. 修改登录密码"
        echo "3. 修改 SSH 连接端口"
        echo "4. 切换优先 IPV4/IPV6"
        echo "5. 修改主机名"
        echo "6. 系统时区调整"
        echo "7. 修改虚拟内存大小 (Swap)"
        echo "8. 重启服务器"
        echo "9. 卸载本脚本"
        echo "0. 返回主菜单"
        echo "=========================================="

        read -p "请输入选项编号: " tools_choice

        case $tools_choice in
            1) advanced_firewall_menu ;;
            2) change_login_password ;;
            3) change_ssh_port ;;
            4) toggle_ipv_priority ;;
            5) change_hostname ;;
            6) change_system_timezone ;;
            7) manage_swap ;;
            8) reboot_server ;;
            9) uninstall_script ;;
            0) return ;;
            *) echo -e "${RED}无效的选项，请重新输入！${NC}"; sleep 1 ;;
        esac
    done
}

# -------------------------------
# 运行VPS网络测试
# -------------------------------
vps_network_test() {
    clear
    echo -e "${CYAN}=========================================="
    echo "            VPS网络全面测试             "
    echo "=========================================="
    echo -e "${NC}"
    echo -e "${YELLOW}正在下载并运行网络测试脚本...${NC}"
    echo -e "${BLUE}来源: NodeQuality.com${NC}"
    
    # 检查是否安装curl
    if ! command -v curl &> /dev/null; then
        echo -e "${YELLOW}未检测到curl，正在尝试安装...${NC}"
        if command -v apt &> /dev/null; then
            apt update -y && apt install -y curl
        elif command -v yum &> /dev/null; then
            yum install -y curl
        elif command -v dnf &> /dev/null; then
            dnf install -y curl
        else
            echo -e "${RED}无法安装curl，请手动安装后重试${NC}"
            read -p "按回车键返回主菜单..."
            return
        fi
    fi
    
    # 运行网络测试
    echo -e "${GREEN}✅ 开始网络测试...${NC}"
    echo -e "${YELLOW}这可能需要几分钟时间，请耐心等待...${NC}"
    bash <(curl -sL https://run.NodeQuality.com)
    
    echo -e "${CYAN}"
    echo "=========================================="
    echo -e "${NC}"
    read -p "测试完成，按回车键返回主菜单..."
}

# ====================================================================
# +++ 主菜单函数更新 +++
# ====================================================================

show_menu() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "       CGG-VPS 脚本管理菜单 v0.9           "
    echo "=========================================="
    echo -e "${NC}"
    echo "1. 系统信息查询"
    echo "2. 系统更新"
    echo "3. 系统清理"
    echo "4. 基础工具"
    echo "5. BBR管理"
    echo "6. Docker管理"
    echo "7. 系统工具"
    echo "8. VPS测试IP网络"
    echo "0. 退出脚本"
    echo "=========================================="
}

# ====================================================================
# +++ 主执行逻辑更新 +++
# ====================================================================

# 脚本启动时，首先检查root权限和依赖
check_root
check_deps

# 无限循环，直到用户选择退出
while true; do
    show_menu
    read -p "请输入你的选择 (0-8): " main_choice

    case $main_choice in
        1)
            system_info
            ;;
        2)
            system_update
            ;;
        3)
            system_clean
            ;;
        4)
            basic_tools
            ;;
        5)
            bbr_management
            ;;
        6)
            docker_management_menu
            ;;
        7)
            system_tools_menu
            ;;
        8)
            vps_network_test
            ;;
        0)
            echo -e "${GREEN}感谢使用，正在退出脚本...${NC}"
            exit 0  # 改为 exit 0 确保完全退出
            ;;
        *)
            echo -e "${RED}无效的选项，请重新输入！${NC}"
            sleep 1
            ;;
    esac
done
