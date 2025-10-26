#!/bin/bash

# VPS一键管理脚本 v0.6 (修复了多处中文错别字和语法错误)
# 作者: 智能助手 (基于用户提供的代码修改)
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

# -------------------------------
# 显示菜单函数
# -------------------------------
show_menu() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "          VPS 脚本管理菜单 v0.6           "
    echo "=========================================="
    echo -e "${NC}"
    echo "1. 系统信息查询"
    echo "2. 系统更新"
    echo "3. 系统清理"
    echo "4. 基础工具"
    echo "5. BBR管理"
    echo "6. Docker管理"
    echo "7. 系统工具 (暂未实现)"
    echo "0. 退出脚本"
    echo "=========================================="
}

# -------------------------------
# 检查BBR状态函数
# -------------------------------
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

# -------------------------------
# 系统信息查询函数
# -------------------------------
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

# -------------------------------
# 系统更新函数
# -------------------------------
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
    read -p "按回车键返回主菜单..."
}

# -------------------------------
# 系统清理函数
# -------------------------------
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
        # 修正: echo -极 -> echo -e
        echo -e "${BLUE}[步骤1/4] 清理YUM缓存...${NC}"
        yum clean all
        echo ""
        
        # 清理旧内核
        echo -e "${BLUE}[步骤2/4] 清理旧内核...${NC}"
        # 注意：package-cleanup 在一些新系统上可能被 dnf 替代，这里沿用原代码
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

# -------------------------------
# 基础工具安装函数
# -------------------------------
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
        # 修正: echo -BL极 -> echo -e "${BLUE}
        echo -e "${BLUE}检测到 Debian/Ubuntu 系统${NC}"
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
# BBR 测试函数 (依赖 speedtest-cli)
# -------------------------------
run_test() {
    local mode="$1"
    local result=""
    
    # 检查 speedtest 命令是否存在
    if ! command -v speedtest >/dev/null 2>&1; then
        echo -e "${RED}❌❌ 错误：未安装 'speedtest-cli' 或 'speedtest' 命令。${NC}"
        echo -e "${YELLOW}请先安装 speedtest-cli (如：pip install speedtest-cli)。${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}正在测试: $mode${NC}"
    
    # 设置拥塞控制算法
    case "$mode" in
        "BBR")
            sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1
            ;;
        "BBR Plus")
            sysctl -w net.ipv4.tcp_congestion_control=bbr_plus >/dev/null 2>&1
            ;;
        "BBRv2")
            sysctl -w net.ipv4.tcp_congestion_control=bbr2 >/dev/null 2>&1
            ;;
        "BBRv3")
            sysctl -w net.ipv4.tcp_congestion_control=bbr3 >/dev/null 2>&1
            ;;
        *)
            echo -e "${RED}未知模式: $mode${NC}"
            return 1
            ;;
    esac
    
    # 检查设置是否成功，如果设置失败（例如内核不支持），则跳过
    local check_cc=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    if [[ "$check_cc" != *"$mode"* ]]; then
        echo -e "${RED}配置失败: $mode 算法可能未加载或不支持${NC}"
        echo "$mode: 配置失败/不支持" >> "$RESULT_FILE"
        return 1
    fi
    
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
# BBR 综合测速菜单
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
        echo -e "${YELLOW}无测速结果（请确保已安装 speedtest-cli）${NC}"
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
    echo "            BBR 内核安装/切换             "
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
                echo "              当前BBR状态                 "
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

# ====================================================================
# +++ Docker管理 +++
# ====================================================================

# -------------------------------
# 检查Docker环境状态
# -------------------------------
check_docker_status() {
    if command -v docker >/dev/null 2>&1; then
        if systemctl is-active docker >/dev/null 2>&1; then
            containers=$(docker ps -aq 2>/dev/null | wc -l)
            images=$(docker images -q 2>/dev/null | wc -l)
            networks=$(docker network ls -q 2>/dev/null | wc -l)
            volumes=$(docker volume ls -q 2>/dev/null | wc -l)
            echo "环境已经安装 容器:${containers} 镜像:${images} 网络:${networks} 卷:${volumes}"
        else
            echo "Docker已安装但服务未启动"
        fi
    else
        echo "Docker未安装"
    fi
}

# -------------------------------
# 安装/更新Docker环境
# -------------------------------
install_update_docker() {
    clear
    echo "正在安装/更新Docker环境..."
    
    # 检查系统类型并安装依赖
    if command -v apt >/dev/null 2>&1; then
        apt update
        apt install -y curl wget
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl wget
    fi
    
    # 使用官方脚本安装Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm -f get-docker.sh
    
    # 启动Docker服务
    systemctl start docker
    systemctl enable docker
    
    if systemctl is-active docker >/dev/null 2>&1; then
        echo -e "${GREEN}Docker安装成功！${NC}"
    else
        echo -e "${RED}Docker安装失败，请检查日志${NC}"
    fi
    read -p "按回车键继续..."
}

# -------------------------------
# 查看Docker全局状态
# -------------------------------
show_docker_status() {
    clear
    echo "=== Docker全局状态 ==="
    docker system df
    echo ""
    echo "=== 运行中的容器 ==="
    docker ps
    read -p "按回车键继续..."
}

# -------------------------------
# Docker卷管理菜单 (用户原脚本缺少，此处添加一个占位函数)
# -------------------------------
docker_volume_management() {
    while true; do
        clear
        echo "=== Docker 卷管理 ==="
        docker volume ls
        echo ""
        echo "1. 创建卷"
        echo "2. 删除卷"
        echo "3. 清理未使用的卷"
        echo "0. 返回上级菜单"
        echo ""
        read -p "请选择操作: " choice

        case $choice in
            1)
                read -p "请输入卷名称: " volume_name
                docker volume create "$volume_name"
                ;;
            2)
                read -p "请输入卷名称或ID: " volume_name
                docker volume rm "$volume_name"
                ;;
            3)
                docker volume prune -f
                ;;
            0)
                break
                ;;
            *)
                echo "无效选择，请重新输入"
                ;;
        esac
        
        echo ""
        read -p "按回车键继续..."
    done
}


# -------------------------------
# Docker容器管理子菜单
# -------------------------------
docker_container_management() {
    while true; do
        clear
        echo "=== Docker容器管理 ==="
        # 使用格式化输出，让显示更整洁
        docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}"
        echo ""
        echo "1. 启动容器"
        echo "2. 停止容器" 
        echo "3. 重启容器"
        echo "4. 查看容器日志"
        echo "5. 进入容器终端"
        echo "6. 删除容器"
        echo "7. 查看容器详情"
        echo "0. 返回上级菜单"
        echo ""
        read -p "请选择操作: " choice

        # 修正: case $choice 在 -> case $choice in
        case $choice in
            1)
                read -p "请输入容器名称或ID: " container
                docker start "$container"
                ;;
            2)
                read -p "请输入容器名称或ID: " container
                docker stop "$container"
                ;;
            3)
                read -p "请输入容器名称或ID: " container
                docker restart "$container"
                ;;
            4)
                read -p "请输入容器名称或ID: " container
                docker logs "$container"
                ;;
            5)
                read -p "请输入容器名称或ID: " container
                docker exec -it "$container" /bin/bash || docker exec -it "$container" /bin/sh
                ;;
            6)
                read -p "请输入容器名称或ID: " container
                docker rm "$container"
                ;;
            7)
                read -p "请输入容器名称或ID: " container
                docker inspect "$container"
                ;;
            0)
                break
                ;;
            *)
                echo "无效选择，请重新输入"
                ;;
        esac
        
        echo ""
        read -p "按回车键继续..."
    done
}

# -------------------------------
# Docker镜像管理子菜单
# -------------------------------
docker_image_management() {
    while true; do
        clear
        echo "=== Docker镜像管理 ==="
        docker images
        echo ""
        echo "1. 拉取镜像"
        echo "2. 删除镜像"
        echo "3. 查看镜像历史"
        echo "4. 导出镜像"
        echo "5. 导入镜像"
        # 修正: echo "极. 返回上级菜单" -> echo "0. 返回上级菜单"
        echo "0. 返回上级菜单"
        echo ""
        read -p "请选择操作: " choice

        case $choice in
            1)
                read -p "请输入镜像名称(如ubuntu:latest): " image
                docker pull "$image"
                ;;
            2)
                read -p "请输入镜像ID或名称: " image
                docker rmi "$image"
                ;;
            3)
                read -p "请输入镜像ID或名称: " image
                docker history "$image"
                ;;
            4)
                read -p "请输入镜像名称: " image
                read -p "请输入导出文件名(如image.tar): " filename
                # 修正: docker save -o "$filename" "$极mage" -> docker save -o "$filename" "$image"
                docker save -o "$filename" "$image"
                ;;
            5)
                read -p "请输入导入的文件名: " filename
                docker load -i "$filename"
                ;;
            0)
                break
                ;;
            *)
                echo "无效选择，请重新输入"
                ;;
        esac
        
        echo ""
        read -p "按回车键继续..."
    done
}

# -------------------------------
# Docker网络管理子菜单
# -------------------------------
docker_network_management() {
    while true; do
        clear
        echo "=== Docker网络管理 ==="
        docker network ls
        echo ""
        echo "1. 创建网络"
        echo "2. 删除网络"
        echo "3. 查看网络详情"
        echo "4. 连接容器到网络"
        echo "5. 从网络断开容器"
        echo "0. 返回上级菜单"
        echo ""
        read -p "请选择操作: " choice

        case $choice in
            1)
                read -p "请输入网络名称: " network
                read -p "请输入网络驱动(bridge/overlay等): " driver
                docker network create --driver "$driver" "$network"
                ;;
            2)
                read -p "请输入网络名称或ID: " network
                docker network rm "$network"
                ;;
            3)
                # 修正: read -p "请输入网络名称或ID: " network极 -> read -p "请输入网络名称或ID: " network
                read -p "请输入网络名称或ID: " network
                docker network inspect "$network"
                ;;
            4)
                read -p "请输入容器名称或ID: " container
                read -p "请输入网络名称或ID: " network
                docker network connect "$network" "$container"
                ;;
            5)
                # 修正: read -p "请输入容器名称或ID极 " container -> read -p "请输入容器名称或ID: " container
                read -p "请输入容器名称或ID: " container
                read -p "请输入网络名称或ID: " network
                docker network disconnect "$network" "$container"
                ;;
            0)
                break
                ;;
            *)
                echo "无效选择，请重新输入"
                ;;
        esac
        
        echo ""
        read -p "按回车键继续..."
    done
}


# -------------------------------
# 清理无用的Docker资源
# -------------------------------
clean_docker_resources() {
    clear
    echo "正在清理无用的Docker资源..."
    
    echo "1. 清理停止的容器、未使用的网络和构建缓存..."
    docker system prune -f
    
    echo "2. 清理所有未使用的镜像..."
    docker image prune -af
    
    echo "3. 清理未使用的卷..."
    docker volume prune -f
    
    echo -e "${GREEN}Docker资源清理完成！${NC}"
    read -p "按回车键继续..."
}

# -------------------------------
# 更换Docker镜像源
# -------------------------------
change_docker_registry() {
    clear
    echo "请选择Docker镜像源:"
    echo "1. Docker官方源(国外，恢复默认)"
    echo "2. 阿里云镜像源(国内推荐)"
    echo "3. 中科大镜像源"
    echo "4. 网易镜像源"
    echo "5. 腾讯云镜像源"
    read -p "请输入选择(1-5): " registry_choice

    local registry_url=""

    case $registry_choice in
        1)
            # Choice 1 will reset to the default mirror
            ;;
        2)
            registry_url="https://registry.cn-hangzhou.aliyuncs.com"
            ;;
        3)
            registry_url="https://docker.mirrors.ustc.edu.cn"
            ;;
        4)
            registry_url="http://hub-mirror.c.163.com"
            ;;
        5)
            registry_url="https://mirror.ccs.tencentyun.com"
            ;;
        *)
            echo "无效选择，操作已取消。"
            return
            ;;
    esac

    # 创建或修改daemon.json
    mkdir -p /etc/docker
    
    if [ -z "$registry_url" ]; then
        # If the URL is empty (Choice 1), restore the default configuration.
        echo '{}' > /etc/docker/daemon.json
        echo "已恢复默认镜像源"
    else
        # For other choices, set the new registry mirror.
        cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": ["$registry_url"]
}
EOF
        echo "已设置镜像源：$registry_url"
    fi

    # 重启Docker服务以应用更改
    echo "正在重启Docker服务..."
    systemctl restart docker
    echo -e "${GREEN}Docker服务已重启，镜像源设置完成${NC}"
    read -p "按回车键继续..."
}

# -------------------------------
# 编辑daemon.json文件
# -------------------------------
edit_daemon_json() {
    clear
    if [ ! -f /etc/docker/daemon.json ]; then
        mkdir -p /etc/docker
        echo "{}" > /etc/docker/daemon.json
    fi
    
    # 检查是否安装了vi或vim
    if ! command -v vi >/dev/null 2>&1 && ! command -v vim >/dev/null 2>&1; then
        echo -e "${RED}未安装 vi/vim 编辑器，请手动编辑 /etc/docker/daemon.json${NC}"
        return
    fi
    
    echo -e "${YELLOW}使用 vi 编辑器编辑 /etc/docker/daemon.json 文件...${NC}"
    # 使用vi编辑器编辑文件
    vi /etc/docker/daemon.json
    
    # 重启Docker服务使配置生效
    echo "正在重启Docker服务..."
    systemctl restart docker
    echo -e "${GREEN}daemon.json配置已更新，Docker服务已重启${NC}"
    read -p "按回车键继续..."
}

# -------------------------------
# 开启Docker IPv6访问
# -------------------------------
enable_docker_ipv6() {
    clear
    echo "正在启用Docker IPv6访问..."
    
    # 检查系统是否支持IPv6
    if [ ! -f /proc/net/if_inet6 ]; then
        echo -e "${RED}系统不支持IPv6，无法开启Docker IPv6访问。${NC}"
        read -p "按回车键继续..."
        return
    fi
    
    # 创建或修改daemon.json启用IPv6
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << EOF
{
  "ipv6": true,
  "fixed-cidr-v6": "fd00:db8:1::/64"
}
EOF

    echo "正在重启Docker服务..."
    systemctl restart docker
    echo -e "${GREEN}Docker IPv6访问已开启 (内网地址段: fd00:db8:1::/64)${NC}"
    read -p "按回车键继续..."
}

# -------------------------------
# 关闭Docker IPv6访问
# -------------------------------
disable_docker_ipv6() {
    clear
    echo "正在禁用Docker IPv6访问..."
    
    # 修改daemon.json禁用IPv6
    if [ -f /etc/docker/daemon.json ]; then
        # 使用jq工具移除IPv6配置
        if command -v jq >/dev/null 2>&1; then
            # 修正：del(.ip极6) -> del(.ipv6)
            jq 'del(.ipv6) | del(.["fixed-cidr-v6"])' /etc/docker/daemon.json > /tmp/daemon.json && mv /tmp/daemon.json /etc/docker/daemon.json
        else
            # 没有jq则使用sed（简单粗暴，不安全）
            echo -e "${YELLOW}警告：未安装 jq，使用 sed 移除配置。${NC}"
            sed -i '/"ipv6": true,/d' /etc/docker/daemon.json
            sed -i '/"fixed-cidr-v6":/d' /etc/docker/daemon.json
        fi
    fi

    echo "正在重启Docker服务..."
    systemctl restart docker
    echo -e "${GREEN}Docker IPv6访问已关闭${NC}"
    read -p "按回车键继续..."
}

# -------------------------------
# 备份/迁移/还原Docker环境
# -------------------------------
backup_restore_docker() {
    clear
    echo "=== Docker环境备份/迁移/还原 ==="
    echo "1. 备份所有容器为镜像"
    echo "2. 导出所有镜像"
    echo "3. 备份Docker数据卷"
    echo "4. 从备份恢复 (手动操作)"
    echo "0. 返回上级菜单"
    echo ""
    read -p "请选择操作: " choice

    case $choice in
        1)
            echo "正在备份所有容器为镜像..."
            for container in $(docker ps -aq); do
                name=$(docker inspect --format='{{.Name}}' $container | sed 's/^\///')
                docker commit "$container" "${name}-backup:latest"
            done
            echo -e "${GREEN}容器备份完成${NC}"
            ;;
        2)
            read -p "请输入导出目录(默认/tmp): " backup_dir
            backup_dir=${backup_dir:-/tmp}
            mkdir -p "$backup_dir"
            echo "正在导出所有镜像到 $backup_dir ..."
            for image in $(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>"); do
                filename=$(echo "$image" | tr '/:' '_').tar
                docker save -o "$backup_dir/$filename" "$image"
            done
            echo -e "${GREEN}镜像导出完成到 $backup_dir 目录${NC}"
            ;;
        3)
            read -p "请输入备份目录(默认/tmp): " backup_dir
            backup_dir=${backup_dir:-/tmp}
            mkdir -p "$backup_dir/docker-volumes"
            echo "正在备份Docker数据卷到 $backup_dir/docker-volumes ..."
            for volume in $(docker volume ls -q); do
                # 使用临时容器打包卷内容
                docker run --rm -v "$volume:/source:ro" -v "$backup_dir/docker-volumes:/backup" alpine tar czf "/backup/${volume}.tar.gz" -C /source .
            done
            echo -e "${GREEN}数据卷备份完成${NC}"
            ;;
        4)
            echo -e "${YELLOW}恢复功能需要手动操作，请参考Docker文档：${NC}"
            echo " - 导入镜像: docker load -i image.tar"
            echo " - 恢复卷: 将备份的.tar.gz解压到目标卷中"
            ;;
        0)
            return
            ;;
        *)
            echo "无效选择"
            ;;
    esac
    read -p "按回车键继续..."
}

# -------------------------------
# 卸载Docker环境
# -------------------------------
uninstall_docker() {
    clear
    echo -e "${RED}警告：此操作将彻底卸载Docker并删除所有数据！${NC}"
    read -p "确定要卸载Docker吗？(y/N): " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}卸载操作已取消${NC}"
        read -p "按回车键继续..."
        return
    fi

    echo "正在停止和删除所有容器..."
    # 停止所有容器
    docker stop $(docker ps -aq) 2>/dev/null
    # 删除所有容器
    docker rm $(docker ps -aq) 2>/dev/null
    # 删除所有镜像
    docker rmi $(docker images -q) 2>/dev/null
    # 删除所有卷
    docker volume rm $(docker volume ls -q) 2>/dev/null
    # 删除所有网络
    docker network rm $(docker network ls | grep -v "bridge\|host\|none" | awk 'NR>1 {print $1}') 2>/dev/null

    # 卸载Docker软件包
    if command -v apt >/dev/null 2>&1; then
        apt purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        apt autoremove -y
    elif command -v yum >/dev/null 2>&1; then
        yum remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi

    # 删除Docker数据目录
    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd
    rm -rf /etc/docker

    echo -e "${GREEN}Docker环境已彻底卸载${NC}"
    read -p "按回车键继续..."
}

# -------------------------------
# Docker管理主菜单
# -------------------------------
docker_management_menu() {
    while true; do
        clear
        echo -e "${CYAN}"
        echo "=========================================="
        echo "                Docker管理                "
        echo "=========================================="
        echo -e "${NC}"
        
        # 显示Docker环境状态
        check_docker_status
        
        echo ""
        echo "1. 安装/更新Docker环境"
        echo "2. 查看Docker全局状态"
        echo "3. Docker容器管理"
        echo "4. Docker镜像管理"
        echo "5. Docker网络管理"
        echo "6. Docker卷管理"
        echo "7. 清理无用的Docker资源"
        echo "8. 更换Docker源"
        echo "9. 编辑daemon.json文件"
        echo "10. 开启Docker-IPv6访问"
        echo "11. 关闭Docker-IPv6访问"
        echo "12. 备份/迁移/还原Docker环境"
        echo "13. 卸载Docker环境"
        echo "0. 返回主菜单"
        echo "=========================================="
        echo ""
        read -p "请输入你的选择: " choice

        case $choice in
            1) install_update_docker ;;
            2) show_docker_status ;;
            3) docker_container_management ;;
            4) docker_image_management ;;
            5) docker_network_management ;;
            # 修正: docker_volume_management 函数调用，使用上面定义的占位函数
            6) docker_volume_management ;;
            7) clean_docker_resources ;;
            8) change_docker_registry ;;
            9) edit_daemon_json ;;
            10) enable_docker_ipv6 ;;
            # 修正: disable_docker_ip极6 -> disable_docker_ipv6
            11) disable_docker_ipv6 ;;
            12) backup_restore_docker ;;
            13) uninstall_docker ;;
            0)
                echo "返回主菜单..."
                break
                ;;
            *)
                echo -e "${RED}无效选择，请重新输入${NC}"
                read -p "按回车键继续..."
                ;;
        esac
    done
}

# ====================================================================
# +++ 主执行逻辑 (Main Execution Logic) +++
# ====================================================================

# 脚本启动时，首先检查root权限和依赖
check_root
check_deps

# 无限循环，直到用户选择退出
while true; do
    show_menu
    read -p "请输入你的选择 (0-7): " main_choice

    case $main_choice in
        1)
            system_info
            ;;
        2)
            system_update
            ;;
        3)
            system_clean
            ;;
        4)
            basic_tools
            ;;
        5)
            bbr_management
            ;;
        6)
            docker_management_menu
            ;;
        7)
            # 这里可以添加脚本中未列出的“系统工具”的调用
            # system_tools 
            echo -e "${YELLOW}该功能尚未实现。${NC}"
            read -p "按回车键继续..."
            ;;
        0)
            echo -e "${GREEN}感谢使用，正在退出脚本...${NC}"
            break
            ;;
        *)
            echo -e "${RED}无效的选项，请重新输入！${NC}"
            sleep 1
            ;;
    esac
done
