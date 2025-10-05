#!/bin/bash
# 增强版VPS工具箱 v2.3
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
    echo -e "${MAGENTA}                VPS 工具箱 v1.0                ${RESET}"
    echo -e "${CYAN}--------------------------------------------------${RESET}"
    echo -e "${YELLOW}功能: BBR测速, 系统管理, GLIBC管理, Docker, SSH配置等${RESET}"
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
    PKGS="curl wget git speedtest-cli net-tools build-essential"
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
    for CMD in curl wget git speedtest-cli; do
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

# -------------------------------
# 功能 9: Docker 管理
# -------------------------------
docker_install() {
    echo -e "${CYAN}正在安装 Docker...${RESET}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh --mirror Aliyun
    rm get-docker.sh
    systemctl enable docker
    systemctl start docker
    if command -v docker >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Docker 安装并启动成功！${RESET}"
    else
        echo -e "${RED}❌❌ Docker 安装失败，请检查日志。${RESET}"
    fi
}

docker_menu() {
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}未检测到 Docker！${RESET}"
        read -p "是否现在安装 Docker? (y/n): " install_docker
        if [[ "$install_docker" == "y" || "$install_docker" == "Y" ]]; then
            docker_install
        fi
        read -n1 -p "按任意键返回菜单..."
        return
    fi

    echo -e "${CYAN}=== Docker 容器管理 ===${RESET}"
    echo -e "${YELLOW}当前运行的容器:${RESET}"
    docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null || echo -e "${YELLOW}无运行中的容器${RESET}"
    echo ""
    echo "1) 查看所有容器"
    echo "2) 重启所有容器"
    echo "3) 返回主菜单"
    read -p "请选择操作: " docker_choice
    
    case "$docker_choice" in # <-- 修复点: 确保此处是 'in'
        1) docker ps -a 2>/dev/null || echo -e "${YELLOW}Docker 命令执行失败${RESET}" ;;
        2) 
            echo -e "${GREEN}正在重启所有容器...${RESET}"
            docker restart $(docker ps -a -q) 2>/dev/null && echo -e "${GREEN}容器重启完成${RESET}" || echo -e "${YELLOW}无容器可重启${RESET}"
            ;;
        *) return ;;
    esac
    read -n1 -p "按任意键返回菜单..."
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
    
    # 检查系统类型 (重新构建此 if-elif-else-fi 块，确保语法纯净)
    if command -v apt >/dev/null 2>&1; then
        # Debian/Ubuntu系统
        echo -e "${GREEN}检测到Debian/Ubuntu系统${RESET}"
        apt update -y
        apt install -y build-essential gawk bison
        apt upgrade -y libc6
    elif command -v yum >/dev/null 2>&1; then
        # CentOS/RHEL系统
        echo -e "${GREEN}检测到CentOS/RHEL系统${RESET}"
        yum update -y
        yum install -y gcc make bison
        yum update -y glibc
    elif command -v dnf >/dev/null 2>&1; then
        # Fedora系统
        echo -e "${GREEN}检测到Fedora系统${RESET}"
        dnf update -y
        dnf install -y gcc make bison
        dnf update -y glibc
    else # <-- 此处的 'else' 是之前报告错误的位置
        echo -e "${RED}❌❌ 无法识别系统类型，请手动升级GLIBC${RESET}"
        return
    fi # <-- 确保 'fi' 匹配了最外层的 'if'

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
        # Debian/Ubuntu系统
        apt update -y
        apt full-upgrade -y
        apt dist-upgrade -y
    elif command -v yum >/dev/null 2>&1; then
        # CentOS/RHEL系统
        yum update -y
        yum upgrade -y
    elif command -v dnf >/dev/null 2>&1; then
        # Fedora系统
        dnf update -y
        dnf upgrade -y
    else
        echo -e "${RED}❌❌ 无法识别系统类型，请手动升级${RESET}"
        return
    fi
    
    echo -e "${GREEN}全面系统升级完成${RESET}"
    echo -e "${YELLOW}建议重启系统以使所有更新生效${RESET}"
}

# -------------------------------
# 功能 13: 卸载脚本
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
        echo -e "${GREEN}--- 服务管理 ---${RESET}"
        echo "11) Docker 容器管理"
        echo "12) SSH 端口与密码修改"
        echo -e "${GREEN}--- 其他 ---${RESET}"
        echo "13) 卸载脚本及残留文件"
        echo "0) 退出脚本" # 退出选项改为0
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
            13) uninstall_script ;;
            0) echo -e "${CYAN}感谢使用，再见！${RESET}"; exit 0 ;; # case语句处理0
            *) echo -e "${RED}无效选项，请输入 0-13${RESET}"; sleep 2 ;; # 提示信息更新为0-13
        esac
    done
}

# -------------------------------
# 主程序
# -------------------------------
check_root
check_deps
show_menu
