#!/bin/bash
# 自动切换 BBR 算法并测速对比 / VPS 工具箱
# GitHub: https://github.com/chengege666/bbr-gj

RESULT_FILE="bbr_result.txt"
SCRIPT_FILE="vpsgj.sh"
UNINSTALL_NOTE="vpsgj_uninstall_done.txt"

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
    echo -e "${MAGENTA}                 VPS 工具箱 v2.1                 ${RESET}"
    echo -e "${CYAN}--------------------------------------------------${RESET}"
    echo -e "${YELLOW}功能: BBR测速, 系统管理, Docker, SSH配置等${RESET}"
    echo -e "${GREEN}测速结果保存: ${RESULT_FILE}${RESET}"
    echo -e "${CYAN}==================================================${RESET}"
    echo ""
}

# -------------------------------
# root 权限检查
# -------------------------------
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}❌ 错误：请使用 root 权限运行本脚本${RESET}"
        echo "👉 使用方法: sudo bash $0"
        exit 1
    fi
}

# -------------------------------
# 依赖安装
# -------------------------------
install_deps() {
    PKGS="curl wget git speedtest-cli net-tools"
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
# 核心功能：BBR 测速 (保持不变)
# -------------------------------
run_test() {
    MODE=$1
    echo -e "${CYAN}>>> 切换到 $MODE 并测速...${RESET}"

    case $MODE in
        "BBR") sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1 ;;
        "BBR Plus") sysctl -w net.ipv4.tcp_congestion_control=bbrplus >/dev/null 2>&1 ;;
        "BBRv2") sysctl -w net.ipv4.tcp_congestion_control=bbrv2 >/dev/null 2>&1 ;;
        "BBRv3") sysctl -w net.ipv4.tcp_congestion_control=bbrv3 >/dev/null 2>&1 ;;
    esac
    
    sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1

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
    
    for ALGO in bbrplus bbrv2 bbrv3; do
        if ! grep -q "$ALGO" /proc/sys/net/ipv4/tcp_available_congestion_controls; then
            echo -e "${YELLOW}⚠️ 当前内核不支持 $ALGO，将跳过测试.${RESET}"
        fi
    done

    for MODE in "BBR" "BBR Plus" "BBRv2" "BBRv3"; do
        run_test "$MODE"
    done
    
    echo -e "${CYAN}=== 测试完成，结果汇总 (${RESULT_FILE}) ===${RESET}"
    cat "$RESULT_FILE"
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
        echo -e "${RED}❌ 下载或运行脚本失败，请检查网络连接${RESET}"
    fi
    read -n1 -p "按任意键返回菜单..."
}

# -------------------------------
# 功能 4: 系统更新
# -------------------------------
sys_update() {
    echo -e "${CYAN}=== 系统更新 (Update & Upgrade) ===${RESET}"
    echo -e "${GREEN}>>> 正在更新系统...${RESET}"
    if command -v apt >/dev/null 2>&1; then
        apt update -y && apt upgrade -y
    elif command -v yum >/dev/null 2>&1; then
        yum update -y
    elif command -v dnf >/dev/null 2>&1; then
        dnf update -y
    else
        echo -e "${RED}❌ 无法识别包管理器，请手动更新系统${RESET}"
    fi
    echo -e "${GREEN}系统更新操作完成。${RESET}"
    read -n1 -p "按任意键返回菜单..."
}

# -------------------------------
# 功能 5: 系统清理
# -------------------------------
sys_cleanup() {
    echo -e "${CYAN}=== 系统清理 (Cache & Autoremove) ===${RESET}"
    echo -e "${GREEN}>>> 正在清理缓存和无用依赖...${RESET}"
    if command -v apt >/dev/null 2>&1; then
        apt autoremove -y
        apt clean
        echo -e "${GREEN}APT 缓存和无用依赖清理完成${RESET}"
    elif command -v yum >/dev/null 2>&1; then
        yum autoremove -y
        yum clean all
        echo -e "${GREEN}YUM 缓存和无用依赖清理完成${RESET}"
    elif command -v dnf >/dev/null 2>&1; then
        dnf autoremove -y
        dnf clean all
        echo -e "${GREEN}DNF 缓存和无用依赖清理完成${RESET}"
    else
        echo -e "${RED}❌ 无法识别包管理器，请手动清理${RESET}"
    fi
    echo -e "${GREEN}系统清理操作完成。${RESET}"
    read -n1 -p "按任意键返回菜单..."
}

# -------------------------------
# 功能 8: 卸载脚本
# -------------------------------
uninstall_script() {
    read -p "确定要卸载本脚本并清理相关文件吗 (y/n)? ${RED}此操作不可逆!${RESET}: " confirm_uninstall
    if [[ "$confirm_uninstall" != "y" && "$confirm_uninstall" != "Y" ]]; then
        return
    fi
    
    DEPENDENCIES="speedtest-cli git wget curl net-tools"
    
    echo -e "${YELLOW}正在清理 ${SCRIPT_FILE}, ${RESULT_FILE}, tcp.sh 等文件...${RESET}"
    rm -f "$SCRIPT_FILE" "$RESULT_FILE" tcp.sh
    
    # 尝试自动卸载依赖
    read -p "是否同时卸载脚本安装的依赖包 ($DEPENDENCIES)? (y/n): " uninstall_deps
    if [[ "$uninstall_deps" == "y" || "$uninstall_deps" == "Y" ]]; then
        echo -e "${GREEN}>>> 正在尝试卸载依赖包...${RESET}"
        if command -v apt >/dev/null 2>&1; then
            apt purge -y $DEPENDENCIES
            echo -e "${GREEN}✅ 依赖包使用 ${YELLOW}apt purge${GREEN} 卸载完成。${RESET}"
        elif command -v yum >/dev/null 2>&1; then
            yum remove -y $DEPENDENCIES
            echo -e "${GREEN}✅ 依赖包使用 ${YELLOW}yum remove${GREEN} 卸载完成。${RESET}"
        elif command -v dnf >/dev/null 2>&1; then
            dnf remove -y $DEPENDENCIES
            echo -e "${GREEN}✅ 依赖包使用 ${YELLOW}dnf remove${GREEN} 卸载完成。${RESET}"
        else
            echo -e "${RED}❌ 无法自动卸载依赖。${RESET}"
        fi
    fi

    # 记录卸载成功
    echo "Script uninstalled on $(date)" > "$UNINSTALL_NOTE"
    
    echo -e "${GREEN}✅ 脚本卸载完成。${RESET}"
    if [[ "$uninstall_deps" != "y" && "$uninstall_deps" != "Y" ]]; then
        echo -e "${CYAN}请注意: 如果您选择不自动卸载，请手动执行以下命令清理依赖：${RESET}"
        if command -v apt >/dev/null 2>&1; then
            echo -e "    ${YELLOW}apt purge -y $DEPENDENCIES${RESET}"
        elif command -v yum >/dev/null 2>&1; 键，然后
            echo -e "    ${YELLOW}yum remove -y $DEPENDENCIES${RESET}"
        elif command -v dnf >/dev/null 2>&1; then
            echo -e "    ${YELLOW}dnf remove -y $DEPENDENCIES${RESET}"
        fi
    fi
    exit 0
}

# -------------------------------
# 其它功能 (3, 6, 7 - 保持不变)
# -------------------------------
# ... (show_sys_info, docker_menu, ssh_config_menu 函数代码省略，与 v2.0 保持一致) ...
show_sys_info() {
    echo -e "${CYAN}=== 系统信息 ===${RESET}"
    echo -e "${GREEN}操作系统:${RESET} $(cat /etc/os-release | grep PRETTY_NAME | cut -d "=" -f 2 | tr -d '"')"
    echo -e "${GREEN}内核版本:${RESET} $(uname -r)"
    echo -e "${GREEN}CPU型号: ${RESET} $(grep -m1 'model name' /proc/cpuinfo | awk -F': ' '{print $2}')"
    echo -e "${GREEN}内存信息:${RESET} $(free -h | grep Mem | awk '{print $2}')"
    echo -e "${GREEN}Swap信息:${RESET} $(free -h | grep Swap | awk '{print $2}')"
    echo -e "${GREEN}磁盘空间:${RESET} $(df -h / | grep / | awk '{print $2}') (已用: $(df -h / | grep / | awk '{print $5}'))"
    echo -e "${GREEN}当前IP: ${RESET} $(curl -s ifconfig.me || echo '获取失败')"
    echo -e "${GREEN}系统运行时间:${RESET} $(uptime | awk '{print $3,$4,$5}')"
    echo ""
    read -n1 -p "按任意键返回菜单..."
}

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
        echo -e "${RED}❌ Docker 安装失败，请检查日志。${RESET}"
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
    docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}"
    echo ""
    echo "1) 查看所有容器"
    echo "2) 重启所有容器"
    echo "3) 返回主菜单"
    read -p "请选择操作: " docker_choice
    
    case "$docker_choice" in
        1) docker ps -a ;;
        2) 
            echo -e "${GREEN}正在重启所有容器...${RESET}"
            docker restart $(docker ps -a -q)
            ;;
        *) return ;;
    esac
    read -n1 -p "按任意键返回菜单..."
}

ssh_config_menu() {
    SSH_CONFIG="/etc/ssh/sshd_config"
    if [ ! -f "$SSH_CONFIG" ]; then
        echo -e "${RED}❌ 未找到 SSH 配置文件 ($SSH_CONFIG)。${RESET}"
        read -n1 -p "按任意键返回菜单..."
        return
    fi

    echo -e "${CYAN}=== SSH 配置修改 ===${RESET}"
    
    read -p "输入新的 SSH 端口 (留空跳过，当前端口: $(grep -E '^Port' $SSH_CONFIG | awk '{print $2}')): " new_port
    if [ ! -z "$new_port" ]; then
        if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1 ] && [ "$new_port" -le 65535 ]; then
            sed -i "s/^#\?Port\s\+.*$/Port $new_port/" "$SSH_CONFIG"
            echo -e "${GREEN}✅ SSH 端口已修改为 $new_port${RESET}"
        else
            echo -e "${RED}❌ 端口输入无效。${RESET}"
        fi
    fi

    read -p "是否修改 root 用户密码? (y/n): " change_pass
    if [[ "$change_pass" == "y" || "$change_pass" == "Y" ]]; then
        echo -e "${YELLOW}请设置新的 root 密码:${RESET}"
        passwd root
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ root 密码修改成功${RESET}"
        else
            echo -e "${RED}❌ root 密码修改失败${RESET}"
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
# 交互菜单
# -------------------------------
show_menu() {
    while true; do
        print_welcome
        echo -e "请选择操作："
        echo -e "${GREEN}--- BBR 测速与切换 ---${RESET}"
        echo "1) BBR 综合测速 (BBR/BBR Plus/BBRv2/BBRv3 对比)"
        echo "2) 安装/切换 BBR 内核"
        echo -e "${GREEN}--- VPS 系统管理 ---${RESET}"
        echo "3) 查看系统信息 (OS/CPU/内存/IP)"
        echo "4) 系统更新 (Update & Upgrade)"
        echo "5) 系统清理 (Cache & Autoremove)"
        echo "6) Docker 容器管理"
        echo "7) SSH 端口与密码修改"
        echo -e "${GREEN}--- 其他 ---${RESET}"
        echo "8) 卸载脚本及残留文件"
        echo "9) 退出"
        echo ""
        read -p "输入数字选择: " choice
        
        case "$choice" in
            1) bbr_test_menu ;;
            2) run_bbr_switch ;;
            3) show_sys_info ;;
            4) sys_update ;; # 分离的更新
            5) sys_cleanup ;; # 分离的清理
            6) docker_menu ;;
            7) ssh_config_menu ;;
            8) uninstall_script ;;
            9) echo -e "${CYAN}感谢使用，再见！${RESET}"; exit 0 ;;
            *) echo -e "${RED}无效选项，请输入 1-9${RESET}"; sleep 2 ;;
        esac
    done
}

# -------------------------------
# 主程序
# -------------------------------
check_root
check_deps
show_menu
