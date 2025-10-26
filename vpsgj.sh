#!/bin/bash
# 增强版VPS工具箱 - 精简版
# GitHub: https://github.com/chengege666/vpsgj

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"

# 创建模块目录
mkdir -p "$MODULES_DIR"

# -------------------------------
# 颜色定义
# -------------------------------
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
MAGENTA="\033[1;35m"
CYAN="\033[1;36m"
BLUE="\033[1;34m"
WHITE="\033[1;37m"
RESET="\033[0m"

# -------------------------------
# 核心函数
# -------------------------------
print_welcome() {
    clear
    echo -e "${CYAN}==================================================${RESET}"
    echo -e "${MAGENTA}              增强版 VPS 工具箱           ${RESET}"
    echo -e "${CYAN}==================================================${RESET}"
    echo ""
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}❌❌❌❌ 错误：请使用 root 权限运行本脚本${RESET}"
        echo "👉 使用方法: sudo bash vpsgj.sh"
        exit 1
    fi
}

check_deps() {
    local PKGS="curl wget"
    for CMD in curl wget; do
        if ! command -v $CMD >/dev/null 2>&1; then
            echo -e "${YELLOW}未检测到 $CMD，正在尝试安装依赖...${RESET}"
            install_deps
            break
        fi
    done
}

install_deps() {
    local PKGS="curl wget"
    if command -v apt >/dev/null 2>&1; then
        apt update -y
        apt install -y $PKGS
    elif command -v yum >/dev/null 2>&1; then
        yum install -y $PKGS
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y $PKGS
    else
        echo -e "${YELLOW}⚠️ 未知系统，请手动安装依赖: $PKGS${RESET}"
    fi
}

# -------------------------------
# 模块加载系统
# -------------------------------
load_module() {
    local module_name="$1"
    local module_file="$MODULES_DIR/${module_name}.sh"
    
    if [[ -f "$module_file" ]]; then
        source "$module_file"
        return 0
    else
        echo -e "${YELLOW}模块文件不存在: $module_file${RESET}"
        echo -e "${CYAN}正在下载模块...${RESET}"
        download_module "$module_name"
        if [[ -f "$module_file" ]]; then
            source "$module_file"
            return 0
        else
            echo -e "${RED}❌ 模块加载失败: $module_name${RESET}"
            return 1
        fi
    fi
}

download_module() {
    local module_name="$1"
    local github_base="https://raw.githubusercontent.com/chengege666/vpsgj/main/modules"
    
    echo -e "${CYAN}>>> 下载模块: $module_name${RESET}"
    if wget -q "${github_base}/${module_name}.sh" -O "$MODULES_DIR/${module_name}.sh"; then
        chmod +x "$MODULES_DIR/${module_name}.sh"
        return 0
    else
        echo -e "${RED}❌ 模块下载失败: $module_name${RESET}"
        return 1
    fi
}

# -------------------------------
# 主菜单功能调用
# -------------------------------
call_module_function() {
    local module_name="$1"
    local function_name="$2"
    
    if load_module "$module_name"; then
        # 检查函数是否存在
        if declare -f "$function_name" > /dev/null; then
            $function_name
        else
            echo -e "${RED}❌ 函数 $function_name 不存在于模块 $module_name 中${RESET}"
            press_any_key
        fi
    else
        echo -e "${RED}❌ 无法加载模块: $module_name${RESET}"
        press_any_key
    fi
}

# -------------------------------
# 工具函数
# -------------------------------
press_any_key() {
    echo ""
    read -n1 -p "按任意键继续..."
    echo -e "\n"
}

# 脚本更新
script_update() {
    echo -e "${CYAN}=== 脚本更新 ===${RESET}"
    echo -e "${YELLOW}检查更新...${RESET}"
    
    # 备份当前脚本
    cp vpsgj.sh vpsgj.sh.backup.$(date +%Y%m%d%H%M%S)
    
    # 下载最新版本
    if wget -O vpsgj.sh.new "https://raw.githubusercontent.com/chengege666/vpsgj/main/vpsgj.sh"; then
        mv vpsgj.sh.new vpsgj.sh
        chmod +x vpsgj.sh
        echo -e "${GREEN}脚本更新完成！请重新运行。${RESET}"
        exit 0
    else
        echo -e "${RED}更新失败，请检查网络连接${RESET}"
    fi
    press_any_key
}

# 退出脚本
exit_script() {
    echo -e "${GREEN}感谢使用，再见！${RESET}"
    exit 0
}

# -------------------------------
# 主菜单
# -------------------------------
show_menu() {
    while true; do
        print_welcome
        
        echo -e "${WHITE}1. 系统信息查询${RESET}"
        echo -e "${WHITE}2. 系统更新${RESET}"
        echo -e "${WHITE}3. 系统清理${RESET}"
        echo -e "${WHITE}4. 基础工具${RESET}"
        echo -e "${WHITE}5. BBR管理${RESET}"
        echo -e "${WHITE}6. Docker管理${RESET}"
        echo -e "${WHITE}8. 测试脚本合集${RESET}"
        echo -e "${WHITE}13. 系统工具${RESET}"
        echo -e "${CYAN}00. 脚本更新${RESET}"
        echo -e "${RED}0. 退出脚本${RESET}"
        echo ""
        
        read -p "请输入你的选择: " choice
        
        case "$choice" in
            1) call_module_function "system_info" "main" ;;
            2) call_module_function "system_update" "main" ;;
            3) call_module_function "system_cleanup" "main" ;;
            4) call_module_function "basic_tools" "main" ;;
            5) call_module_function "bbr_manager" "main" ;;
            6) call_module_function "docker_manager" "main" ;;
            8) call_module_function "test_scripts" "main" ;;
            13) call_module_function "system_tools" "main" ;;
            00) script_update ;;
            0) exit_script ;;
            *) echo -e "${RED}无效选择，请重新输入${RESET}"; sleep 2 ;;
        esac
    done
}

# -------------------------------
# 主程序
# -------------------------------
main() {
    check_root
    check_deps
    show_menu
}

# 运行主程序
main "$@"
