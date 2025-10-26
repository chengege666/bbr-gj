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
    # 依赖中移除 speedtest-cli, 因为已移动到模块中
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
    # 依赖中移除 speedtest-cli 检查
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

# 模块加载函数
load_module() {
    MODULE_NAME=$1
    # 模块路径使用相对路径，根据您的目录结构
    MODULE_PATH="modules/$MODULE_NAME"
    
    if [ -f "$MODULE_PATH" ]; then
        echo -e "${CYAN}=== 调用模块: ${MODULE_NAME} ===${RESET}"
        # 使用 source 引入模块中的函数
        source "$MODULE_PATH"
        
        # 模块的菜单函数名约定为 [文件名]_menu (例如 bbr_manager.sh -> bbr_manager_menu)
        MODULE_FUNC=$(echo "$MODULE_NAME" | sed 's/\.sh$/_menu/') 
        
        # 检查并调用模块的主菜单函数
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
# --- 以下是 V1.3.0 中被移除/保留在主脚本的功能 ---
# ====================================================================

# -------------------------------
# **已移除** V1.3.0 中的 BBR 相关函数:
# run_test
# bbr_test_menu
# run_bbr_switch
# **原因:** 已移至 modules/bbr_manager.sh
# -------------------------------

# -------------------------------
# **已移除** V1.3.0 中的部分系统功能，现应由模块提供:
# show_sys_info
# sys_update
# sys_cleanup
# glibc_menu
# full_system_upgrade
# **原因:** 这些功能应移至 modules/system_info.sh, modules/system_update.sh, modules/system_cleanup.sh 等。
# -------------------------------

# -------------------------------
# **保留** V1.3.0 中未模块化的系统工具函数:
# (ip_version_switch, timezone_adjust, system_reboot, ssh_config_menu, firewall_menu_advanced, docker_menu, npm_menu, uninstall_script)
# 这些函数体从 V1.3.0 脚本中复制过来。
# -------------------------------

# ***********************************************
# (为简洁，这里省略了未模块化的函数体，如 ip_version_switch, timezone_adjust, system_reboot 等，
#  您应保留它们在 vpsgj.sh 中或将其移入 modules/system_tools.sh 等相应模块。)
# ***********************************************

# 从 V1.3.0 中保留的 ip_version_switch 函数
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

# 从 V1.3.0 中保留的 system_reboot 函数
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

# 从 V1.3.0 中保留的 docker_menu 函数
# ... (此处省略 docker_menu, ssh_config_menu, firewall_menu_advanced, npm_menu 的代码体)
# ... **注意：在 V2.0.0 结构中，`docker_manager.sh` 应包含这些功能，但根据您的 V1.3.0 结构，它们暂时保留在主脚本中，直到您将它们移入模块**
# -------------------------------
# 由于您提供的 V1.3.0 脚本中这些函数是完整的，
# 且 V2.0.0 菜单截图显示了 Docker 管理 (6) 和 系统工具 (13)，
# 它们应该被 load_module 调用。因此，这些函数（如 docker_menu）在最终版本中应移入 modules/docker_manager.sh 和 modules/system_tools.sh。
# 但为了让这个 V2.0.0 示例运行起来，我们假设它们已经移入了对应的模块，
# 所以在主脚本中，**必须**将 `docker_menu`, `firewall_menu_advanced`, `npm_menu`, `ssh_config_menu` 等函数体移除，
# 否则在加载模块时会产生函数重定义冲突。

# -------------------------------
# **保留** 脚本卸载函数 (Function 15)
# -------------------------------
uninstall_script() {
    read -p "确定要卸载本脚本并清理相关文件吗 (y/n)? ${RED}此操作不可逆!${RESET}: " confirm_uninstall
    if [[ "$confirm_uninstall" == "y" || "$confirm_uninstall" == "Y" ]]; then
        echo -e "${YELLOW}正在清理 ${SCRIPT_FILE}, ${RESULT_FILE} 等文件...${RESET}"
        # 增加对模块目录的清理，如果存在
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
            1) load_module "system_info.sh" ;; # 调用 modules/system_info.sh
            2) load_module "system_update.sh" ;; # 调用 modules/system_update.sh
            3) load_module "system_cleanup.sh" ;; # 调用 modules/system_cleanup.sh
            4) load_module "basic_tools.sh" ;; # 调用 modules/basic_tools.sh
            5) load_module "bbr_manager.sh" ;; # 调用 modules/bbr_manager.sh
            6) load_module "docker_manager.sh" ;; # 调用 modules/docker_manager.sh
            8) load_module "test_scripts.sh" ;; # 调用 modules/test_scripts.sh
            13) load_module "system_tools.sh" ;; # 调用 modules/system_tools.sh
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
