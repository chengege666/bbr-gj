#!/bin/bash
# 增强版VPS工具箱 v2.0 - 修复版
# GitHub: https://github.com/chengege666/vpsgj

# 获取脚本真实路径（修复路径问题）
realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

SCRIPT_PATH=$(realpath "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
MODULES_DIR="$SCRIPT_DIR/modules"
CONFIG_DIR="$SCRIPT_DIR/config"
CACHE_DIR="$SCRIPT_DIR/.cache"

# 创建必要目录
mkdir -p "$MODULES_DIR" "$CONFIG_DIR" "$CACHE_DIR"

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
# 版本信息
# -------------------------------
VERSION="2.0.0"
GITHUB_BASE="https://raw.githubusercontent.com/chengege666/vpsgj/main"

# -------------------------------
# 核心函数
# -------------------------------
print_welcome() {
    clear
    echo -e "${CYAN}==================================================${RESET}"
    echo -e "${MAGENTA}          增强版 VPS 工具箱 v${VERSION}         ${RESET}"
    echo -e "${CYAN}==================================================${RESET}"
    echo ""
    echo -e "${YELLOW}脚本目录: $SCRIPT_DIR${RESET}"
    echo -e "${YELLOW}模块目录: $MODULES_DIR${RESET}"
    echo ""
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}❌ 错误：请使用 root 权限运行本脚本${RESET}"
        echo "👉 使用方法: sudo bash vpsgj.sh"
        exit 1
    fi
}

check_deps() {
    local deps=("curl" "wget")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo -e "${YELLOW}未检测到 $dep，正在安装...${RESET}"
            install_deps
            return
        fi
    done
}

install_deps() {
    if command -v apt >/dev/null 2>&1; then
        apt update -y && apt install -y curl wget
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl wget
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y curl wget
    else
        echo -e "${YELLOW}⚠️ 请手动安装依赖: curl wget${RESET}"
    fi
}

# -------------------------------
# 模块管理系统（修复版）
# -------------------------------
load_module() {
    local module_name="$1"
    local module_file="$MODULES_DIR/${module_name}.sh"
    
    # 检查模块文件是否存在
    if [[ -f "$module_file" ]]; then
        echo -e "${GREEN}✅ 加载模块: $module_name${RESET}"
        source "$module_file"
        return 0
    else
        echo -e "${YELLOW}模块文件不存在: $module_file${RESET}"
        echo -e "${CYAN}正在下载模块...${RESET}"
        if download_module "$module_name"; then
            if [[ -f "$module_file" ]]; then
                source "$module_file"
                return 0
            else
                echo -e "${RED}❌ 模块下载后仍不存在: $module_name${RESET}"
                return 1
            fi
        else
            echo -e "${RED}❌ 模块下载失败: $module_name${RESET}"
            return 1
        fi
    fi
}

download_module() {
    local module_name="$1"
    local module_url="$GITHUB_BASE/modules/${module_name}.sh"
    local module_file="$MODULES_DIR/${module_name}.sh"
    
    echo -e "${CYAN}>>> 下载模块: $module_name${RESET}"
    echo -e "${YELLOW}下载URL: $module_url${RESET}"
    echo -e "${YELLOW}保存到: $module_file${RESET}"
    
    # 确保模块目录存在
    mkdir -p "$MODULES_DIR"
    
    # 使用 curl 或 wget 下载
    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL "$module_url" -o "$module_file"; then
            chmod +x "$module_file"
            echo -e "${GREEN}✅ 模块下载成功: $module_name${RESET}"
            return 0
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -q "$module_url" -O "$module_file"; then
            chmod +x "$module_file"
            echo -e "${GREEN}✅ 模块下载成功: $module_name${RESET}"
            return 0
        fi
    else
        echo -e "${RED}❌ 未找到 curl 或 wget${RESET}"
    fi
    
    echo -e "${RED}❌ 模块下载失败: $module_name${RESET}"
    return 1
}

check_module_updates() {
    echo -e "${CYAN}>>> 检查模块更新...${RESET}"
    local update_cache="$CACHE_DIR/last_update_check"
    local current_time=$(date +%s)
    local last_check=0
    
    if [[ -f "$update_cache" ]]; then
        last_check=$(cat "$update_cache")
    fi
    
    # 每24小时检查一次更新
    if (( current_time - last_check > 86400 )); then
        echo "$current_time" > "$update_cache"
        echo -e "${GREEN}模块更新检查已启用${RESET}"
    fi
}

# -------------------------------
# 主菜单功能
# -------------------------------
call_module() {
    local module_name="$1"
    local function_name="${2:-main}"
    
    echo -e "${CYAN}=== 调用模块: $module_name ===${RESET}"
    
    if load_module "$module_name"; then
        if declare -f "$function_name" > /dev/null; then
            $function_name
        else
            echo -e "${RED}❌ 函数 $function_name 不存在于模块 $module_name 中${RESET}"
            press_any_key
        fi
    else
        echo -e "${RED}❌ 无法加载模块: $module_name${RESET}"
        echo -e "${YELLOW}请检查网络连接或模块名称是否正确${RESET}"
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

script_update() {
    echo -e "${CYAN}=== 脚本更新 ===${RESET}"
    local backup_file="vpsgj.sh.backup.$(date +%Y%m%d%H%M%S)"
    
    echo -e "${YELLOW}备份当前脚本...${RESET}"
    cp "$0" "$backup_file"
    
    echo -e "${YELLOW}下载最新版本...${RESET}"
    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL "$GITHUB_BASE/vpsgj.sh" -o "vpsgj.sh.new"; then
            mv "vpsgj.sh.new" "vpsgj.sh"
            chmod +x "vpsgj.sh"
            echo -e "${GREEN}✅ 脚本更新完成！${RESET}"
            echo -e "${YELLOW}请重新运行脚本${RESET}"
            exit 0
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -q "$GITHUB_BASE/vpsgj.sh" -O "vpsgj.sh.new"; then
            mv "vpsgj.sh.new" "vpsgj.sh"
            chmod +x "vpsgj.sh"
            echo -e "${GREEN}✅ 脚本更新完成！${RESET}"
            echo -e "${YELLOW}请重新运行脚本${RESET}"
            exit 0
        fi
    fi
    
    echo -e "${RED}❌ 更新失败${RESET}"
    mv "$backup_file" "vpsgj.sh"
    press_any_key
}

exit_script() {
    echo -e "${GREEN}感谢使用，再见！${RESET}"
    exit 0
}

# -------------------------------
# 主菜单（根据图片调整）
# -------------------------------
show_menu() {
    while true; do
        print_welcome
        check_module_updates
        
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
            1) call_module "system_info" ;;
            2) call_module "system_update" ;;
            3) call_module "system_cleanup" ;;
            4) call_module "basic_tools" ;;
            5) call_module "bbr_manager" ;;
            6) call_module "docker_manager" ;;
            8) call_module "test_scripts" ;;
            13) call_module "system_tools" ;;
            00) script_update ;;
            0) exit_script ;;
            *) echo -e "${RED}无效选择${RESET}"; sleep 1 ;;
        esac
    done
}

# -------------------------------
# 初始化检查
# -------------------------------
initialize() {
    echo -e "${CYAN}>>> 初始化检查...${RESET}"
    echo -e "${GREEN}脚本路径: $SCRIPT_PATH${RESET}"
    echo -e "${GREEN}工作目录: $SCRIPT_DIR${RESET}"
    echo -e "${GREEN}模块目录: $MODULES_DIR${RESET}"
    
    # 检查模块目录权限
    if [ ! -w "$MODULES_DIR" ]; then
        echo -e "${YELLOW}模块目录不可写，尝试修复权限...${RESET}"
        chmod 755 "$MODULES_DIR" 2>/dev/null || true
    fi
    
    # 创建必要的目录
    mkdir -p "$MODULES_DIR" "$CONFIG_DIR" "$CACHE_DIR"
    echo -e "${GREEN}✅ 初始化完成${RESET}"
    sleep 1
}

# -------------------------------
# 主程序
# -------------------------------
main() {
    check_root
    initialize
    check_deps
    show_menu
}

# 运行主程序
main "$@"
