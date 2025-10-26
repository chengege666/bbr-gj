#!/bin/bash
# 增强版VPS工具箱 v1.3.0 (模块化版本)
# GitHub: https://github.com/chengege666/bbr-gj

# -------------------------------
# 基础配置
# -------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"

# 全局变量
RESULT_FILE="bbr_result.txt"
UNINSTALL_NOTE="vps_toolbox_uninstall_done.txt"
IP_VERSION="4"

# -------------------------------
# 加载模块
# -------------------------------
load_modules() {
    # 创建模块目录
    mkdir -p "$MODULES_DIR"
    
    # 检查模块是否存在，如果不存在则尝试下载
    if [ ! -f "$MODULES_DIR/common.sh" ]; then
        echo -e "\033[1;33m模块文件不存在，尝试下载...\033[0m"
        download_modules
    fi
    
    # 加载公共函数
    if [ -f "$MODULES_DIR/common.sh" ]; then
        source "$MODULES_DIR/common.sh"
    else
        echo -e "\033[1;31m错误：无法加载公共模块\033[0m"
        exit 1
    fi
    
    # 加载功能模块
    local modules=("bbr_functions.sh" "system_functions.sh" "docker_functions.sh" "firewall_functions.sh" "npm_functions.sh")
    for module in "${modules[@]}"; do
        if [ -f "$MODULES_DIR/$module" ]; then
            source "$MODULES_DIR/$module"
        else
            echo -e "\033[1;33m警告：缺少模块 $module\033[0m"
        fi
    done
}

# 下载模块文件
download_modules() {
    local base_url="https://raw.githubusercontent.com/chengege666/bbr-gj/main/modules"
    local modules=("common.sh" "bbr_functions.sh" "system_functions.sh" "docker_functions.sh" "firewall_functions.sh" "npm_functions.sh")
    
    echo -e "\033[1;36m正在下载模块文件...\033[0m"
    for module in "${modules[@]}"; do
        echo -e "下载: $module"
        if wget -q -O "$MODULES_DIR/$module" "$base_url/$module"; then
            chmod +x "$MODULES_DIR/$module"
            echo -e "\033[1;32m✅ $module 下载成功\033[0m"
        else
            echo -e "\033[1;31m❌ $module 下载失败\033[0m"
        fi
    done
}

# -------------------------------
# 主菜单
# -------------------------------
main_menu() {
    # 初始化检查
    check_root
    load_modules
    check_deps
    
    while true; do
        print_welcome
        echo -e "请选择操作："
        echo -e "\033[1;32m--- BBR 测速与切换 ---\033[0m"
        echo "1) BBR 综合测速 (BBR/BBR Plus/BBRv2/BBRv3 对比)"
        echo "2) 安装/切换 BBR 内核"
        echo -e "\033[1;32m--- VPS 系统管理 ---\033[0m"
        echo "3) 查看系统信息 (OS/CPU/内存/IP/BBR/GLIBC)"
        echo "4) 更新软件包并升级 (不升级内核)"
        echo "5) 系统清理 (清理旧版依赖包)"
        echo "6) IPv4/IPv6 切换 (当前: IPv$IP_VERSION)"
        echo "7) 系统时区调整"
        echo "8) 系统重启"
        echo "9) GLIBC 管理"
        echo "10) 全面系统升级 (含内核升级)"
        echo -e "\033[1;32m--- 服务与安全 ---\033[0m"
        echo "11) 高级 Docker 管理"
        echo "12) SSH 端口与密码修改"
        echo "13) 高级防火墙管理 (iptables)"
        echo "14) Nginx Proxy Manager 管理"
        echo -e "\033[1;32m--- 其他 ---\033[0m"
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
            0) echo -e "\033[1;36m感谢使用，再见！\033[0m"; exit 0 ;;
            *) echo -e "\033[1;31m无效选项，请输入 0-15\033[0m"; sleep 2 ;;
        esac
    done
}

# 启动主程序
main_menu
