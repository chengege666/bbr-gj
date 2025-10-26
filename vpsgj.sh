#!/bin/bash
# 增强版VPS工具箱 v2.0.0 (模块化重构)
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
    echo -e "${MAGENTA}              增强版 VPS 工具箱 V2.0.0           ${RESET}"
    echo -e "${CYAN}--------------------------------------------------${RESET}"
    echo -e "${YELLOW}功能: 模块化管理 BBR, 系统, Docker, NPM等${RESET}"
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
    # 移除 speedtest-cli 依赖，因为它已移入模块，且模块中会进行检查
    PKGS="curl wget git net-tools build-essential iptables"
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
    # 检查核心依赖
    for CMD in curl wget git iptables; do
        if ! command -v $CMD >/dev/null 2>&1; then
            echo -e "${YELLOW}未检测到 $CMD，正在尝试安装依赖...${RESET}"
            install_deps
            break
        fi
    done
}


# ====================================================================
# +++ 模块加载核心 (V2.0.0 新增) +++
# ====================================================================
load_module() {
    MODULE_NAME=$1
    MODULE_PATH="modules/$MODULE_NAME"
    
    if [ -f "$MODULE_PATH" ]; then
        echo -e "${CYAN}=== 调用模块: ${MODULE_NAME} ===${RESET}"
        source "$MODULE_PATH"
        
        # 模块的菜单函数名约定为 [文件名]_menu
        MODULE_FUNC=$(echo "$MODULE_NAME" | sed 's/\.sh$/_menu/') 
        
        if command -v "$MODULE_FUNC" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ 加载模块: ${MODULE_NAME}${RESET}"
            "$MODULE_FUNC"
        else
            echo -e "${RED}❌ 错误: 模块 ${MODULE_NAME} 未定义入口函数 ${MODULE_FUNC}${RESET}"
            read -n1 -p "按任意键返回菜单..."
        fi
    else
        echo -e "${RED}❌ 错误: 未找到模块 $MODULE_PATH${RESET}"
        read -n1 -p "按任意键返回菜单..."
    fi
}

# ====================================================================
# --- BBR 功能移除 (已移入 modules/bbr_manager.sh) ---
# ====================================================================
# 原 V1.3.0 中的 run_test, bbr_test_menu, run_bbr_switch 函数已移除。


# ====================================================================
# --- 其他功能移除/保留 (原V1.3.0中的函数) ---
# ====================================================================
# 注意：以下所有函数（除 uninstall_script 外）在最终模块化版本中都应该被移除，并移入对应的模块。
# 
# 为了快速实现 V2.0.0 菜单结构，我们暂时保留这些函数定义，但主菜单不再直接调用它们。
# 只有 `uninstall_script` 必须保留在主脚本中。

# -------------------------------
# 功能 3-14: (V1.3.0 中的所有功能)
# 这些函数体仍保留在此处，但其调用逻辑已移入 load_module
# ***********************************************
# (此处为简洁省略了 V1.3.0 中 show_sys_info, sys_update, sys_cleanup, ip_version_switch, timezone_adjust, system_reboot, 
#  glibc_menu, upgrade_glibc, full_system_upgrade, docker_menu, ssh_config_menu, firewall_menu_advanced, npm_menu 的函数体。
#  **在您的实际文件中，它们必须被完整保留或移入对应模块**。)
# ***********************************************

# 从 V1.3.0 文件中复制过来的 show_sys_info 函数
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

# (此处省略其余V1.3.0中的函数体，请确保您的vpsgj.sh包含了它们，或者您已经将它们成功移入对应的模块。)

# -------------------------------
# 功能 15: 卸载脚本 (必须保留在主脚本)
# -------------------------------
uninstall_script() {
    read -p "确定要卸载本脚本并清理相关文件吗 (y/n)? ${RED}此操作不可逆!${RESET}: " confirm_uninstall
    if [[ "$confirm_uninstall" == "y" || "$confirm_uninstall" == "Y" ]]; then
        echo -e "${YELLOW}正在清理 ${SCRIPT_FILE}, ${RESULT_FILE} 等文件...${RESET}"
        # 清理主脚本和BBR结果文件
        rm -f "$SCRIPT_FILE" "$RESULT_FILE" tcp.sh
        
        # 记录卸载成功
        echo "Script uninstalled on $(date)" > "$UNINSTALL_NOTE"
        
        # 自动清理依赖包的逻辑... (保持不变)
        
        echo -e "${CYAN}==================================================${RESET}"
        echo -e "${GREEN}卸载完成！感谢使用 VPS 工具箱${RESET}"
        echo -e "${CYAN}==================================================${RESET}"
        exit 0
    fi
}


# -------------------------------
# 交互菜单 (与 V2.0.0 截图对齐)
# -------------------------------
show_menu() {
    # 初始化IP版本变量
    if [ -z "$IP_VERSION" ]; then
        IP_VERSION="4"
    fi
    
    while true; do
        print_welcome
        echo -e "请选择操作："
        echo -e "${CYAN}1. 系统信息查询${RESET}"
        echo -e "${CYAN}2. 系统更新${RESET}"
        echo -e "${CYAN}3. 系统清理${RESET}"
        echo -e "${CYAN}4. 基础工具${RESET}"
        echo -e "${MAGENTA}5. BBR管理${RESET}" # BBR 模块入口
        echo -e "${CYAN}6. Docker管理${RESET}"
        echo -e "${CYAN}8. 测试脚本合集${RESET}"
        echo -e "${CYAN}13. 系统工具${RESET}"
        echo "------------------------------------------------"
        echo -e "${YELLOW}00. 脚本更新${RESET}"
        echo -e "${RED}0. 退出脚本${RESET}"
        echo ""
        read -p "请输入你的选择: " choice
        
        case "$choice" in
            1) load_module "system_info.sh" ;;    # 调用 modules/system_info.sh
            2) load_module "system_update.sh" ;;  # 调用 modules/system_update.sh
            3) load_module "system_cleanup.sh" ;; # 调用 modules/system_cleanup.sh
            4) load_module "basic_tools.sh" ;;    # 调用 modules/basic_tools.sh
            5) load_module "bbr_manager.sh" ;;    # 调用 modules/bbr_manager.sh
            6) load_module "docker_manager.sh" ;; # 调用 modules/docker_manager.sh
            8) load_module "test_scripts.sh" ;;   # 调用 modules/test_scripts.sh
            13) load_module "system_tools.sh" ;;  # 调用 modules/system_tools.sh (包含原 6,7,8,9,10,12,13,14 的功能)
            
            00) # 脚本更新功能
                echo -e "${YELLOW}脚本更新功能待实现，请手动拉取GitHub最新代码。${RESET}"; sleep 3
                ;;
            0) echo -e "${CYAN}感谢使用，再见！${RESET}"; exit 0 ;;
            *) echo -e "${RED}无效选项，请输入正确的数字${RESET}"; sleep 2 ;;
        esac
    done
}

# -------------------------------
# 主程序
# -------------------------------
check_root
check_deps
show_menu
