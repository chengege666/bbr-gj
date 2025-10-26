#!/bin/bash
# 增强版VPS工具箱 v2.0 - 路径修复版
# GitHub: https://github.com/chengege666/bbr-gj

# 获取脚本真实路径
get_script_dir() {
    SOURCE="${BASH_SOURCE[0]}"
    while [ -h "$SOURCE" ]; do
        DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
        SOURCE="$(readlink "$SOURCE")"
        [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
    done
    echo "$( cd -P "$( dirname "$SOURCE" )" && pwd )"
}

# 设置正确的路径
SCRIPT_DIR=$(get_script_dir)
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
GITHUB_BASE="https://raw.githubusercontent.com/chengege666/bbr-gj/main"

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
                echo -极速模式 (已停止)
