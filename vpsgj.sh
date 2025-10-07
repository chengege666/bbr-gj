#!/bin/bash
# 增强版VPS工具箱 v1.2.1 (修复Docker管理逻辑)
# GitHub: https://github.com/chengege666/bbr-gj

RESULT_FILE="bbr_result.txt"
SCRIPT_FILE="vps_toolbox.sh"
UNINSTALL_NOTE="vps_toolbox_uninstall_done.txt"

# -------------------------------
# 颜色定义与欢迎窗口
# -------------------------------
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
MAGENTA="\033[1;35m"
CYAN="\033[1;36m"
RESET="\033[0m"

print_welcome() {
    clear
    echo -e "${CYAN}==================================================${RESET}"
    echo -e "${MAGENTA}              增强版 VPS 工具箱 v1.2.1           ${RESET}"
    echo -e "${CYAN}--------------------------------------------------${RESET}"
    echo -e "${YELLOW}功能: BBR测速, 系统管理, 高级防火墙, 高级Docker等${RESET}"
    echo -e "${GREEN}测速结果保存: ${RESULT_FILE}${RESET}"
    echo -e "${CYAN}==================================================${RESET}"
    echo ""
}

# -------------------------------
# root 权限检查
# -------------------------------
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}❌❌❌❌ 错误：请使用 root 权限运行本脚本${RESET}"
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
        echo -e "${RED}❌❌❌❌ 下载或运行脚本失败，请检查网络连接${RESET}"
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

# -------------------------------
# 功能 4: 系统更新 (更新软件包列表并升级已安装软件)
# -------------------------------
sys_update() {
    echo -e "${CYAN}=== 系统更新 ===${RESET}"
    echo -e "${GREEN}>>> 正在更新软件包列表并升级已安装软件...${RESET}"
    if command -v apt >/dev/null 2>&1; then
        apt update -y
        apt upgrade -y
    elif command -v yum >/dev/null 2>&1; then
        yum update -y
    elif command -v dnf >/dev/null 2>&1; then
        dnf update -y
    else
        echo -e "${RED}❌❌❌❌ 无法识别包管理器，请手动更新系统${RESET}"
    fi
    echo -e "${GREEN}系统更新操作完成。${RESET}"
    read -n1 -p "按任意键返回菜单..."
}

# -------------------------------
# 功能 5: 系统清理 (清理旧版依赖包)
# -------------------------------
sys_cleanup() {
    echo -e "${CYAN}=== 系统清理 ===${RESET}"
    echo -e "${GREEN}>>> 正在清理缓存和旧版依赖包...${RESET}"
    if command -v apt >/dev/null 2>&1; then
        apt autoremove -y
        apt clean
        apt autoclean
        echo -e "${GREEN}APT 清理完成${RESET}"
    elif command -v yum >/dev/null 2>&1; then
        yum autoremove -y
        yum clean all
        echo -e "${GREEN}YUM 清理完成${RESET}"
    elif command -v dnf >/dev/null 2>&1; then
        dnf autoremove -y
        dnf clean all
        echo -e "${GREEN}DNF 清理完成${RESET}"
    else
        echo -e "${RED}❌❌❌❌ 无法识别包管理器，请手动清理${RESET}"
    fi
    echo -e "${GREEN}系统清理操作完成。${RESET}"
    read -n1 -p "按任意键返回菜单..."
}

# -------------------------------
# 功能 6: IPv4/IPv6 切换
# -------------------------------
ip_version_switch() {
    echo -e "${CYAN}=== IPv4/IPv6 切换 ===${RESET}"
    echo "当前网络模式: $([ "$IP_VERSION" = "6" ] && echo "IPv6" || echo "IPv4")"
    echo ""
    echo "1) 使用 IPv4"
    echo "2) 使用 IPv6"
    echo "3) 返回主菜单"
    read -p "请选择: " ip_choice
    
    case "$ip_choice" in
        1) 
            IP_VERSION="4"
            echo -e "${GREEN}已切换到 IPv4 模式${RESET}"
            ;;
        2) 
            IP_VERSION="6"
            echo -e "${GREEN}已切换到 IPv6 模式${RESET}"
            ;;
        3) 
            return
            ;;
        *)
            echo -e "${RED}无效选择${RESET}"
            ;;
    esac
    read -n1 -p "按任意键返回菜单..."
}

# -------------------------------
# 功能 7: 系统时区调整
# -------------------------------
timezone_adjust() {
    echo -e "${CYAN}=== 系统时区调整 ===${RESET}"
    echo -e "${YELLOW}当前系统时区:${RESET}"
    timedatectl status | grep "Time zone"
    echo ""
    echo "1) 设置时区为上海 (Asia/Shanghai)"
    echo "2) 设置时区为纽约 (America/New_York)"
    echo "3) 手动输入时区"
    echo "4) 返回主菜单"
    read -p "请选择: " tz_choice
    
    case "$tz_choice" in
        1)
            timedatectl set-timezone Asia/Shanghai
            echo -e "${GREEN}已设置时区为 Asia/Shanghai${RESET}"
            ;;
        2)
            timedatectl set-timezone America/New_York
            echo -e "${GREEN}已设置时区为 America/New_York${RESET}"
            ;;
        3)
            read -p "请输入时区 (如 Asia/Tokyo): " custom_tz
            if timedatectl set-timezone "$custom_tz" 2>/dev/null; then
                echo -e "${GREEN}已设置时区为 $custom_tz${RESET}"
            else
                echo -e "${RED}无效的时区，请检查输入${RESET}"
            fi
            ;;
        4)
            return
            ;;
        *)
            echo -e "${RED}无效选择${RESET}"
            ;;
    esac
    read -n1 -p "按任意键返回菜单..."
}

# -------------------------------
# 功能 8: 系统重启
# -------------------------------
system_reboot() {
    echo -e "${CYAN}=== 系统重启 ===${RESET}"
    echo -e "${RED}警告：这将立即重启系统！${RESET}"
    read -p "确定要重启系统吗？(y/N): " confirm_reboot
    if [[ "$confirm_reboot" == "y" || "$confirm_reboot" == "Y" ]]; then
        echo -e "${GREEN}正在重启系统...${RESET}"
        reboot
    else
        echo -e "${GREEN}已取消重启${RESET}"
        read -n1 -p "按任意键返回菜单..."
    fi
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
        elif command -v dnf >/dev/null 2>&1; 键，然后
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
        echo -e "${RED}❌❌❌❌ Docker 安装/更新失败，请检查日志。${RESET}"
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

# nginx-proxy-manager 管理菜单
nginx_proxy_manager_menu() {
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}未检测到 Docker 环境！${RESET}"
        read -p "是否现在安装 Docker? (y/n): " install_docker
        if [[ "$install_docker" == "y" || "$install_docker" == "Y" ]]; then
            install_update_docker
        else
            return
        fi
    fi

    while true; do
        clear
        echo -e "${CYAN}=== nginx-proxy-manager 管理 ===${RESET}"
        
        # 检查是否已安装
        if docker ps -a --format '{{.Names}}' | grep -q 'nginx-proxy-manager'; then
            npm_status=$(docker inspect -f '{{.State.Status}}' nginx-proxy-manager 2>/dev/null || echo "未运行")
            echo -e "${GREEN}当前状态: $npm_status${RESET}"
        else
            echo -e "${YELLOW}nginx-proxy-manager 未安装${RESET}"
        fi
        
        echo "------------------------------------------------"
        echo "1. 安装/更新 nginx-proxy-manager"
        echo "2. 启动 nginx-proxy-manager"
        echo "3. 停止 nginx-proxy-manager"
        echo "4. 重启 nginx-proxy-manager"
        echo "5. 查看日志"
        echo "6. 卸载 nginx-proxy-manager"
        echo "7. 备份配置"
        echo "8. 恢复配置"
        echo "0. 返回上级菜单"
        echo "------------------------------------------------"
        read -p "请输入你的选择: " choice

        case "$choice" in
            1)
                echo -e "${CYAN}>>> 安装/更新 nginx-proxy-manager...${RESET}"
                #
