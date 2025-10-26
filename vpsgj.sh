#!/bin/bash
# 增强版VPS工具箱 v2.0.0 (模块化重构)
# GitHub: https://github.com/chengege666/bbr-gj

# -------------------------------
# 全局变量定义
# -------------------------------
RESULT_FILE="bbr_result.txt"
UNINSTALL_NOTE="vps_toolbox_uninstall_done.txt"

# 颜色定义
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
MAGENTA="\033[1;35m"
CYAN="\033[1;36m"
RESET="\033[0m"

# -------------------------------
# 核心路径修正 (V2.0.0 模块化必备)
# -------------------------------
# 步骤 1: 获取脚本所在的目录
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# 步骤 2: 更改工作目录到脚本所在目录，确保模块相对路径正确
# 这是解决 "未找到模块 modules/bbr_manager.sh" 问题的关键
cd "$SCRIPT_DIR" || exit 1 

print_welcome() {
    clear
    echo -e "${CYAN}==================================================${RESET}"
    echo -e "${MAGENTA}              增强版 VPS 工具箱 V2.0.0           ${RESET}"
    echo -e "${CYAN}--------------------------------------------------${RESET}"
    echo -e "${YELLOW}功能: 模块化管理 BBR, 系统, Docker, NPM等${RESET}"
    echo -e "${YELLOW}脚本目录:${RESET} $SCRIPT_DIR" # 打印当前工作目录，方便调试
    echo -e "${YELLOW}模块目录:${RESET} $SCRIPT_DIR/modules"
    echo -e "${CYAN}==================================================${RESET}"
    echo ""
}

# -------------------------------
# 基础检查和依赖 (保留在主脚本)
# -------------------------------
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}❌❌ 错误：请使用 root 权限运行本脚本${RESET}"
        echo "👉 使用方法: sudo bash $0"
        exit 1
    fi
}

# 依赖安装（简化，因为大部分工具已移入模块）
install_deps() {
    PKGS="curl wget git net-tools iptables"
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
    local MODULE_NAME=$1
    local MODULE_PATH="$SCRIPT_DIR/modules/$MODULE_NAME"
    
    if [ -f "$MODULE_PATH" ]; then
        # source 引入模块，使其函数在当前脚本可用
        source "$MODULE_PATH"
        
        # 模块的菜单函数名约定为 [文件名]_menu (例如 bbr_manager.sh -> bbr_manager_menu)
        local MODULE_FUNC=$(echo "$MODULE_NAME" | sed 's/\.sh$/_menu/') 
        
        if command -v "$MODULE_FUNC" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ 加载模块: ${MODULE_NAME}${RESET}"
            "$MODULE_FUNC" # 执行模块的入口函数
        else
            echo -e "${RED}❌ 错误: 模块 ${MODULE_NAME} 未定义入口函数 ${MODULE_FUNC}${RESET}"
            read -n1 -p "按任意键返回菜单..."
        fi
    else
        echo -e "${RED}❌ 错误: 未找到模块 $MODULE_PATH${RESET}"
        read -n1 -p "按任意键返回菜单..."
    fi
}

# -------------------------------
# 功能 00: 脚本更新
# -------------------------------
script_update() {
    echo -e "${CYAN}=== 脚本更新 ===${RESET}"
    echo -e "${YELLOW}此功能应从GitHub拉取最新代码，请确保您有git权限。${RESET}"
    read -p "是否尝试使用git拉取最新脚本？(y/N): " confirm_git
    if [[ "$confirm_git" == "y" || "$confirm_git" == "Y" ]]; then
        if command -v git >/dev/null 2>&1; then
            echo -e "${GREEN}正在拉取最新代码...${RESET}"
            git pull
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✅ 脚本更新成功，请重新运行脚本。${RESET}"
            else
                echo -e "${RED}❌❌ Git拉取失败，请手动检查。${RESET}"
            fi
        else
            echo -e "${RED}未安装 git，无法自动更新。${RESET}"
        fi
    fi
    read -n1 -p "按任意键返回菜单..."
}

# -------------------------------
# 功能 0: 卸载脚本 (需要实现)
# -------------------------------
uninstall_script() {
    echo -e "${CYAN}=== 卸载脚本 ===${RESET}"
    echo -e "${YELLOW}此功能将清理脚本安装的相关组件${RESET}"
    read -p "确定要卸载吗？(y/N): " confirm_uninstall
    if [[ "$confirm_uninstall" == "y" || "$confirm_uninstall" == "Y" ]]; then
        # 这里添加卸载逻辑
        echo -e "${GREEN}✅ 卸载功能待实现${RESET}"
        touch "$UNINSTALL_NOTE"
    fi
    read -n1 -p "按任意键返回菜单..."
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
        echo -e "${MAGENTA}5. BBR管理${RESET}" # 调用 modules/bbr_manager.sh
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
            5) load_module "bbr_manager.sh" ;;    
            6) load_module "docker_manager.sh" ;; 
            8) load_module "test_scripts.sh" ;;   
            13) load_module "system_tools.sh" ;;  
            
            00) script_update ;;
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
