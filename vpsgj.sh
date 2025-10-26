#!/bin/bash
# 增强版VPS工具箱 v1.3.0 (增加 Nginx Proxy Manager 功能)
# GitHub: https://github.com/chengege666/bbr-gj

RESULT_FILE="bbr_result.txt"
SCRIPT_FILE="vps_toolbox.sh"
UNINSTALL_NOTE="vps_toolbox_uninstall_done.txt"

# NPM (Nginx Proxy Manager) 相关路径定义
NPM_DIR="/opt/nginx-proxy-manager"
NPM_COMPOSE_FILE="$NPM_DIR/docker-compose.yml"

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
    echo -e "${MAGENTA}              增强版 VPS 工具箱 v1.3.0           ${RESET}"
    echo -e "${CYAN}--------------------------------------------------${RESET}"
    echo -e "${YELLOW}功能: BBR, 系统管理, 防火墙, Docker, NPM等${RESET}"
    echo -e "${GREEN}测速结果保存: ${RESULT_FILE}${RESET}"
    echo -e "${CYAN}==================================================${RESET}"
    echo ""
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
        echo -e "${RED}❌❌ 无法识别包管理器，请手动更新系统${RESET}"
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
        echo -e "${RED}❌❌ 无法识别包管理器，请手动清理${RESET}"
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
# 功能 10: SSH 配置修改
# -------------------------------
ssh_config_menu() {
    SSH_CONFIG="/etc/ssh/sshd_config"
    if [ ! -f "$SSH_CONFIG" ]; then
        echo -e "${RED}❌❌ 未找到 SSH 配置文件 ($SSH_CONFIG)。${RESET}"
        read -n1 -p "按任意键返回菜单..."
        return
    fi

    echo -e "${CYAN}=== SSH 配置修改 ===${RESET}"
    
    # 端口修改
    CURRENT_PORT=$(grep -E '^Port' "$SSH_CONFIG" 2>/dev/null | awk '{print $2}' || echo "22")
    read -p "输入新的 SSH 端口 (留空跳过，当前端口: $CURRENT_PORT): " new_port
    if [ ! -z "$new_port" ]; then
        if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1 ] && [ "$new_port" -le 65535 ]; then
            sed -i "s/^#\?Port\s\+.*$/Port $new_port/" "$SSH_CONFIG"
            echo -e "${GREEN}✅ SSH 端口已修改为 $new_port${RESET}"
        else
            echo -e "${RED}❌❌ 端口输入无效。${RESET}"
        fi
    fi

    # 密码修改
    read -p "是否修改 root 用户密码? (y/n): " change_pass
    if [[ "$change_pass" == "y" || "$change_pass" == "Y" ]]; then
        echo -e "${YELLOW}请设置新的 root 密码:${RESET}"
        passwd root
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ root 密码修改成功${RESET}"
        else
            echo -e "${RED}❌❌ root 密码修改失败${RESET}"
        fi
    fi

    echo -e "${GREEN}>>> 正在重启 SSH 服务以应用更改...${RESET}"
    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart sshd
    else
        /etc/init.d/sshd restart
    fi
    echo -e "${YELLOW}请注意: 如果您更改了 SSH 端口，请立即使用新端口重新连接！${RESET}"
    read -n1 -p "按任意键返回菜单..."
}

# -------------------------------
# 功能 11: GLIBC 管理
# -------------------------------
glibc_menu() {
    echo -e "${CYAN}=== GLIBC 管理 ===${RESET}"
    echo "1) 查询当前GLIBC版本"
    echo "2) 升级GLIBC"
    echo "3) 返回主菜单"
    read -p "请选择操作: " glibc_choice
    
    case "$glibc_choice" in
        1)
            echo -e "${GREEN}当前GLIBC版本:${RESET}"
            ldd --version | head -n1
            ;;
        2)
            upgrade_glibc
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

upgrade_glibc() {
    echo -e "${RED}警告：升级GLIBC是高风险操作，可能导致系统不稳定！${RESET}"
    read -p "确定要继续升级GLIBC吗？(y/N): " confirm_upgrade
    if [[ "$confirm_upgrade" != "y" && "$confirm_upgrade" != "Y" ]]; then
        echo -e "${GREEN}已取消升级操作${RESET}"
        return
    fi
    
    echo -e "${CYAN}>>> 开始升级GLIBC...${RESET}"
    
    if command -v apt >/dev/null 2>&1; then
        echo -e "${GREEN}检测到Debian/Ubuntu系统${RESET}"
        apt update -y
        apt install -y build-essential gawk bison
        apt upgrade -y libc6
    elif command -v yum >/dev/null 2>&1; then
        echo -e "${GREEN}检测到CentOS/RHEL系统${RESET}"
        yum update -y
        yum install -y gcc make bison
        yum update -y glibc
    elif command -v dnf >/dev/null 2>&1; then
        echo -e "${GREEN}检测到Fedora系统${RESET}"
        dnf update -y
        dnf install -y gcc make bison
        dnf update -y glibc
    else 
        echo -e "${RED}❌❌ 无法识别系统类型，请手动升级GLIBC${RESET}"
        return
    fi 

    echo -e "${GREEN}GLIBC升级完成${RESET}"
    echo -e "${YELLOW}建议重启系统以使新GLIBC版本生效${RESET}"
}

# -------------------------------
# 功能 12: 全面系统升级 (包括内核和依赖)
# -------------------------------
full_system_upgrade() {
    echo -e "${RED}警告：全面系统升级将升级所有软件包，包括内核，可能需要重启系统！${RESET}"
    read -p "确定要继续全面系统升级吗？(y/N): " confirm_upgrade
    if [[ "$confirm_upgrade" != "y" && "$confirm_upgrade" != "Y" ]]; then
        echo -e "${GREEN}已取消升级操作${RESET}"
        return
    fi
    
    echo -e "${CYAN}>>> 开始全面系统升级...${RESET}"
    
    if command -v apt >/dev/null 2>&1; then
        apt update -y
        apt full-upgrade -y
        apt dist-upgrade -y
    elif command -v yum >/dev/null 2>&1; then
        yum update -y
        yum upgrade -y
    elif command -v dnf >/dev/null 2>&1; then
        dnf update -y
        dnf upgrade -y
    else
        echo -e "${RED}❌❌ 无法识别系统类型，请手动升级${RESET}"
        return
    fi
    
    echo -e "${GREEN}全面系统升级完成${RESET}"
    echo -e "${YELLOW}建议重启系统以使所有更新生效${RESET}"
}

# ====================================================================
# +++ 高级防火墙管理 (基于iptables) +++
# ====================================================================
# 获取当前SSH端口
get_ssh_port() {
    SSH_PORT=$(ss -tnlp | grep 'sshd' | awk '{print $4}' | awk -F ':' '{print $NF}' | head -n 1)
    echo "${SSH_PORT:-22}"
}

# 允许当前SSH连接，以防锁死
allow_current_ssh() {
    local ssh_port
    ssh_port=$(get_ssh_port)
    if ! iptables -C INPUT -p tcp --dport "$ssh_port" -j ACCEPT >/dev/null 2>&1; then
        iptables -I INPUT 1 -p tcp --dport "$ssh_port" -j ACCEPT
        echo -e "${YELLOW}为防止失联，已自动放行当前SSH端口 ($ssh_port)。${RESET}"
    fi
}

# 保存iptables规则
save_iptables_rules() {
    echo -e "${CYAN}=== 保存防火墙规则 ===${RESET}"
    if command -v apt >/dev/null 2>&1; then
        if ! command -v iptables-save >/dev/null 2>&1; then
            apt-get update
            apt-get install -y iptables-persistent
        fi
        iptables-save > /etc/iptables/rules.v4
        ip6tables-save > /etc/iptables/rules.v6
    elif command -v yum >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
        if ! command -v iptables-save >/dev/null 2>&1; then
           yum install -y iptables-services
           systemctl enable iptables
        fi
        service iptables save
    else
        echo -e "${RED}无法确定规则保存方式，请手动执行 'iptables-save'。${RESET}"
        return
    fi
    echo -e "${GREEN}防火墙规则已保存，重启后将自动加载。${RESET}"
}

# 安装GeoIP模块
setup_geoip() {
    if lsmod | grep -q 'xt_geoip'; then
        return 0
    fi
    echo -e "${CYAN}检测到您首次使用国家IP限制功能，需要安装相关模块...${RESET}"
    if command -v apt >/dev/null 2>&1; then
        apt update
        apt install -y xtables-addons-common libtext-csv-xs-perl unzip
    elif command -v yum >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
        # CentOS/RHEL 需要 EPEL
        yum install -y epel-release
        yum install -y xtables-addons perl-Text-CSV_XS unzip
    fi

    mkdir -p /usr/share/xt_geoip
    cd /usr/share/xt_geoip || return
    # 使用ipdeny的数据库
    wget -qO- "https://www.ipdeny.com/ipblocks/data/countries/all-zones.tar.gz" | tar -xzf -
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}GeoIP数据库下载并解压成功。${RESET}"
        /usr/lib/xtables-addons/xt_geoip_build -D /usr/share/xt_geoip/ -S /usr/share/xt_geoip/
        echo -e "${GREEN}GeoIP数据库编译完成。${RESET}"
        modprobe xt_geoip
    else
        echo -e "${RED}GeoIP数据库下载失败，请检查网络。${RESET}"
        return 1
    fi
}

firewall_menu_advanced() {
    while true; do
        clear
        echo -e "${CYAN}=== 高级防火墙管理 (iptables) ===${RESET}"
        iptables -L INPUT -n --line-numbers | head -n 20
        echo "------------------------------------------------"
        echo -e "${YELLOW}1. 开放指定端口${RESET}                ${YELLOW}2. 关闭指定端口${RESET}"
        echo -e "${YELLOW}3. 开放所有端口(策略ACCEPT)${RESET}    ${YELLOW}4. 关闭所有端口(策略DROP)${RESET}"
        echo -e "${YELLOW}5. IP白名单 (允许访问)${RESET}           ${YELLOW}6. IP黑名单 (禁止访问)${RESET}"
        echo -e "${YELLOW}7. 清除指定IP规则${RESET}"
        echo "------------------------------------------------"
        echo -e "${CYAN}11. 允许 PING${RESET}                    ${CYAN}12. 禁止 PING${RESET}"
        echo -e "${CYAN}13. 启用基础DDoS防御${RESET}           ${CYAN}14. 关闭基础DDoS防御${RESET}"
        echo "------------------------------------------------"
        echo -e "${MAGENTA}15. 阻止指定国家IP${RESET}             ${MAGENTA}16. 仅允许指定国家IP${RESET}"
        echo -e "${MAGENTA}17. 解除所有国家IP限制${RESET}"
        echo "------------------------------------------------"
        echo -e "${GREEN}98. 保存当前规则使其永久生效${RESET}"
        echo -e "${GREEN}99. 清空所有防火墙规则${RESET}"
        echo -e "${GREEN}0. 返回上一级菜单${RESET}"
        echo ""
        read -p "请输入你的选择: " fw_choice

        allow_current_ssh # 每次操作前都确保SSH是通的

        case "$fw_choice" in
            1)
                read -p "请输入要开放的端口: " port
                iptables -I INPUT -p tcp --dport "$port" -j ACCEPT
                iptables -I INPUT -p udp --dport "$port" -j ACCEPT
                echo -e "${GREEN}端口 $port (TCP/UDP) 已开放。${RESET}"
                ;;
            2)
                read -p "请输入要关闭的端口: " port
                iptables -I INPUT -p tcp --dport "$port" -j DROP
                iptables -I INPUT -p udp --dport "$port" -j DROP
                echo -e "${GREEN}端口 $port (TCP/UDP) 的访问已被禁止。${RESET}"
                ;;
            3)
                echo -e "${RED}警告：此操作将允许所有外部访问！${RESET}"
                read -p "确定要将默认策略设为 ACCEPT 吗？(y/N): " confirm
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    iptables -P INPUT ACCEPT
                    echo -e "${GREEN}防火墙默认策略已设为 ACCEPT。${RESET}"
                fi
                ;;
            4)
                echo -e "${RED}警告：此操作将默认拒绝所有访问，仅放行您已设置的允许规则！${RESET}"
                read -p "确定要将默认策略设为 DROP 吗？(y/N): " confirm
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    iptables -P INPUT DROP
                    echo -e "${GREEN}防火墙默认策略已设为 DROP。${RESET}"
                fi
                ;;
            5)
                read -p "请输入要加入白名单的IP地址: " ip
                iptables -I INPUT -s "$ip" -j ACCEPT
                echo -e "${GREEN}IP $ip 已加入白名单。${RESET}"
                ;;
            6)
                read -p "请输入要加入黑名单的IP地址: " ip
                iptables -I INPUT -s "$ip" -j DROP
                echo -e "${GREEN}IP $ip 已加入黑名单。${RESET}"
                ;;
            7)
                read -p "请输入要清除规则的IP地址: " ip
                # 尝试删除该IP的所有规则
                iptables -D INPUT -s "$ip" -j ACCEPT 2>/dev/null
                iptables -D INPUT -s "$ip" -j DROP 2>/dev/null
                echo -e "${GREEN}已尝试清除IP $ip 的所有规则。${RESET}"
                ;;
            11)
                iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
                echo -e "${GREEN}已允许 PING 请求。${RESET}"
                ;;
            12)
                iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
                echo -e "${GREEN}已禁止 PING 请求。${RESET}"
                ;;
            13)
                # 基础DDoS防御规则
                iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
                iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
                iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
                # 防止SYN洪水攻击
                iptables -A INPUT -p tcp -m tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j DROP
                iptables -A INPUT -p tcp -m tcp --tcp-flags FIN,SYN FIN,SYN -j DROP
                iptables -A INPUT -p tcp -m tcp --tcp-flags SYN,RST SYN,RST -j DROP
                iptables -A INPUT -p tcp -m tcp --tcp-flags FIN,RST FIN,RST -j DROP
                iptables -A INPUT -p tcp -m tcp --tcp-flags FIN,ACK FIN -j DROP
                iptables -A INPUT -p tcp -m tcp --tcp-flags ACK,URG URG -j DROP
                # 限制新连接速率
                iptables -A INPUT -p tcp -m conntrack --ctstate NEW -m limit --limit 60/s --limit-burst 20 -j ACCEPT
                iptables -A INPUT -p tcp -m conntrack --ctstate NEW -j DROP
                echo -e "${GREEN}基础DDoS防御规则已启用。${RESET}"
                ;;
            14)
                # 移除基础DDoS防御规则
                iptables -D INPUT -p tcp --tcp-flags ALL NONE -j DROP 2>/dev/null
                iptables -D INPUT -p tcp ! --syn -m state --state NEW -j DROP 2>/dev/null
                iptables -D INPUT -p tcp --tcp-flags ALL ALL -j DROP 2>/dev/null
                iptables -D INPUT -p tcp -m tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j DROP 2>/dev/null
                iptables -D INPUT -p tcp -m tcp --tcp-flags FIN,SYN FIN,SYN -j DROP 2>/dev/null
                iptables -D INPUT -p tcp -m tcp --tcp-flags SYN,RST SYN,RST -j DROP 2>/dev/null
                iptables -D INPUT -p tcp -m tcp --tcp-flags FIN,RST FIN,RST -j DROP 2>/dev/null
                iptables -D INPUT -p tcp -m tcp --tcp-flags FIN,ACK FIN -j DROP 2>/dev/null
                iptables -D INPUT -p tcp -m tcp --tcp-flags ACK,URG URG -j DROP 2>/dev/null
                iptables -D INPUT -p tcp -m conntrack --ctstate NEW -m limit --limit 60/s --limit-burst 20 -j ACCEPT 2>/dev/null
                iptables -D INPUT -p tcp -m conntrack --ctstate NEW -j DROP 2>/dev/null
                echo -e "${GREEN}基础DDoS防御规则已关闭。${RESET}"
                ;;
            15)
                setup_geoip
                if [ $? -ne 0 ]; then read -n1 -p "按任意键返回..."; continue; fi
                read -p "请输入要阻止的国家代码 (例如 CN,US,RU)，多个用逗号隔开: " country_codes
                iptables -I INPUT -m geoip --src-cc "$country_codes" -j DROP
                echo -e "${GREEN}已阻止来自 $country_codes 的IP访问。${RESET}"
                ;;
            16)
                setup_geoip
                if [ $? -ne 0 ]; then read -n1 -p "按任意键返回..."; continue; fi
                echo -e "${RED}警告：此操作将拒绝除指定国家外的所有IP访问，风险极高！${RESET}"
                read -p "请输入仅允许的国家代码 (例如 CN,US,RU)，多个用逗号隔开: " country_codes
                read -p "再次确认执行此高风险操作吗？(y/N): " confirm
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    iptables -A INPUT -m geoip ! --src-cc "$country_codes" -j DROP
                    echo -e "${GREEN}已设置为仅允许来自 $country_codes 的IP访问。${RESET}"
                fi
                ;;
            17)
                # 移除所有GeoIP规则
                for rule_num in $(iptables -L INPUT --line-numbers | grep 'geoip' | awk '{print $1}' | sort -rn); do
                    iptables -D INPUT "$rule_num"
                done
                echo -e "${GREEN}所有国家IP限制规则已解除。${RESET}"
                ;;
            98)
                save_iptables_rules
                ;;
            99)
                echo -e "${RED}警告：此操作将清空所有防火墙规则，使服务器完全暴露！${RESET}"
                read -p "确定要清空所有规则吗？(y/N): " confirm
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    iptables -F
                    iptables -X
                    iptables -P INPUT ACCEPT
                    iptables -P FORWARD ACCEPT
                    iptables -P OUTPUT ACCEPT
                    echo -e "${GREEN}所有防火墙规则已清空。${RESET}"
                fi
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效选项，请输入正确的数字。${RESET}"
                ;;
        esac
        read -n1 -p "按任意键返回防火墙菜单..."
    done
}


# ====================================================================
# +++ Nginx Proxy Manager 模块 +++
# ====================================================================
COMPOSE_CMD=""

# 检查并设置 docker compose 命令
check_compose_command() {
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        echo -e "${YELLOW}未检测到 Docker Compose。请先从Docker菜单安装Docker环境，它通常会包含Compose插件。${RESET}"
        return 1
    fi
    return 0
}

# 安装NPM
install_npm() {
    if [ -f "$NPM_COMPOSE_FILE" ]; then
        echo -e "${YELLOW}Nginx Proxy Manager 似乎已经安装在 $NPM_DIR 中。${RESET}"
        return
    fi
    
    check_compose_command || return
    
    echo -e "${CYAN}>>> 准备安装 Nginx Proxy Manager...${RESET}"
    mkdir -p "$NPM_DIR"
    
    # 创建 docker-compose.yml
    cat > "$NPM_COMPOSE_FILE" << EOF
version: '3.8'
services:
  app:
    image: 'jc21/nginx-proxy-manager:latest'
    restart: unless-stopped
    ports:
      # Public HTTP Port:
      - '80:80'
      # Public HTTPS Port:
      - '443:443'
      # Admin Web Port:
      - '81:81'
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
EOF

    echo -e "${GREEN}docker-compose.yml 文件已创建。${RESET}"
    echo -e "${CYAN}>>> 正在使用 Docker Compose 启动 Nginx Proxy Manager...${RESET}"
    
    # 使用 cd 来避免在命令中指定 -f 和工作目录，更简洁
    (cd "$NPM_DIR" && $COMPOSE_CMD up -d)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Nginx Proxy Manager 安装并启动成功！${RESET}"
        echo -e "${YELLOW}请访问: http://<你的服务器IP>:81${RESET}"
        echo -e "${YELLOW}默认管理员用户:${RESET}"
        echo -e " - ${CYAN}Email:${RESET}    admin@example.com"
        echo -e " - ${CYAN}Password:${RESET} changeme"
    else
        echo -e "${RED}❌❌ Nginx Proxy Manager 安装失败，请检查 Docker 环境和日志。${RESET}"
    fi
}

# 卸载NPM
uninstall_npm() {
    if [ ! -f "$NPM_COMPOSE_FILE" ]; then
        echo -e "${YELLOW}未在 $NPM_DIR 中找到 Nginx Proxy Manager 的安装。${RESET}"
        return
    fi
    
    check_compose_command || return

    echo -e "${RED}警告：此操作将停止并彻底删除 Nginx Proxy Manager 及其所有数据（配置、证书等）！${RESET}"
    read -p "确定要继续吗？(y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${GREEN}操作已取消。${RESET}"
        return
    fi
    
    echo -e "${CYAN}>>> 正在停止并删除 Nginx Proxy Manager 容器和卷...${RESET}"
    (cd "$NPM_DIR" && $COMPOSE_CMD down --volumes)
    
    echo -e "${CYAN}>>> 正在删除安装目录...${RESET}"
    rm -rf "$NPM_DIR"
    
    echo -e "${GREEN}✅ Nginx Proxy Manager 已成功卸载。${RESET}"
}

# NPM 服务管理 (启动、停止、重启、日志)
manage_npm_service() {
    if [ ! -f "$NPM_COMPOSE_FILE" ]; then
        echo -e "${YELLOW}请先安装 Nginx Proxy Manager。${RESET}"
        return
    fi
    check_compose_command || return
    
    ACTION=$1
    echo -e "${CYAN}>>> 正在执行操作: $ACTION...${RESET}"
    
    case "$ACTION" in
        "start" | "stop" | "restart")
            (cd "$NPM_DIR" && $COMPOSE_CMD $ACTION)
            ;;
        "logs")
            (cd "$NPM_DIR" && $COMPOSE_CMD logs -f --tail=100)
            ;;
        *)
            echo -e "${RED}未知的服务操作: $ACTION${RESET}"
            ;;
    esac
}

# 更新 NPM
update_npm() {
    if [ ! -f "$NPM_COMPOSE_FILE" ]; then
        echo -e "${YELLOW}请先安装 Nginx Proxy Manager。${RESET}"
        return
    fi
    check_compose_command || return
    
    echo -e "${CYAN}>>> 正在拉取最新的 Nginx Proxy Manager 镜像...${RESET}"
    (cd "$NPM_DIR" && $COMPOSE_CMD pull)
    
    echo -e "${CYAN}>>> 正在使用新镜像重启服务...${RESET}"
    (cd "$NPM_DIR" && $COMPOSE_CMD up -d)
    
    echo -e "${GREEN}✅ Nginx Proxy Manager 更新完成。${RESET}"
}

# NPM 主菜单
npm_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== Nginx Proxy Manager 管理 ===${RESET}"
        
        # 检查安装状态
        if [ -f "$NPM_COMPOSE_FILE" ]; then
            # 尝试获取运行状态
            if docker ps --format '{{.Image}}' | grep -q "jc21/nginx-proxy-manager"; then
                 echo -e "${GREEN}状态: 已安装并正在运行${RESET}"
            else
                 echo -e "${YELLOW}状态: 已安装但未运行${RESET}"
            fi
            echo -e "管理面板: ${CYAN}http://$(curl -s4 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}'):81${RESET}"
        else
            echo -e "${RED}状态: 未安装${RESET}"
        fi
        
        echo "------------------------------------------------"
        echo "1. 安装 Nginx Proxy Manager"
        echo "2. 卸载 Nginx Proxy Manager"
        echo ""
        echo "3. 启动服务"
        echo "4. 停止服务"
        echo "5. 重启服务"
        echo "6. 查看日志"
        echo "7. 更新版本"
        echo "------------------------------------------------"
        echo "0. 返回主菜单"
        echo ""
        read -p "请输入你的选择: " choice

        case "$choice" in
            1) install_npm ;;
            2) uninstall_npm ;;
            3) manage_npm_service "start" ;;
            4) manage_npm_service "stop" ;;
            5) manage_npm_service "restart" ;;
            6) manage_npm_service "logs" ;;
            7) update_npm ;;
            0) break ;;
            *) echo -e "${RED}无效选项${RESET}" ;;
        esac
        read -n1 -p "按任意键返回NPM菜单..."
    done
}


# -------------------------------
# 功能 15: 卸载脚本
# -------------------------------
uninstall_script() {
    read -p "确定要卸载本脚本并清理相关文件吗 (y/n)? ${RED}此操作不可逆!${RESET}: " confirm_uninstall
    if [[ "$confirm_uninstall" == "y" || "$confirm_uninstall" == "Y" ]]; then
        echo -e "${YELLOW}正在清理 ${SCRIPT_FILE}, ${RESULT_FILE} 等文件...${RESET}"
        rm -f "$SCRIPT_FILE" "$RESULT_FILE" tcp.sh
        
        # 记录卸载成功
        echo "Script uninstalled on $(date)" > "$UNINSTALL_NOTE"
        
        echo -e "${GREEN}✅ 脚本卸载完成。${RESET}"
        echo -e "${YELLOW}为了完全清理，您可能需要手动删除下载的其他依赖包:${RESET}"
        echo -e "${CYAN}可以运行以下命令清理依赖包:${RESET}"
        echo ""
        echo "Debian/Ubuntu:"
        echo "  apt remove --purge curl wget git speedtest-cli net-tools"
        echo "  apt autoremove -y"
        echo ""
        echo "CentOS/RHEL:"
        echo "  yum remove curl wget git speedtest-cli net-tools"
        echo ""
        echo "Fedora:"
        echo "  dnf remove curl wget git speedtest-cli net-tools"
        echo ""
        echo -e "${YELLOW}或者您希望自动执行清理命令吗？${RESET}"
        read -p "自动清理依赖包? (y/n): " auto_clean
        
        if [[ "$auto_clean" == "y" || "$auto_clean" == "Y" ]]; then
            echo -e "${CYAN}>>> 正在尝试自动清理依赖包...${RESET}"
            if command -v apt >/dev/null 2>&1; then
                apt remove --purge -y curl wget git speedtest-cli net-tools
                apt autoremove -y
            elif command -v yum >/dev/null 2>&1; then
                yum remove -y curl wget git speedtest-cli net-tools
            elif command -v dnf >/dev/null 2>&1; then
                dnf remove -y curl wget git speedtest-cli net-tools
            else
                echo -e "${RED}❌❌ 无法识别包管理器，请手动清理${RESET}"
            fi
            echo -e "${GREEN}✅ 依赖包清理完成${RESET}"
        fi
        
        echo -e "${CYAN}==================================================${RESET}"
        echo -e "${GREEN}卸载完成！感谢使用 VPS 工具箱${RESET}"
        echo -e "${CYAN}==================================================${RESET}"
        exit 0
    fi
}

# -------------------------------
# 交互菜单
# -------------------------------
show_menu() {
    # 初始化IP版本变量
    if [ -z "$IP_VERSION" ]; then
        IP_VERSION="4"
    fi
    
    while true; do
        print_welcome
        echo -e "请选择操作："
        echo -e "${GREEN}--- BBR 测速与切换 ---${RESET}"
        echo "1) BBR 综合测速 (BBR/BBR Plus/BBRv2/BBRv3 对比)"
        echo "2) 安装/切换 BBR 内核"
        echo -e "${GREEN}--- VPS 系统管理 ---${RESET}"
        echo "3) 查看系统信息 (OS/CPU/内存/IP/BBR/GLIBC)"
        echo "4) 更新软件包并升级 (不升级内核)"
        echo "5) 系统清理 (清理旧版依赖包)"
        echo "6) IPv4/IPv6 切换 (当前: IPv$IP_VERSION)"
        echo "7) 系统时区调整"
        echo "8) 系统重启"
        echo "9) GLIBC 管理"
        echo "10) 全面系统升级 (含内核升级)"
        echo -e "${GREEN}--- 服务与安全 ---${RESET}"
        echo "11) 高级 Docker 管理"
        echo "12) SSH 端口与密码修改"
        echo "13) 高级防火墙管理 (iptables)"
        echo "14) Nginx Proxy Manager 管理"
        echo -e "${GREEN}--- 其他 ---${RESET}"
        echo "15) 卸载脚本及残留文件"
        echo "0) 退出脚本"
        echo ""
        read -p "输入数字选择: " choice
        
        case "$choice" in
            1) bbr_test_menu ;;
            2) run_bbr_switch ;;
            3) show_sys_info ;;
            4) sys_update ;;
            5) sys_cleanup ;;
            6) ip_version_switch ;;
            7) timezone_adjust ;;
            8) system_reboot ;;
            9) glibc_menu ;;
            10) full_system_upgrade ;;
            11) docker_menu ;;
            12) ssh_config_menu ;;
            13) firewall_menu_advanced ;; 
            14) npm_menu ;;
            15) uninstall_script ;; 
            0) echo -e "${CYAN}感谢使用，再见！${RESET}"; exit 0 ;;
            *) echo -e "${RED}无效选项，请输入 0-15${RESET}"; sleep 2 ;;
        esac
    done
}

# -------------------------------
# 主程序
# -------------------------------
check_root
check_deps
show_menu
