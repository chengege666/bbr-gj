#!/bin/bash

# VPS一键管理脚本 v0.7 (包含系统工具增强)
# 作者: 智能助手 (基于用户提供的代码修改)
# 最后更新: 2025-10-27

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
# 显示菜单函数
# -------------------------------
show_menu() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "          VPS 脚本管理菜单 v0.7           "
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
# 检查BBR状态函数 (略，保持不变)
# -------------------------------
check_bbr() {
    local bbr_enabled=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    local bbr_module=$(lsmod | grep bbr)
    local default_qdisc=$(sysctl net.core.default_qdisc | awk '{print $3}')
    local bbr_params=$(sysctl -a 2>/dev/null | grep -E "bbr|tcp_congestion_control" | grep -v '^net.core' | sort)
    local bbr_version=""
    if [[ "$bbr_enabled" == *"bbr"* ]]; then
        if [[ "$bbr_enabled" == "bbr" ]]; then
            bbr_version="BBR v1"
        elif [[ "$bbr_enabled" == "bbr2" ]]; then
            bbr_version="BBR v2"
        else
            bbr_version="未知BBR类型"
        fi
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

# -------------------------------
# 系统信息查询函数 (略，保持不变)
# -------------------------------
system_info() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "              系统信息查询                "
    echo "=========================================="
    echo -e "${NC}"
    echo -e "${BLUE}主机名: ${GREEN}$(hostname)${NC}"
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        echo -e "${BLUE}操作系统: ${NC}$PRETTY_NAME"
    else
        echo -e "${BLUE}操作系统: ${NC}未知"
    fi
    echo -e "${BLUE}内核版本: ${NC}$(uname -r)"
    cpu_model=$(grep 'model name' /proc/cpuinfo | head -1 | cut -d ':' -f2 | sed 's/^ *//')
    cpu_cores=$(grep -c '^processor' /proc/cpuinfo)
    echo -e "${BLUE}CPU型号: ${NC}$cpu_model"
    echo -e "${BLUE}CPU核心数: ${NC}$cpu_cores"
    total_mem=$(free -m | awk '/Mem:/ {print $2}')
    available_mem=$(free -m | awk '/Mem:/ {print $7}')
    echo -e "${BLUE}总内存: ${NC}${total_mem}MB"
    echo -e "${BLUE}可用内存: ${NC}${available_mem}MB"
    disk_usage=$(df -h / | awk 'NR==2 {print $5}')
    disk_total=$(df -h / | awk 'NR==2 {print $2}')
    disk_used=$(df -h / | awk 'NR==2 {print $3}')
    echo -e "${BLUE}根分区使用率: ${NC}$disk_usage (已用 ${disk_used} / 总共 ${disk_total})"
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
    ipv6=$(curl -s --connect-timeout 2 ipv6.icanhazip.com)
    if [ -z "$ipv6" ]; 键，然后
        ipv6=$(curl -s --connect-timeout 2 ipv6.ip.sb)
    fi
    if [ -z "$ipv6" ]; 键，然后
        ipv6="${RED}未检测到${NC}"
    else
        ipv6="${YELLOW}$ipv6${NC}"
    fi
    echo -e "${BLUE}公网IPv6: $ipv6"
    echo -e "${BLUE}BBR状态: ${NC}"
    check_bbr
    uptime_info=$(uptime -p | sed 's/up //')
    echo -e "${BLUE}系统运行时间: ${NC}$uptime_info"
    beijing_time=$(TZ='Asia/Shanghai' date +'%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}北京时间: ${NC}$beijing_time"
    echo -e "${CYAN}"
    echo "=========================================="
    echo -e "${NC}"
    read -p "按回车键返回主菜单..."
}

# -------------------------------
# 系统更新函数 (略，保持不变)
# -------------------------------
system_update() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "              系统更新功能                "
    echo "=========================================="
    echo -e "${NC}"
    if [ -f /etc/debian_version ]; 键，然后
        echo -e "${BLUE}检测到 Debian/Ubuntu 系统${NC}"
        echo -e "${YELLOW}开始更新系统...${NC}"
        echo -e "${BLUE}[步骤1/3] 更新软件包列表...${NC}"; apt update
        echo -e "${BLUE}[步骤2/3] 升级软件包...${NC}"; apt upgrade -y
        echo -e "${BLUE}[步骤3/3] 清理系统...${NC}"; apt autoremove -y; apt autoclean
        echo -e "${GREEN}系统更新完成！${NC}"
    elif [ -f /etc/redhat-release ]; then
        echo -e "${BLUE}检测到 CentOS/RHEL 系统${NC}"
        echo -e "${YELLOW}开始更新系统...${NC}"
        echo -e "${BLUE}[步骤1/2] 更新软件包...${NC}"; yum update -y
        echo -e "${BLUE}[步骤2/2] 清理系统...${NC}"; yum clean all; yum autoremove -y
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

# -------------------------------
# 系统清理函数 (略，保持不变)
# -------------------------------
system_clean() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "              系统清理功能                "
    echo "=========================================="
    echo -e "${NC}"
    echo -e "${YELLOW}⚠️ 警告：系统清理操作将删除不必要的文件，请谨慎操作！${NC}"
    read -p "是否继续执行系统清理？(y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}已取消系统清理操作${NC}"
        read -p "按回车键返回主菜单..."
        return
    fi
    if [ -f /etc/debian_version ]; 键，然后
        echo -e "${BLUE}检测到 Debian/Ubuntu 系统${NC}"
        echo -e "${YELLOW}开始清理系统...${NC}"
        echo -e "${BLUE}[步骤1/4] 清理APT缓存...${NC}"; apt clean
        echo -e "${BLUE}[步骤2/4] 清理旧内核...${NC}"; apt autoremove --purge -y
        echo -e "${BLUE}[步骤3/4] 清理日志文件...${NC}"; journalctl --vacuum-time=1d; find /var/log -type f -regex ".*\.gz$" -delete; find /var/log -type f -regex ".*\.[0-9]$" -delete
        echo -e "${BLUE}[步骤4/4] 清理临时文件...${NC}"; rm -rf /tmp/*; rm -rf /var/tmp/*
        echo -e "${GREEN}系统清理完成！${NC}"
    elif [ -f /etc/redhat-release ]; 键，然后
        echo -e "${BLUE}检测到 CentOS/RHEL 系统${NC}"
        echo -e "${YELLOW}开始清理系统...${NC}"
        echo -e "${BLUE}[步骤1/4] 清理YUM缓存...${NC}"; yum clean all
        echo -e "${BLUE}[步骤2/4] 清理旧内核...${NC}"; package-cleanup --oldkernels --count=1 -y
        echo -e "${BLUE}[步骤3/4] 清理日志文件...${NC}"; journalctl --vacuum-time=1d; find /var/log -type f -regex ".*\.gz$" -delete; find /var/log -type f -regex ".*\.[0-9]$" -delete
        echo -e "${BLUE}[步骤4/4] 清理临时文件...${NC}"; rm -rf /tmp/*; rm -rf /var/tmp/*
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

# -------------------------------
# 基础工具安装函数 (略，保持不变)
# -------------------------------
basic_tools() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "              基础工具安装                "
    echo "=========================================="
    echo -e "${NC}"
    DEBIAN_TOOLS="htop vim tmux net-tools dnsutils lsof tree zip unzip"
    REDHAT_TOOLS="htop vim tmux net-tools bind-utils lsof tree zip unzip"
    if [ -f /etc/debian_version ]; then
        echo -e "${BLUE}检测到 Debian/Ubuntu 系统${NC}"
        echo -e "${YELLOW}开始安装基础工具...${NC}"
        echo -e "${BLUE}[步骤1/2] 更新软件包列表...${NC}"; apt update -y
        echo -e "${BLUE}[步骤2/2] 安装基础工具...${NC}"; apt install -y $DEBIAN_TOOLS
        echo -e "${GREEN}基础工具安装完成！${NC}"
        echo -e "${YELLOW}已安装工具: $DEBIAN_TOOLS${NC}"
    elif [ -f /etc/redhat-release ]; then
        echo -e "${BLUE}检测到 CentOS/RHEL 系统${NC}"
        echo -e "${YELLOW}开始安装基础工具...${NC}"
        echo -e "${BLUE}[步骤1/1] 安装基础工具...${NC}"; yum install -y epel-release; yum install -y $REDHAT_TOOLS
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

# -------------------------------
# BBR 相关函数 (略，保持不变)
# -------------------------------
run_test() {
    local mode="$1"
    local result=""
    if ! command -v speedtest >/dev/null 2>&1; then
        echo -e "${RED}❌❌ 错误：未安装 'speedtest-cli' 或 'speedtest' 命令。${NC}"
        echo -e "${YELLOW}请先安装 speedtest-cli (如：pip install speedtest-cli)。${NC}"
        return 1
    fi
    echo -e "${YELLOW}正在测试: $mode${NC}"
    case "$mode" in
        "BBR") sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1 ;;
        "BBR Plus") sysctl -w net.ipv4.tcp_congestion_control=bbr_plus >/dev/null 2>&1 ;;
        "BBRv2") sysctl -w net.ipv4.tcp_congestion_control=bbr2 >/dev/null 2>&1 ;;
        "BBRv3") sysctl -w net.ipv4.tcp_congestion_control=bbr3 >/dev/null 2>&1 ;;
        *) echo -e "${RED}未知模式: $mode${NC}"; return 1 ;;
    esac
    local check_cc=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    if [[ "$check_cc" != *"$mode"* ]]; then
        echo -e "${RED}配置失败: $mode 算法可能未加载或不支持${NC}"
        echo "$mode: 配置失败/不支持" >> "$RESULT_FILE"
        return 1
    fi
    result=$(speedtest --simple --timeout 15 2>&1)
    if echo "$result" | grep -q "ERROR"; then
        echo -e "${RED}测试失败: $mode${NC}"
        echo "$mode: 测试失败" >> "$RESULT_FILE"
    else
        local ping=$(echo "$result" | grep "Ping" | awk '{print $2}')
        local download=$(echo "$result" | grep "Download" | awk '{print $2}')
        local upload=$(echo "$result" | grep "Upload" | awk '{print $2}')
        echo -e "  ${BLUE}延迟: ${GREEN}$ping ms${NC}"
        echo -e "  ${BLUE}下载: ${GREEN}$download Mbps${NC}"
        echo -e "  ${BLUE}上传: ${GREEN}$upload Mbps${NC}"
        echo "$mode: 延迟 ${ping}ms | 下载 ${download}Mbps | 上传 ${upload}Mbps" >> "$RESULT_FILE"
    fi
    echo ""
}

bbr_test_menu() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "              BBR 综合测速                "
    echo "=========================================="
    echo -e "${NC}"
    echo -e "${YELLOW}⚠️ 注意：此测试将临时修改网络配置${NC}"
    echo -e "${YELLOW}测试完成后将恢复原始设置${NC}"
    echo ""
    local current_cc=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    > "$RESULT_FILE"
    for MODE in "BBR" "BBR Plus" "BBRv2" "BBRv3"; do
        run_test "$MODE"
    done
    sysctl -w net.ipv4.tcp_congestion_control="$current_cc" >/dev/null 2>&1
    echo -e "${CYAN}=== 测试完成，结果汇总 ===${NC}"
    if [ -f "$RESULT_FILE" ] && [ -s "$RESULT_FILE" ]; then
        cat "$RESULT_FILE"
    else
        echo -e "${YELLOW}无测速结果（请确保已安装 speedtest-cli）${NC}"
    fi
    echo -e "${CYAN}"
    echo "=========================================="
    echo -e "${NC}"
    read -p "按回车键返回BBR管理菜单..."
}

run_bbr_switch() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "            BBR 内核安装/切换             "
    echo "=========================================="
    echo -e "${NC}"
    echo -e "${YELLOW}正在下载并运行 BBR 切换脚本...${NC}"
    echo -e "${YELLOW}来源: ylx2016/Linux-NetSpeed${NC}"
    echo ""
    wget -O tcp.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcp.sh"
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌❌ 下载脚本失败，请检查网络连接${NC}"
        read -p "按回车键返回BBR管理菜单..."
        return
    fi
    chmod +x tcp.sh
    ./tcp.sh
    rm -f tcp.sh
    echo -e "${CYAN}"
    echo "=========================================="
    echo -e "${NC}"
    read -p "按回车键返回BBR管理菜单..."
}

bbr_management() {
    while true; do
        clear
        echo -e "${CYAN}"
        echo "=========================================="
        echo "              BBR 管理菜单                "
        echo "=========================================="
        echo -e "${NC}"
        echo "1. BBR综合测速"
        echo "2. 安装/切换BBR内核"
        echo "3. 查看当前BBR状态"
        echo "0. 返回主菜单"
        echo "=========================================="
        read -p "请输入选项编号: " bbr_choice
        case $bbr_choice in
            1) bbr_test_menu ;;
            2) run_bbr_switch ;;
            3)
                clear
                echo -e "${CYAN}"
                echo "=========================================="
                echo "              当前BBR状态                 "
                echo "=========================================="
                echo -e "${NC}"
                check_bbr
                echo ""
                read -p "按回车键返回BBR管理菜单..."
                ;;
            0) return ;;
            *) echo -e "${RED}无效的选项，请重新输入！${NC}"; sleep 1 ;;
        esac
    done
}

# -------------------------------
# Docker 相关函数 (略，保持不变)
# -------------------------------
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
        apt update; apt install -y curl wget
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
# +++ 新增系统工具功能 +++
# ====================================================================

# -------------------------------
# 1. 修改登录密码
# -------------------------------
change_user_password() {
    clear
    echo -e "${CYAN}=== 修改登录密码 ===${NC}"
    echo -e "${YELLOW}警告：此操作将立即修改指定用户的密码！${NC}"
    
    read -p "请输入要修改密码的用户名 (通常为 root 或当前用户): " user_name
    
    if id "$user_name" &>/dev/null; then
        echo -e "${YELLOW}正在为用户 ${user_name} 修改密码...${NC}"
        passwd "$user_name"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ 用户 ${user_name} 的密码修改成功！${NC}"
        else
            echo -e "${RED}❌ 密码修改失败，请检查输入或权限。${NC}"
        fi
    else
        echo -e "${RED}❌ 错误：用户 ${user_name} 不存在。${NC}"
    fi
    read -p "按回车键返回..."
}

# -------------------------------
# 2. 修改 SSH 连接端口
# -------------------------------
change_ssh_port() {
    clear
    echo -e "${CYAN}=== 修改 SSH 连接端口 ===${NC}"
    
    local sshd_config="/etc/ssh/sshd_config"
    
    if [ ! -f "$sshd_config" ]; then
        echo -e "${RED}❌ 错误：未找到 SSH 配置文件 ($sshd_config)。${NC}"
        read -p "按回车键返回..."
        return
    fi
    
    local current_port=$(grep -E '^\s*Port\s+[0-9]+' "$sshd_config" | awk '{print $2}' | head -1)
    if [ -z "$current_port" ]; then
        current_port="22 (默认)"
    fi
    echo -e "${BLUE}当前 SSH 端口: ${YELLOW}$current_port${NC}"
    
    read -p "请输入新的 SSH 端口号 (1025-65535): " new_port
    
    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1025 ] || [ "$new_port" -gt 65535 ]; then
        echo -e "${RED}❌ 错误：端口号无效或不在安全范围 (1025-65535)。${NC}"
        read -p "按回车键返回..."
        return
    fi
    
    echo -e "${YELLOW}正在将 SSH 端口从 ${current_port} 修改为 ${new_port}...${NC}"

    # 替换或添加 Port 配置
    if grep -E '^\s*#?\s*Port\s+[0-9]+' "$sshd_config"; then
        # 如果找到 Port 行（无论是否被注释），则修改它
        sed -i -E "s/^\s*#?\s*Port\s+[0-9]+/Port $new_port/" "$sshd_config"
    else
        # 如果未找到，则在文件末尾添加
        echo "Port $new_port" >> "$sshd_config"
    fi
    
    # 针对 CentOS/RHEL 检查 SELinux 端口
    if command -v semanage &>/dev/null; then
        echo -e "${YELLOW}正在检查并配置 SELinux 端口...${NC}"
        if semanage port -l | grep -q "ssh_port_t.* $new_port"; then
            echo -e "${GREEN}✅ SELinux 端口已配置。${NC}"
        else
            semanage port -a -t ssh_port_t -p tcp "$new_port"
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✅ SELinux 端口 $new_port 已添加。${NC}"
            else
                echo -e "${YELLOW}⚠️ 无法自动配置 SELinux 端口，请手动处理。${NC}"
            fi
        fi
    fi
    
    # 针对防火墙 (firewalld 或 UFW)
    if command -v firewall-cmd &>/dev/null; then
        echo -e "${YELLOW}正在配置 Firewalld...${NC}"
        firewall-cmd --zone=public --add-port="$new_port/tcp" --permanent
        firewall-cmd --reload
        echo -e "${GREEN}✅ Firewalld 已更新。${NC}"
    elif command -v ufw &>/dev/null; then
        echo -e "${YELLOW}正在配置 UFW...${NC}"
        ufw allow "$new_port/tcp"
        ufw reload
        echo -e "${GREEN}✅ UFW 已更新。${NC}"
    else
        echo -e "${YELLOW}⚠️ 未检测到 firewalld 或 ufw，请手动配置防火墙。${NC}"
    fi

    # 重启 SSH 服务
    echo -e "${YELLOW}正在重启 SSH 服务...${NC}"
    systemctl restart sshd
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ SSH 端口修改成功，新端口：${new_port}${NC}"
        echo -e "${RED}请立即使用新端口 ${new_port} 重新连接，旧端口可能已失效！${NC}"
    else
        echo -e "${RED}❌ SSH 服务重启失败，请检查配置文件！${NC}"
    fi
    read -p "按回车键返回..."
}


# -------------------------------
# 3. 切换优先 IPV4/IPV6
# -------------------------------
switch_ip_priority() {
    clear
    echo -e "${CYAN}=== 切换 IP 优先顺序 ===${NC}"
    
    local gai_config="/etc/gai.conf"
    local ipv4_line="precedence ::ffff:0:0/96  100"
    
    echo "1. 优先使用 IPv4 (默认设置)"
    echo "2. 优先使用 IPv6"
    echo "0. 返回上级菜单"
    echo ""
    read -p "请选择优先顺序: " ip_choice
    
    if [ ! -f "$gai_config" ]; then
        echo -e "${YELLOW}⚠️ 配置文件 ${gai_config} 不存在，尝试创建。${NC}"
        touch "$gai_config"
    fi
    
    case $ip_choice in
        1)
            # 优先 IPv4: 确保 precedence ::ffff:0:0/96  100 存在且启用
            if grep -qF "$ipv4_line" "$gai_config"; then
                # 如果已存在，确保没有被注释
                sed -i "/$ipv4_line/s/^#//" "$gai_config"
            else
                # 如果不存在，添加并启用
                echo "$ipv4_line" >> "$gai_config"
            fi
            # 确保 IPv6 的默认行被注释
            sed -i '/precedence ::1/s/^/#/' "$gai_config"
            
            echo -e "${GREEN}✅ 已设置为：优先使用 IPv4${NC}"
            ;;
        2)
            # 优先 IPv6: 注释 IPv4 优先行
            sed -i "/$ipv4_line/s/^/#/" "$gai_config"
            # 确保 IPv6 的默认行（如果有）未被注释
            sed -i '/precedence ::1/s/^#//' "$gai_config"

            echo -e "${GREEN}✅ 已设置为：优先使用 IPv6${NC}"
            ;;
        0)
            echo -e "${YELLOW}操作取消。${NC}"
            read -p "按回车键返回..."
            return
            ;;
        *)
            echo -e "${RED}无效选择。${NC}"
            read -p "按回车键返回..."
            return
            ;;
    esac
    
    echo -e "${YELLOW}配置已更新。由于系统库缓存，部分应用可能需要重启才能生效。${NC}"
    read -p "按回车键返回..."
}

# -------------------------------
# 4. 修改主机名
# -------------------------------
change_hostname() {
    clear
    echo -e "${CYAN}=== 修改主机名 ===${NC}"
    local current_hostname=$(hostname)
    echo -e "${BLUE}当前主机名: ${YELLOW}$current_hostname${NC}"
    
    read -p "请输入新的主机名: " new_hostname
    
    if [ -z "$new_hostname" ]; then
        echo -e "${RED}❌ 主机名不能为空。${NC}"
        read -p "按回车键返回..."
        return
    fi
    
    echo -e "${YELLOW}正在将主机名修改为 ${new_hostname}...${NC}"
    
    # 使用 hostnamectl 设置主机名 (适用于大多数现代系统)
    if command -v hostnamectl &>/dev/null; 键，然后
        hostnamectl set-hostname "$new_hostname"
        if [ $? -eq 0 ]; 键，然后
            echo -e "${GREEN}✅ 主机名修改成功。${NC}"
            echo -e "${YELLOW}新主机名: $(hostname)${NC}"
        else
            echo -e "${RED}❌ hostnamectl 命令执行失败。${NC}"
        fi
    else
        # 针对旧系统，直接修改配置文件
        if [ -f /etc/hostname ]; 键，然后
            echo "$new_hostname" > /etc/hostname
            hostname -F /etc/hostname
            echo -e "${GREEN}✅ 主机名文件 /etc/hostname 已更新。${NC}"
        else
            echo -e "${RED}❌ 警告：未找到 hostnamectl 且 /etc/hostname 不存在。请手动修改。${NC}"
        fi
    fi
    
    # 建议同时更新 /etc/hosts 文件，防止解析错误
    if [ -f /etc/hosts ]; 键，然后
        sed -i "s/127.0.0.1\s\+$current_hostname/127.0.0.1\t$new_hostname/" /etc/hosts
    fi
    
    echo -e "${YELLOW}配置已更新。但为了完全生效，建议重启服务器。${NC}"
    read -p "按回车键返回..."
}

# -------------------------------
# 5. 系统时区调整
# -------------------------------
change_timezone() {
    clear
    echo -e "${CYAN}=== 系统时区调整 ===${NC}"
    
    if command -v timedatectl &>/dev/null; 键，然后
        echo -e "${BLUE}当前时区: ${YELLOW}$(timedatectl | grep 'Time zone' | awk '{print $3}')${NC}"
        echo ""
        echo "常用时区列表:"
        echo "1. Asia/Shanghai (北京时间)"
        echo "2. Asia/Tokyo (东京时间)"
        echo "3. America/New_York (美国东部时间)"
        echo "4. Europe/London (格林尼治时间)"
        echo "5. 使用 timedatectl list-timezones 查看全部"
        echo "0. 返回上级菜单"
        echo ""
        read -p "请输入选项编号或完整时区名称 (如 Asia/Hong_Kong): " tz_choice

        local new_timezone
        case $tz_choice in
            1) new_timezone="Asia/Shanghai" ;;
            2) new_timezone="Asia/Tokyo" ;;
            3) new_timezone="America/New_York" ;;
            4) new_timezone="Europe/London" ;;
            5) timedatectl list-timezones | less; read -p "请输入完整时区名称: " new_timezone ;;
            0) echo -e "${YELLOW}操作取消。${NC}"; read -p "按回车键返回..." ; return ;;
            *) new_timezone="$tz_choice" ;;
        esac

        if [ -z "$new_timezone" ]; then
            echo -e "${RED}❌ 时区不能为空。${NC}"
            read -p "按回车键返回..."
            return
        fi

        echo -e "${YELLOW}正在设置时区为 ${new_timezone}...${NC}"
        timedatectl set-timezone "$new_timezone"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ 时区设置成功！${NC}"
            echo -e "${BLUE}新时区: ${YELLOW}$(timedatectl | grep 'Time zone' | awk '{print $3}')${NC}"
        else
            echo -e "${RED}❌ 时区设置失败，请检查时区名称是否正确。${NC}"
        fi
        
    elif command -v dpkg-reconfigure &>/dev/null && [ -f /etc/debian_version ]; then
        echo -e "${YELLOW}正在使用 dpkg-reconfigure 进行时区设置...${NC}"
        dpkg-reconfigure tzdata
    elif command -v tzselect &>/dev/null; then
        echo -e "${YELLOW}正在使用 tzselect 进行时区设置...${NC}"
        tzselect
        # tzselect 输出最终命令，需要用户手动执行或捕获
        echo -e "${YELLOW}⚠️ 请根据 tzselect 的提示手动设置时区！${NC}"
    else
        echo -e "${RED}❌ 未找到 timedatectl 或其他配置工具。请手动操作：ln -sf /usr/share/zoneinfo/时区 /etc/localtime${NC}"
    fi

    read -p "按回车键返回..."
}

# -------------------------------
# 6. 重启服务器
# -------------------------------
reboot_server() {
    clear
    echo -e "${RED}!!! 警告：您确定要立即重启服务器吗？ !!!${NC}"
    read -p "输入 'yes' 确认重启: " confirm
    
    if [ "$confirm" == "yes" ]; then
        echo -e "${YELLOW}服务器将在 5 秒后重启...${NC}"
        sleep 5
        reboot
    else
        echo -e "${GREEN}已取消重启操作。${NC}"
    fi
    read -p "按回车键返回..."
}

# -------------------------------
# 7. 修改虚拟内存大小 (Swap)
# -------------------------------
change_swap_size() {
    clear
    echo -e "${CYAN}=== 修改虚拟内存大小 (Swap) ===${NC}"
    
    local swapfile="/swapfile"
    
    # 检查当前 Swap 状态
    echo -e "${BLUE}当前 Swap 使用情况:${NC}"
    free -h | grep -E 'Swap|交换'
    
    # 询问新的 Swap 大小
    read -p "请输入新的 Swap 文件大小 (MB, 0为禁用): " new_size_mb
    
    if ! [[ "$new_size_mb" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}❌ 输入无效，必须是数字。${NC}"
        read -p "按回车键返回..."
        return
    fi
    
    if [ "$new_size_mb" -eq 0 ]; then
        # 禁用并删除 Swap
        if swapon -s | grep -q "$swapfile"; then
            echo -e "${YELLOW}正在禁用 Swap...${NC}"
            swapoff "$swapfile"
        fi
        if [ -f "$swapfile" ]; then
            echo -e "${YELLOW}正在删除 Swap 文件...${NC}"
            rm -f "$swapfile"
            # 清除 fstab 配置
            sed -i "/$swapfile/d" /etc/fstab
            echo -e "${GREEN}✅ Swap 已禁用并清理完成。${NC}"
        else
            echo -e "${YELLOW}⚠️ 未检测到 Swap 文件，操作完成。${NC}"
        fi
    elif [ "$new_size_mb" -gt 0 ]; then
        local new_size_bytes=$((new_size_mb * 1024 * 1024))

        echo -e "${YELLOW}正在设置新的 Swap 大小为 ${new_size_mb}MB...${NC}"

        # 1. 禁用当前 Swap
        if swapon -s | grep -q "$swapfile"; then
            echo -e "${YELLOW}正在禁用旧 Swap...${NC}"
            swapoff "$swapfile"
        fi
        
        # 2. 删除旧文件 (如果存在)
        if [ -f "$swapfile" ]; then
            rm -f "$swapfile"
        fi

        # 3. 创建新的 Swap 文件 (使用 dd 或 fallocate)
        echo -e "${YELLOW}正在创建 ${new_size_mb}MB 的 Swap 文件...${NC}"
        if command -v fallocate &>/dev/null; then
            fallocate -l "${new_size_bytes}" "$swapfile"
        else
            dd if=/dev/zero of="$swapfile" bs=1M count="$new_size_mb"
        fi

        # 4. 设置权限和格式化
        chmod 600 "$swapfile"
        mkswap "$swapfile"

        # 5. 启用新的 Swap
        swapon "$swapfile"

        # 6. 配置 fstab 永久启用
        # 清除 fstab 旧配置
        sed -i "/$swapfile/d" /etc/fstab
        # 添加新配置
        echo "$swapfile none swap sw 0 0" >> /etc/fstab

        # 7. 调整 swappiness (可选，设置为10)
        sysctl vm.swappiness=10
        if ! grep -q "vm.swappiness=10" /etc/sysctl.conf; then
            echo "vm.swappiness=10" >> /etc/sysctl.conf
        fi
        
        echo -e "${GREEN}✅ Swap 文件已成功设置为 ${new_size_mb}MB${NC}"
    else
        echo -e "${RED}❌ 操作失败。${NC}"
    fi

    # 再次显示 Swap 状态
    echo -e "${BLUE}新 Swap 使用情况:${NC}"
    free -h | grep -E 'Swap|交换'

    read -p "按回车键返回..."
}


# -------------------------------
# 脚本卸载函数 (略，保持不变)
# -------------------------------
uninstall_script() {
    clear
    echo -e "${RED}⚠️ 警告：此操作将卸载本管理脚本并清理相关文件！${NC}"
    echo ""
    echo -e "${YELLOW}将执行以下操作：${NC}"
    echo "1. 删除本脚本文件 (${0})"
    echo "2. 删除临时结果文件 (${RESULT_FILE})"
    read -p "是否清理脚本安装的依赖包 (curl, wget, git, net-tools)? (y/N): " clean_deps_confirm
    read -p "确定要继续卸载本脚本吗？(y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then echo -e "${YELLOW}已取消脚本卸载操作${NC}"; read -p "按回车键返回主菜单..."; return; fi
    
    SCRIPT_PATH="$0"
    if [ -f "$RESULT_FILE" ]; then rm -f "$RESULT_FILE"; echo -e "${GREEN}✅ 临时结果文件 $RESULT_FILE 已清理。${NC}"; fi
    
    if [[ "$clean_deps_confirm" == "y" || "$clean_deps_confirm" == "Y" ]]; then
        PKGS_TO_REMOVE="curl wget git net-tools"
        if command -v apt >/dev/null 2>&1; then apt purge -y $PKGS_TO_REMOVE; apt autoremove -y; elif command -v yum >/dev/null 2>&1; then yum remove -y $PKGS_TO_REMOVE; yum autoremove -y; elif command -v dnf >/dev/null 2>&1; then dnf remove -y $PKGS_TO_REMOVE; dnf autoremove -y; else echo -e "${YELLOW}⚠️ 未知系统，请手动卸载依赖包: $PKGS_TO_REMOVE${NC}"; fi
        echo -e "${GREEN}✅ 依赖包清理完成。${NC}"
    else
        echo -e "${YELLOW}跳过依赖包清理。${NC}"
    fi
    
    if [ -f "$SCRIPT_PATH" ]; then
        rm -f "$SCRIPT_PATH"
        echo -e "${GREEN}🎉 脚本 $SCRIPT_PATH 已成功卸载。${NC}"
        echo -e "${CYAN}=========================================="; echo "   脚本已卸载，请关闭当前终端窗口。    "; echo "=========================================="; echo -e "${NC}"
        exit 0 
    else
        echo -e "${RED}❌ 脚本文件未找到或已被删除，无法完成卸载。${NC}"
    fi
    read -p "按回车键返回主菜单..."
}

# -------------------------------
# 系统工具菜单 (新增功能入口)
# -------------------------------
system_tools_menu() {
    while true; do
        clear
        echo -e "${CYAN}"
        echo "=========================================="
        echo "              系统工具菜单                "
        echo "=========================================="
        echo -e "${NC}"
        echo "1. 修改登录密码"
        echo "2. 修改 SSH 连接端口"
        echo "3. 切换优先 IPV4/IPV6"
        echo "4. 修改主机名"
        echo "5. 系统时区调整"
        echo "6. 修改虚拟内存大小 (Swap)"
        echo "7. 重启服务器"
        echo "8. 卸载本脚本"
        echo "0. 返回主菜单"
        echo "=========================================="
        
        read -p "请输入选项编号: " tools_choice
        
        case $tools_choice in
            1) change_user_password ;;
            2) change_ssh_port ;;
            3) switch_ip_priority ;;
            4) change_hostname ;;
            5) change_timezone ;;
            6) change_swap_size ;;
            7) reboot_server ;;
            8)
                uninstall_script
                # 如果卸载成功，脚本会通过 exit 0 退出，否则会继续循环
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效的选项，请重新输入！${NC}"
                sleep 1
                ;;
        esac
    done
}


# ====================================================================
# +++ 主执行逻辑 (Main Execution Logic) +++
# ====================================================================

# 脚本启动时，首先检查root权限和依赖
check_root
check_deps

# 无限循环，直到用户选择退出
while true; do
    show_menu
    read -p "请输入你的选择 (0-7): " main_choice

    case $main_choice in
        1) system_info ;;
        2) system_update ;;
        3) system_clean ;;
        4) basic_tools ;;
        5) bbr_management ;;
        6) docker_management_menu ;;
        7) system_tools_menu ;;
        0)
            echo -e "${GREEN}感谢使用，正在退出脚本...${NC}"
            break
            ;;
        *)
            echo -e "${RED}无效的选项，请重新输入！${NC}"
            sleep 1
            ;;
    esac
done
