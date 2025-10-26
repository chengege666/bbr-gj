#!/bin/bash

# VPS一键管理脚本 v0.5
# 作者: 智能助手
# 最后更新: 2025-10-27

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # 重置颜色

# 结果文件路径
RESULT_FILE="/tmp/bbr_test_results.txt"

# -------------------------------
# root 权限检查
# -------------------------------
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}❌❌ 错误：请使用 root 权限运行本脚本${NC}"
        echo "👉 使用方法: sudo bash $0"
        exit 1
    fi
}

# -------------------------------
# 依赖安装
# -------------------------------
install_deps() {
    PKGS="curl wget git net-tools"
    if command -v apt >/dev/null 2>&1; then
        echo -e "${YELLOW}正在更新软件包列表...${NC}"
        apt update -y
        echo -e "${YELLOW}正在安装依赖: $PKGS${NC}"
        apt install -y $PKGS
    elif command -v yum >/dev/null 2>&1; then
        echo -e "${YELLOW}正在安装依赖: $PKGS${NC}"
        yum install -y $PKGS
    elif command -v dnf >/dev/null 2>&1; then
        echo -e "${YELLOW}正在安装依赖: $PKGS${NC}"
        dnf install -y $PKGS
    else
        echo -e "${YELLOW}⚠️ 未知系统，请手动安装依赖: $PKGS${NC}"
        read -n1 -p "按任意键继续菜单..."
    fi
}

check_deps() {
    for CMD in curl wget git; do
        if ! command -v $CMD >/dev/null 2>&1; then
            echo -e "${YELLOW}未检测到 $CMD，正在尝试安装依赖...${NC}"
            install_deps
            break
        fi
    done
}

# 显示菜单函数
show_menu() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "          VPS 脚本管理菜单 v0.5           "
    echo "=========================================="
    echo -e "${NC}"
    echo "1. 系统信息查询"
    echo "2. 系统更新"
    echo "3. 系统清理"
    echo "4. 基础工具"
    echo "5. BBR管理"
    echo "6. Docker管理"
    echo "7. 系统工具"
    echo "0. 退出脚本"
    echo "=========================================="
}

# 检查BBR状态函数
check_bbr() {
    # 检查是否启用了BBR
    local bbr_enabled=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    local bbr_module=$(lsmod | grep bbr)
    
    # 获取默认队列算法
    local default_qdisc=$(sysctl net.core.default_qdisc | awk '{print $3}')
    
    # 获取BBR参数
    local bbr_params=$(sysctl -a 2>/dev/null | grep -E "bbr|tcp_congestion_control" | grep -v '^net.core' | sort)
    
    # 检查BBR版本
    local bbr_version=""
    if [[ "$bbr_enabled" == *"bbr"* ]]; then
        if [[ "$bbr_enabled" == "bbr" ]]; then
            bbr_version="BBR v1"
        elif [[ "$bbr_enabled" == "bbr2" ]]; then
            bbr_version="BBR v2"
        else
            bbr_version="未知BBR类型"
        fi
        
        # 返回BBR信息
        echo -e "${GREEN}已启用${NC} ($bbr_version)"
        echo -e "${BLUE}默认队列算法: ${NC}$default_qdisc"
        echo -e "${BLUE}BBR参数:${NC}"
        echo "$bbr_params" | while read -r line; do
            echo "  $line"
        done
    elif [[ -n "$bbr_module" ]]; then
        echo -e "${YELLOW}已加载但未启用${NC}"
        echo -e "${BLUE}默认队列算法: ${NC}$default_qdisc"
    else
        echo -e "${RED}未启用${NC}"
        echo -e "${BLUE}默认队列算法: ${NC}$default_qdisc"
    fi
}

# 系统信息查询函数
system_info() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "              系统信息查询                "
    echo "=========================================="
    echo -e "${NC}"

    # 1. 主机名
    echo -e "${BLUE}主机名: ${GREEN}$(hostname)${NC}"

    # 2. 操作系统版本
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        echo -e "${BLUE}操作系统: ${NC}$PRETTY_NAME"
    else
        echo -e "${BLUE}操作系统: ${NC}未知"
    fi

    # 3. 内核版本
    echo -e "${BLUE}内核版本: ${NC}$(uname -r)"

    # 4. CPU信息
    cpu_model=$(grep 'model name' /proc/cpuinfo | head -1 | cut -d ':' -f2 | sed 's/^ *//')
    cpu_cores=$(grep -c '^processor' /proc/cpuinfo)
    echo -e "${BLUE}CPU型号: ${NC}$cpu_model"
    echo -e "${BLUE}CPU核心数: ${NC}$cpu_cores"

    # 5. 内存信息
    total_mem=$(free -m | awk '/Mem:/ {print $2}')
    available_mem=$(free -m | awk '/Mem:/ {print $7}')
    echo -e "${BLUE}总内存: ${NC}${total_mem}MB"
    echo -e "${BLUE}可用内存: ${NC}${available_mem}MB"

    # 6. 硬盘信息
    disk_usage=$(df -h / | awk 'NR==2 {print $5}')
    disk_total=$(df -h / | awk 'NR==2 {print $2}')
    disk_used=$(df -h / | awk 'NR==2 {print $3}')
    echo -e "${BLUE}根分区使用率: ${NC}$disk_usage (已用 ${disk_used} / 总共 ${disk_total})"

    # 7. 公网IPv4地址
    ipv4=$(curl -s --connect-timeout 2 ipv4.icanhazip.com)
    if [ -z "$ipv4" ]; then
        ipv4=$(curl -s --connect-timeout 2 ipv4.ip.sb)
    fi
    if [ -z "$ipv4" ]; then
        ipv4="${RED}无法获取${NC}"
    else
        ipv4="${YELLOW}$ipv4${NC}"
    fi
    echo -e "${BLUE}公网IPv4: $ipv4"

    # 8. 公网IPv6地址
    ipv6=$(curl -s --connect-timeout 2 ipv6.icanhazip.com)
    if [ -z "$ipv6" ]; then
        ipv6=$(curl -s --connect-timeout 2 ipv6.ip.sb)
    fi
    if [ -z "$ipv6" ]; then
        ipv6="${RED}未检测到${NC}"
    else
        ipv6="${YELLOW}$ipv6${NC}"
    fi
    echo -e "${BLUE}公网IPv6: $ipv6"
    
    # 9. BBR状态
    echo -e "${BLUE}BBR状态: ${NC}"
    check_bbr

    # 10. 系统运行时间
    uptime_info=$(uptime -p | sed 's/up //')
    echo -e "${BLUE}系统运行时间: ${NC}$uptime_info"

    # 11. 当前时间（北京时间）
    beijing_time=$(TZ='Asia/Shanghai' date +'%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}北京时间: ${NC}$beijing_time"

    echo -e "${CYAN}"
    echo "=========================================="
    echo -e "${NC}"
    read -p "按回车键返回主菜单..."
}

# 系统更新函数
system_update() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "              系统更新功能                "
    echo "=========================================="
    echo -e "${NC}"
    
    # 检查系统类型
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu系统
        echo -e "${BLUE}检测到 Debian/Ubuntu 系统${NC}"
        echo -e "${YELLOW}开始更新系统...${NC}"
        echo ""
        
        # 更新软件包列表
        echo -e "${BLUE}[步骤1/3] 更新软件包列表...${NC}"
        apt update
        echo ""
        
        # 升级软件包
        echo -e "${BLUE}[步骤2/3] 升级软件包...${NC}"
        apt upgrade -y
        echo ""
        
        # 清理不再需要的包
        echo -e "${BLUE}[步骤3/3] 清理系统...${NC}"
        apt autoremove -y
        apt autoclean
        echo ""
        
        echo -e "${GREEN}系统更新完成！${NC}"
        
    elif [ -f /etc/redhat-release ]; then
        # CentOS/RHEL系统
        echo -e "${BLUE}检测到 CentOS/RHEL 系统${NC}"
        echo -e "${YELLOW}开始更新系统...${NC}"
        echo ""
        
        # 更新软件包
        echo -e "${BLUE}[步骤1/2] 更新软件包...${NC}"
        yum update -y
        echo ""
        
        # 清理缓存
        echo -e "${BLUE}[步骤2/2] 清理系统...${NC}"
        yum clean all
        yum autoremove -y
        echo ""
        
        echo -e "${GREEN}系统更新完成！${NC}"
        
    else
        echo -e "${RED}不支持的系统类型！${NC}"
        echo -e "${YELLOW}仅支持 Debian/Ubuntu 和 CentOS/RHEL 系统。${NC}"
    fi
    
    echo -e "${CYAN}"
    echo "=========================================="
    echo -e "${NC}"
    read -p "按回车极返回主菜单..."
}

# 系统清理函数
system_clean() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "              系统清理功能                "
    echo "=========================================="
    echo -e "${NC}"
    
    # 显示警告信息
    echo -e "${YELLOW}⚠️ 警告：系统清理操作将删除不必要的文件，请谨慎操作！${NC}"
    echo ""
    
    # 确认操作
    read -p "是否继续执行系统清理？(y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}已取消系统清理操作${NC}"
        read -p "按回车键返回主菜单..."
        return
    fi
    
    # 检查系统类型
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu系统
        echo -e "${BLUE}检测到 Debian/Ubuntu 系统${NC}"
        echo -e "${YELLOW}开始清理系统...${NC}"
        echo ""
        
        # 清理APT缓存
        echo -e "${BLUE}[步骤1/4] 清理APT缓存...${NC}"
        apt clean
        echo ""
        
        # 清理旧内核
        echo -e "${BLUE}[步骤2/4] 清理旧内核...${NC}"
        apt autoremove --purge -y
        echo ""
        
        # 清理日志文件
        echo -e "${BLUE}[步骤3/4] 清理日志文件...${NC}"
        journalctl --vacuum-time=1d
        find /var/log -type f -regex ".*\.gz$" -delete
        find /var/log -type f -regex ".*\.[0-9]$" -delete
        echo ""
        
        # 清理临时文件
        echo -e "${BLUE}[步骤4/4] 清理临时文件...${NC}"
        rm -rf /tmp/*
        rm -rf /var/tmp/*
        echo ""
        
        echo -e "${GREEN}系统清理完成！${NC}"
        
    elif [ -f /etc/redhat-release ]; then
        # CentOS/RHEL系统
        echo -e "${BLUE}检测到 CentOS/RHEL 系统${NC}"
        echo -e "${YELLOW}开始清理系统...${NC}"
        echo ""
        
        # 清理YUM缓存
        echo -极 "${BLUE}[步骤1/4] 清理YUM缓存...${NC}"
        yum clean all
        echo ""
        
        # 清理旧内核
        echo -e "${BLUE}[步骤2/4] 清理旧内核...${NC}"
        package-cleanup --oldkernels --count=1 -y
        echo ""
        
        # 清理日志文件
        echo -e "${BLUE}[步骤3/4] 清理日志文件...${NC}"
        journalctl --vacuum-time=1d
        find /var/log -type f -regex ".*\.gz$" -delete
        find /var/log -type f -regex ".*\.[0-9]$" -delete
        echo ""
        
        # 清理临时文件
        echo -e "${BLUE}[步骤4/4] 清理临时文件...${NC}"
        rm -rf /tmp/*
        rm -rf /var/tmp/*
        echo ""
        
        echo -e "${GREEN}系统清理完成！${NC}"
        
    else
        echo -e "${RED}不支持的系统类型！${NC}"
        echo -e "${YELLOW}仅支持 Debian/Ubuntu 和 CentOS/RHEL 系统。${NC}"
    fi
    
    echo -e "${CYAN}"
    echo "=========================================="
    echo -e "${NC}"
    read -p "按回车键返回主菜单..."
}

# 基础工具安装函数
basic_tools() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "              基础工具安装                "
    echo "=========================================="
    echo -e "${NC}"
    
    # 定义常用工具列表
    DEBIAN_TOOLS="htop vim tmux net-tools dnsutils lsof tree zip unzip"
    REDHAT_TOOLS="htop vim tmux net-tools bind-utils lsof tree zip unzip"
    
    # 检查系统类型
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu系统
        echo -e "${BL极}检测到 Debian/Ubuntu 系统${NC}"
        echo -e "${YELLOW}开始安装基础工具...${NC}"
        echo ""
        
        # 更新软件包列表
        echo -e "${BLUE}[步骤1/2] 更新软件包列表...${NC}"
        apt update -y
        echo ""
        
        # 安装工具
        echo -e "${BLUE}[步骤2/2] 安装基础工具...${NC}"
        apt install -y $DEBIAN_TOOLS
        echo ""
        
        echo -e "${GREEN}基础工具安装完成！${NC}"
        echo -e "${YELLOW}已安装工具: $DEBIAN_TOOLS${NC}"
        
    elif [ -f /etc/redhat-release ]; then
        # CentOS/RHEL系统
        echo -e "${BLUE}检测到 CentOS/RHEL 系统${NC}"
        echo -e "${YELLOW}开始安装基础工具...${NC}"
        echo ""
        
        # 安装工具
        echo -e "${BLUE}[步骤1/1] 安装基础工具...${NC}"
        yum install -y epel-release
        yum install -y $REDHAT_TOOLS
        echo ""
        
        echo -e "${GREEN}基础工具安装完成！${NC}"
        echo -e "${YELLOW}已安装工具: $REDHAT_TOOLS${NC}"
        
    else
        echo -e "${RED}不支持的系统类型！${NC}"
        echo -e "${YELLOW}仅支持 Debian/Ubuntu 和 CentOS/RHEL 系统。${NC}"
    fi
    
    echo -e "${CYAN}"
    echo "=========================================="
    echo -e "${NC}"
    read -p "按回车键返回主菜单..."
}

# -------------------------------
# BBR 测试函数
# -------------------------------
run_test() {
    local mode="$1"
    local result=""
    
    echo -e "${YELLOW}正在测试: $mode${NC}"
    
    # 设置拥塞控制算法
    case "$mode" in
        "BBR")
            sysctl -w net.ipv4.tcp_congestion_control=bbr
            ;;
        "BBR Plus")
            sysctl -w net.ipv4.tcp_congestion_control=bbr_plus
            ;;
        "BBRv2")
            sysctl -w net.ipv4.tcp_congestion_control=bbr2
            ;;
        "BBRv3")
            sysctl -w net.ipv4.tcp_congestion_control=bbr3
            ;;
        *)
            echo -e "${RED}未知模式: $mode${NC}"
            return
            ;;
    esac
    
    # 执行测速
    result=$(speedtest --simple --timeout 15 2>&1)
    
    if echo "$result" | grep -q "ERROR"; then
        echo -e "${RED}测试失败: $mode${NC}"
        echo "$mode: 测试失败" >> "$RESULT_FILE"
    else
        # 提取测速结果
        local ping=$(echo "$result" | grep "Ping" | awk '{print $2}')
        local download=$(echo "$result" | grep "Download" | awk '{print $2}')
        local upload=$(echo "$result" | grep "Upload" | awk '{print $2}')
        
        # 显示结果
        echo -e "  ${BLUE}延迟: ${GREEN}$ping ms${NC}"
        echo -e "  ${BLUE}下载: ${GREEN}$download Mbps${NC}"
        echo -e "  ${BLUE}上传: ${GREEN}$upload Mbps${NC}"
        
        # 保存结果
        echo "$mode: 延迟 ${ping}ms | 下载 ${download}Mbps | 上传 ${upload}Mbps" >> "$RESULT_FILE"
    fi
    
    echo ""
}

# -------------------------------
# BBR 综合测速
# -------------------------------
bbr_test_menu() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "              BBR 综合测速                "
    echo "=========================================="
    echo -e "${NC}"
    
    # 警告信息
    echo -e "${YELLOW}⚠️ 注意：此测试将临时修改网络配置${NC}"
    echo -e "${YELLOW}测试完成后将恢复原始设置${NC}"
    echo ""
    
    # 保存当前拥塞控制算法
    local current_cc=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    
    # 清空结果文件
    > "$RESULT_FILE"
    
    # 尝试所有算法
    for MODE in "BBR" "BBR Plus" "BBRv2" "BBRv3"; do
        run_test "$MODE"
    done
    
    # 恢复原始设置
    sysctl -w net.ipv4.tcp_congestion_control="$current_cc" >/dev/null 2>&1
    
    # 显示结果汇总
    echo -e "${CYAN}=== 测试完成，结果汇总 ===${NC}"
    if [ -f "$RESULT_FILE" ] && [ -s "$RESULT_FILE" ]; then
        cat "$RESULT_FILE"
    else
        echo -e "${YELLOW}无测速结果${NC}"
    fi
    
    echo -e "${CYAN}"
    echo "=========================================="
    echo -e "${NC}"
    read -p "按回车键返回BBR管理菜单..."
}

# -------------------------------
# 安装/切换 BBR 内核
# -------------------------------
run_bbr_switch() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "           BBR 内核安装/切换             "
    echo "=========================================="
    echo -e "${NC}"
    
    echo -e "${YELLOW}正在下载并运行 BBR 切换脚本...${NC}"
    echo -e "${YELLOW}来源: ylx2016/Linux-NetSpeed${NC}"
    echo ""
    
    # 下载脚本
    wget -O tcp.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcp.sh"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌❌ 下载脚本失败，请检查网络连接${NC}"
        read -p "按回车键返回BBR管理菜单..."
        return
    fi
    
    # 设置执行权限
    chmod +x tcp.sh
    
    # 运行脚本
    ./tcp.sh
    
    # 清理文件
    rm -f tcp.sh
    
    echo -e "${CYAN}"
    echo "=========================================="
    echo -e "${NC}"
    read -p "按回车键返回BBR管理菜单..."
}

# -------------------------------
# BBR 管理菜单
# -------------------------------
bbr_management() {
    while true; do
        clear
        echo -e "${CYAN}"
        echo "=========================================="
        echo "              BBR 管理菜单                "
        echo "=========================================="
        echo -e "${NC}"
        echo "1. BBR综合测速"
        echo "2. 安装/切换BBR内核"
        echo "3. 查看当前BBR状态"
        echo "0. 返回主菜单"
        echo "=========================================="
        
        read -p "请输入选项编号: " bbr_choice
        
        case $bbr_choice in
            1)
                bbr_test_menu
                ;;
            2)
                run_bbr_switch
                ;;
            3)
                clear
                echo -e "${CYAN}"
                echo "=========================================="
                echo "              当前BBR状态                "
                echo "=========================================="
                echo -e "${NC}"
                check_bbr
                echo ""
                read -p "按回车键返回BBR管理菜单..."
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效的选项，请重新输入！${NC}"
                sleep 1
                ;;
        esac
    done
}
