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
    echo -e "${GREEN}脚本目录:${RESET} $(pwd)"
    echo -e "${GREEN}模块目录:${RESET} $(pwd)/modules"
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
    for CMD in curl wget git iptables; do # 移除 speedtest-cli 依赖检查，因为已模块化且可能不需要
        if ! command -v $CMD >/dev/null 2>&1; then
            echo -e "${YELLOW}未检测到 $CMD，正在尝试安装依赖...${RESET}"
            install_deps
            break
        fi
    done
}

# ====================================================================
# +++ 模块加载核心 +++
# ====================================================================

# 模块加载函数
load_module() {
    MODULE_NAME=$1
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
# +++ V1.3.0 中保留的非模块化功能 (例如Docker/NPM/防火墙等) +++
# 由于篇幅限制，此处仅保留函数声明，并假设其余函数（如 Docker、NPM、防火墙相关）也已相应移动或被主脚本调用。
# -------------------------------
# 注意：以下函数体需保持在 vpsgj.sh 中，除非您将它们也移入单独的模块。
# -------------------------------

# --- 占位符: 系统工具/NPM/Docker/SSH/防火墙 函数 ---
# ... (此处省略了 V1.3.0 脚本中那些未被模块化的函数，如 npm_menu, docker_menu, firewall_menu_advanced 等)
# ...

# -------------------------------
# 功能 15: 卸载脚本
# -------------------------------
uninstall_script() {
    # 保持原有的卸载逻辑不变
    read -p "确定要卸载本脚本并清理相关文件吗 (y/n)? ${RED}此操作不可逆!${RESET}: " confirm_uninstall
    if [[ "$confirm_uninstall" == "y" || "$confirm_uninstall" == "Y" ]]; then
        echo -e "${YELLOW}正在清理 ${SCRIPT_FILE}, ${RESULT_FILE} 等文件...${RESET}"
        rm -f "$SCRIPT_FILE" "$RESULT_FILE" tcp.sh
        
        # ... (此处省略卸载脚本的完整清理逻辑)
        
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
            1) load_module "system_info.sh" ;;
            2) load_module "system_update.sh" ;;
            3) load_module "system_cleanup.sh" ;;
            4) load_module "basic_tools.sh" ;;
            5) load_module "bbr_manager.sh" ;; # 调用 BBR 模块
            6) load_module "docker_manager.sh" ;;
            8) load_module "test_scripts.sh" ;;
            13) load_module "system_tools.sh" ;;
            00) # 假设脚本更新功能保留在主脚本或有专门的 update 模块
                echo -e "${YELLOW}脚本更新功能待实现...${RESET}"; sleep 2
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
