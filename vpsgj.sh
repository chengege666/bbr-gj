#!/bin/bash



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
# 显示主菜单函数
# -------------------------------
show_menu() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "       CGG-VPS 脚本管理菜单 v3.3           "
    echo "=========================================="
    echo -e "${NC}"
    echo "1. 系统信息查询"
    echo "2. 系统更新"
    echo "3. 系统清理"
    echo "4. 基础工具"
    echo "5. BBR管理"
    echo "6. Docker管理"
    echo "7. 系统工具"
    echo "8. VPS测试IP网络"
    echo "0. 退出脚本"
    echo "=========================================="
}

# -------------------------------
# 系统信息查询函数
# -------------------------------
system_info() {
    clear; echo -e "${CYAN}"; echo "=========================================="; echo "              系统信息查询                "; echo "=========================================="; echo -e "${NC}"
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

# -------------------------------
# 系统更新函数
# -------------------------------
system_update() {
    clear; echo -e "${CYAN}"; echo "=========================================="; echo "              系统更新功能                "; echo "=========================================="; echo -e "${NC}"
    if [ -f /etc/debian_version ]; then
        echo -e "${BLUE}检测到 Debian/Ubuntu 系统${NC}"; echo -e "${YELLOW}开始更新系统...${NC}"; echo ""
        echo -e "${BLUE}[步骤1/3] 更新软件包列表...${NC}"; apt update; echo ""
        echo -e "${BLUE}[步骤2/3] 升级软件包...${NC}"; apt upgrade -y; echo ""
        echo -e "${BLUE}[步骤3/3] 清理系统...${NC}"; apt autoremove -y; apt autoclean; echo ""
        echo -e "${GREEN}系统更新完成！${NC}"
    elif [ -f /etc/redhat-release ]; then
        echo -e "${BLUE}检测到 CentOS/RHEL 系统${NC}"; echo -e "${YELLOW}开始更新系统...${NC}"; echo ""
        echo -e "${BLUE}[步骤1/2] 更新软件包...${NC}"; yum update -y; echo ""
        echo -e "${BLUE}[步骤2/2] 清理系统...${NC}"; yum clean all; yum autoremove -y; echo ""
        echo -e "${GREEN}系统更新完成！${NC}"
    else
        echo -e "${RED}不支持的系统类型！${NC}"; echo -e "${YELLOW}仅支持 Debian/Ubuntu 和 CentOS/RHEL 系统。${NC}"
    fi
    echo -e "${CYAN}"; echo "=========================================="; echo -e "${NC}"; read -p "按回车键返回主菜单..."
}

# -------------------------------
# 系统清理函数 (优化版)
# -------------------------------
system_clean() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "              系统清理功能        "
    echo "=========================================="
    echo -e "${NC}"
    
    echo -e "${YELLOW}⚠️ 警告：系统清理操作将删除不必要的文件，请谨慎操作！${NC}"
    echo ""
    read -p "是否继续执行系统清理？(y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then 
        echo -e "${YELLOW}已取消系统清理操作${NC}"
        read -p "按回车键返回主菜单..."
        return
    fi

    # 创建备份时间戳
    BACKUP_DIR="/tmp/system_clean_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    if [ -f /etc/debian_version ]; then
        echo -e "${BLUE}检测到 Debian/Ubuntu 系统${NC}"
        echo -e "${YELLOW}开始深度清理系统...${NC}"
        echo ""
        
        # 1. 清理包管理器缓存
        echo -e "${BLUE}[步骤1/8] 清理APT缓存和旧包...${NC}"
        apt clean
        apt autoclean
        apt autoremove --purge -y
        
        # 2. 清理旧内核 (更彻底的方法)
        echo -e "${BLUE}[步骤2/8] 清理旧内核...${NC}"
        current_kernel=$(uname -r | sed 's/-*[a-z]//g' | sed 's/-386//g')
        installed_kernels=$(dpkg -l | grep linux-image | awk '{print $2}')
        for kernel in $installed_kernels; do
            if [[ "$kernel" != *"$current_kernel"* ]]; then
                apt purge -y "$kernel" 2>/dev/null
            fi
        done
        
        # 3. 清理日志文件 (更彻底)
        echo -e "${BLUE}[步骤3/8] 清理日志文件...${NC}"
        journalctl --vacuum-time=7d 2>/dev/null  # 保留7天日志
        find /var/log -name "*.log" -type f -mtime +30 -delete 2>/dev/null
        find /var/log -name "*.gz" -type f -mtime +7 -delete 2>/dev/null
        find /var/log -name "*.old" -type f -mtime +7 -delete 2>/dev/null
        find /var/log -name "*.[0-9]" -type f -mtime +7 -delete 2>/dev/null
        truncate -s 0 /var/log/*.log 2>/dev/null
        
        # 4. 清理临时文件 (扩大范围)
        echo -e "${BLUE}[步骤4/8] 清理临时文件...${NC}"
        rm -rf /tmp/*
        rm -rf /var/tmp/*
        rm -rf /var/cache/apt/archives/*
        rm -rf /var/cache/debconf/*
        
        # 5. 清理缩略图缓存
        echo -e "${BLUE}[步骤5/8] 清理缩略图缓存...${NC}"
        find /home -type f -name ".thumbnails" -exec rm -rf {} + 2>/dev/null
        find /root -type f -name ".thumbnails" -exec rm -rf {} + 2>/dev/null
        
        # 6. 清理浏览器缓存 (如果存在)
        echo -e "${BLUE}[步骤6/8] 清理浏览器缓存...${NC}"
        find /home -type d -name ".cache" -exec rm -rf {}/* 2>/dev/null \;
        find /root -type d -name ".cache" -exec rm -rf {}/* 2>/dev/null \;
        
        # 7. 清理崩溃报告
        echo -e "${BLUE}[步骤7/8] 清理崩溃报告...${NC}"
        rm -rf /var/crash/*
        find /var/lib/apport/crash -type f -delete 2>/dev/null
        
        # 8. 清理软件包列表缓存
        echo -e "${BLUE}[步骤8/8] 清理软件包列表缓存...${NC}"
        rm -rf /var/lib/apt/lists/*
        apt update  # 重新生成干净的列表
        
    elif [ -f /etc/redhat-release ]; then
        echo -e "${BLUE}检测到 CentOS/RHEL 系统${NC}"
        echo -e "${YELLOW}开始深度清理系统...${NC}"
        echo ""

# -------------------------------
# 实用工具箱菜单
# -------------------------------
utility_toolbox_menu() {
    system_tools_menu
}
        
        # 1. 清理YUM/DNF缓存
        echo -e "${BLUE}[步骤1/8] 清理YUM/DNF缓存...${NC}"
        if command -v dnf >/dev/null 2>&1; then
            dnf clean all
            dnf autoremove -y
        else
            yum clean all
            package-cleanup --oldkernels --count=1 -y 2>/dev/null
            package-cleanup --leaves -y 2>/dev/null
        fi
        
        # 2. 清理旧内核
        echo -e "${BLUE}[步骤2/8] 清理旧内核...${NC}"
        if command -v dnf >/dev/null 2>&1; then
            dnf remove -y $(dnf repoquery --installonly --latest-limit=-1 -q) 2>/dev/null
        else
            package-cleanup --oldkernels --count=1 -y 2>/dev/null
        fi
        
        # 3. 清理日志文件
        echo -e "${BLUE}[步骤3/8] 清理日志文件...${NC}"
        journalctl --vacuum-time=7d 2>/dev/null
        find /var/log -name "*.log" -type f -mtime +30 -delete 2>/dev/null
        find /var/log -name "*.gz" -type f -mtime +7 -delete 2>/dev/null
        find /var/log -name "*.[0-9]" -type f -mtime +7 -delete 2>/dev/null
        truncate -s 0 /var/log/*.log 2>/dev/null
        
        # 4. 清理临时文件
        echo -e "${BLUE}[步骤4/8] 清理临时文件...${NC}"
        rm -rf /tmp/*
        rm -rf /var/tmp/*
        rm -rf /var/cache/yum/*
        rm -rf /var/cache/dnf/*
        
        # 5. 清理缩略图缓存
        echo -e "${BLUE}[步骤5/8] 清理缩略图缓存...${NC}"
        find /home -type f -name ".thumbnails" -exec rm -rf {} + 2>/dev/null
        find /root -type f -name ".thumbnails" -exec rm -rf {} + 2>/dev/null
        
        # 6. 清理浏览器缓存
        echo -e "${BLUE}[步骤6/8] 清理浏览器缓存...${NC}"
        find /home -type d -name ".cache" -exec rm -rf {}/* 2>/dev/null \;
        find /root -type d -name ".cache" -exec rm -rf {}/* 2>/dev/null \;
        
        # 7. 清理崩溃报告
        echo -e "${BLUE}[步骤7/8] 清理崩溃报告...${NC}"
        rm -rf /var/crash/*
        find /var/spool/abrt -type f -delete 2>/dev/null
        
        # 8. 清理系统缓存
        echo -e "${BLUE}[步骤8/8] 清理系统缓存...${NC}"
        sync
        echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
        
    else
        echo -e "${RED}不支持的系统类型！${NC}"
        echo -e "${YELLOW}仅支持 Debian/Ubuntu 和 CentOS/RHEL 系统。${NC}"
        read -p "按回车键返回主菜单..."
        return
    fi
    
    # 通用清理步骤 (所有系统)
    echo -e "${BLUE}[通用步骤] 执行通用清理...${NC}"
    
    # 清理垃圾文件
    find /tmp -name "*.tmp" -type f -delete 2>/dev/null
    find /tmp -name "*.swp" -type f -delete 2>/dev/null
    find /home -name "*.bak" -type f -mtime +30 -delete 2>/dev/null
    
    # 清理空目录
    find /tmp -type d -empty -delete 2>/dev/null
    find /var/tmp -type d -empty -delete 2>/dev/null
    
    # 显示清理结果
    echo ""
    echo -e "${GREEN}✅ 系统深度清理完成！${NC}"
    echo -e "${YELLOW}释放的磁盘空间：${NC}"
    df -h / | tail -1 | awk '{print "根分区可用空间: " $4}'
    
    # 清理备份目录
    rm -rf "$BACKUP_DIR"
    
    echo -e "${CYAN}"
    echo "=========================================="
    echo -e "${NC}"
    read -p "按回车键返回主菜单..."
}

# -------------------------------
# BBR 管理函数
# -------------------------------
bbr_management() {
    while true; do
        clear
        echo -e "${CYAN}"
        echo "=========================================="
        echo "                BBR 管理菜单              "
        echo "=========================================="
        echo -e "${NC}"
        echo "1. BBR 综合测速 (BBR, BBR Plus, BBRv2, BBRv3)"
        echo "2. 安装/切换 BBR 内核 (使用 ylx2016 脚本)"
        echo "3. 查看系统详细信息 (含BBR状态)"
        echo "4. speedtest-cli 测速依赖 (安装/卸载)"  # <<< 新增功能
        echo "0. 返回主菜单"
        echo "=========================================="
        
        read -p "请输入你的选择 (0-4): " bbr_choice

        case $bbr_choice in
            1)
                bbr_test_menu
                ;;
            2)
                run_bbr_switch
                ;;
            3)
                show_sys_info
                ;;
            4)
                manage_speedtest_cli  # <<< 调用新增的 speedtest-cli 管理函数
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效选项，请重新输入${NC}"; sleep 1
                ;;
        esac
    done
}

# -------------------------------
# 核心功能：BBR 测速
# -------------------------------
run_test() {
    MODE=$1
    echo -e "${CYAN}>>> 切换到 $MODE 并测速...${RESET}" 
    
    # 切换算法
    case $MODE in
        "BBR") 
            modprobe tcp_bbr >/dev/null 2>&1
            sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1
            sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1
            ;;
        "BBR Plus") 
            modprobe tcp_bbrplus >/dev/null 2>&1
            sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1
            sysctl -w net.ipv4.tcp_congestion_control=bbrplus >/dev/null 2>&1
            ;;
        "BBRv2") 
            modprobe tcp_bbrv2 >/dev/null 2>&1
            sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1
            sysctl -w net.ipv4.tcp_congestion_control=bbrv2 >/dev/null 2>&1
            ;;
        "BBRv3") 
            modprobe tcp_bbrv3 >/dev/null 2>&1
            sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1
            sysctl -w net.ipv4.tcp_congestion_control=bbrv3 >/dev/null 2>&1
            ;;
        *) # 增加一个默认情况以防意外输入，虽然测速模式通常是固定的
            echo -e "${YELLOW}未知 BBR 模式: $MODE${RESET}"
            ;;
    esac
    
    # 执行测速
    RAW=$(speedtest-cli --simple 2>/dev/null)
    if [ -z "$RAW" ]; then
        echo -e "${YELLOW}⚠️ speedtest-cli 失败，尝试替代方法...${RESET}" 
        RAW=$(curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python - --simple 2>/dev/null)
    fi

    if [ -z "$RAW" ]; then
        echo -e "${RED}$MODE 测速失败${RESET}" | tee -a "$RESULT_FILE" 
        echo ""
        return
    fi

    PING=$(echo "$RAW" | grep "Ping" | awk '{print $2}')
    DOWNLOAD=$(echo "$RAW" | grep "Download" | awk '{print $2}')
    UPLOAD=$(echo "$RAW" | grep "Upload" | awk '{print $2}')

    echo -e "${GREEN}$MODE | Ping: ${PING}ms | Down: ${DOWNLOAD} Mbps | Up: ${UPLOAD} Mbps${RESET}" | tee -a "$RESULT_FILE" 
    echo ""
}

# -------------------------------
# 功能 1: BBR 综合测速
# -------------------------------
bbr_test_menu() {
    echo -e "${CYAN}=== 开始 BBR 综合测速 ===${RESET}"
    > "$RESULT_FILE"
    
    # 无条件尝试所有算法
    for MODE in "BBR" "BBR Plus" "BBRv2" "BBRv3"; do
        run_test "$MODE"
    done
    
    echo -e "${CYAN}=== 测试完成，结果汇总 (${RESULT_FILE}) ===${RESET}"
    if [ -f "$RESULT_FILE" ] && [ -s "$RESULT_FILE" ]; then
        cat "$RESULT_FILE"
    else
        echo -e "${YELLOW}无测速结果${RESET}"
    fi
    echo ""
    read -n1 -p "按任意键返回菜单..."
}

# -------------------------------
# 功能 2: 安装/切换 BBR 内核 (修复调用)
# -------------------------------
run_bbr_switch() {
    echo -e "${CYAN}正在下载并运行 BBR 切换脚本... (来自 ylx2016/Linux-NetSpeed)${RESET}"
    wget -O tcp.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌❌❌❌ 下载或运行脚本失败，请检查网络连接${RESET}"
    fi
    read -n1 -p "按任意键返回菜单..."
}

# -------------------------------
# 功能 3: 系统信息 (增强版，包含BBR类型和GLIBC版本) (修复调用)
# -------------------------------
show_sys_info() {
    echo -e "${CYAN}=== 系统详细信息 ===${RESET}"
    
    # BBR信息
    CURRENT_BBR=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    CURRENT_QDISC=$(sysctl net.core.default_qdisc 2>/dev/null | awk '{print $3}')
    echo -e "${GREEN}当前拥塞控制算法:${RESET} $CURRENT_BBR"
    echo -e "${GREEN}当前队列规则:${RESET} $CURRENT_QDISC"
    
    echo ""
    read -n1 -p "按任意键返回菜单..."
}

# -------------------------------
# speedtest-cli 管理函数 (新增)
# -------------------------------
manage_speedtest_cli() {
    clear
    echo -e "${CYAN}=========================================="
    echo "           speedtest-cli 管理             "
    echo "=========================================="
    echo -e "${NC}"
    
    # 检查当前状态
    if command -v speedtest-cli >/dev/null 2>&1; then
        STATUS="${GREEN}✅ 已安装 ${YELLOW}$(speedtest-cli --version 2>/dev/null | head -n 1)${NC}"
    else
        STATUS="${RED}❌ 未安装${NC}"
    fi
    echo -e "${BLUE}当前状态: $STATUS${NC}"
    
    echo "请选择操作："
    echo "1. 安装/更新 speedtest-cli"
    echo "2. 卸载 speedtest-cli"
    echo "0. 返回上级菜单"
    read -p "请输入选项编号: " choice

    case $choice in
        1) # 安装/更新
            echo -e "${YELLOW}正在尝试安装 speedtest-cli...${NC}"
            if [ -f /etc/debian_version ]; then
                apt update -y
                apt install -y speedtest-cli
            elif [ -f /etc/redhat-release ]; then
                # RHEL/CentOS 需要 EPEL 源
                yum install -y epel-release; yum install -y speedtest-cli
            elif command -v dnf >/dev/null 2>&1; then
                dnf install -y speedtest-cli
            else
                echo -e "${RED}不支持的系统或找不到包管理器，请手动安装。${NC}"
            fi
            
            if command -v speedtest-cli >/dev/null 2>&1; then
                echo -e "${GREEN}✅ speedtest-cli 安装/更新成功！${NC}"
            else
                echo -e "${RED}❌ speedtest-cli 安装失败，请检查系统源。${NC}"
            fi
            ;;
        2) # 卸载
            echo -e "${YELLOW}正在尝试卸载 speedtest-cli...${NC}"
            if [ -f /etc/debian_version ]; then
                apt purge -y speedtest-cli; apt autoremove -y
            elif [ -f /etc/redhat-release ]; then
                yum remove -y speedtest-cli
            elif command -v dnf >/dev/null 2>&1; then
                dnf remove -y speedtest-cli
            else
                echo -e "${RED}不支持的系统或找不到包管理器，请手动卸载。${NC}"
            fi

            if ! command -v speedtest-cli >/dev/null 2>&1; then
                echo -e "${GREEN}✅ speedtest-cli 卸载成功！${NC}"
            else
                echo -e "${RED}❌ speedtest-cli 卸载失败，请检查系统日志。${NC}"
            fi
            ;;
        0)
            echo -e "${YELLOW}返回上级菜单...${NC}"
            return
            ;;
        *)
            echo -e "${RED}无效选项，请重新输入${NC}"
            ;;
    esac
    read -n1 -p "按任意键返回菜单..."
}

# Docker 相关函数 (修复版)
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

install_update_docker() {
    clear
    echo "正在安装/更新Docker环境..."
    if command -v apt >/dev/null 2>&1; then
        apt update -y
        apt install -y curl wget
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl wget
    fi
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm -f get-docker.sh
    systemctl start docker
    systemctl enable docker
    if systemctl is-active docker >/dev/null 2>&1; then
        echo -e "${GREEN}Docker安装成功！${NC}"
    else
        echo -e "${RED}Docker安装失败，请检查日志${NC}"
    fi
    read -p "按回车键继续..."
}

show_docker_status() {
    clear
    echo "=== Docker全局状态 ==="
    docker system df
    echo ""
    echo "=== 运行中的容器 ==="
    docker ps
    read -p "按回车键继续..."
}

docker_volume_management() {
    while true; do
        clear
        echo "=== Docker 卷管理 ==="
        docker volume ls
        echo ""
        echo "1. 创建卷"; echo "2. 删除卷"; echo "3. 清理未使用的卷"; echo "0. 返回上级菜单"; echo ""
        read -p "请选择操作: " choice
        case $choice in
            1) read -p "请输入卷名称: " volume_name; docker volume create "$volume_name" ;;
            2) read -p "请输入卷名称或ID: " volume_name; docker volume rm "$volume_name" ;;
            3) docker volume prune -f ;;
            0) break ;;
            *) echo "无效选择，请重新输入" ;;
        esac
        echo ""; read -p "按回车键继续..."
    done
}

docker_container_management() {
    while true; do
        clear
        echo "=== Docker容器管理 ==="
        docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}"
        echo ""
        echo "1. 启动容器"; echo "2. 停止容器"; echo "3. 重启容器"; echo "4. 查看容器日志"; echo "5. 进入容器终端"; echo "6. 删除容器"; echo "7. 查看容器详情"; echo "0. 返回上级菜单"; echo ""
        read -p "请选择操作: " choice
        case $choice in
            1) read -p "请输入容器名称或ID: " container; docker start "$container" ;;
            2) read -p "请输入容器名称或ID: " container; docker stop "$container" ;;
            3) read -p "请输入容器名称或ID: " container; docker restart "$container" ;;
            4) read -p "请输入容器名称或ID: " container; docker logs "$container" ;;
            5) read -p "请输入容器名称或ID: " container; docker exec -it "$container" /bin/bash || docker exec -it "$container" /bin/sh ;;
            6) read -p "请输入容器名称或ID: " container; docker rm "$container" ;;
            7) read -p "请输入容器名称或ID: " container; docker inspect "$container" ;;
            0) break ;;
            *) echo "无效选择，请重新输入" ;;
        esac
        echo ""; read -p "按回车键继续..."
    done
}

docker_image_management() {
    while true; do
        clear
        echo "=== Docker镜像管理 ==="
        docker images
        echo ""
        echo "1. 拉取镜像"; echo "2. 删除镜像"; echo "3. 查看镜像历史"; echo "4. 导出镜像"; echo "5. 导入镜像"; echo "0. 返回上级菜单"; echo ""
        read -p "请选择操作: " choice
        case $choice in
            1) read -p "请输入镜像名称(如ubuntu:latest): " image; docker pull "$image" ;;
            2) read -p "请输入镜像ID或名称: " image; docker rmi "$image" ;;
            3) read -p "请输入镜像ID或名称: " image; docker history "$image" ;;
            4) read -p "请输入镜像名称: " image; read -p "请输入导出文件名(如image.tar): " filename; docker save -o "$filename" "$image" ;;
            5) read -p "请输入导入的文件名: " filename; docker load -i "$filename" ;;
            0) break ;;
            *) echo "无效选择，请重新输入" ;;
        esac
        echo ""; read -p "按回车键继续..."
    done
}

docker_network_management() {
    while true; do
        clear
        echo "=== Docker网络管理 ==="
        docker network ls
        echo ""
        echo "1. 创建网络"; echo "2. 删除网络"; echo "3. 查看网络详情"; echo "4. 连接容器到网络"; echo "5. 从网络断开容器"; echo "0. 返回上级菜单"; echo ""
        read -p "请选择操作: " choice
        case $choice in
            1) read -p "请输入网络名称: " network; read -p "请输入网络驱动(bridge/overlay等): " driver; docker network create --driver "$driver" "$network" ;;
            2) read -p "请输入网络名称或ID: " network; docker network rm "$network" ;;
            3) read -p "请输入网络名称或ID: " network; docker network inspect "$network" ;;
            4) read -p "请输入容器名称或ID: " container; read -p "请输入网络名称或ID: " network; docker network connect "$network" "$container" ;;
            5) read -p "请输入容器名称或ID: " container; read -p "请输入网络名称或ID: " network; docker network disconnect "$network" "$container" ;;
            0) break ;;
            *) echo "无效选择，请重新输入" ;;
        esac
        echo ""; read -p "按回车键继续..."
    done
}

clean_docker_resources() {
    clear
    echo "正在清理无用的Docker资源..."
    echo "1. 清理停止的容器、未使用的网络和构建缓存..."; docker system prune -f
    echo "2. 清理所有未使用的镜像..."; docker image prune -af
    echo "3. 清理未使用的卷..."; docker volume prune -f
    echo -e "${GREEN}Docker资源清理完成！${NC}"
    read -p "按回车键继续..."
}

change_docker_registry() {
    clear
    echo "请选择Docker镜像源:"
    echo "1. Docker官方源(国外，恢复默认)"; echo "2. 阿里云镜像源(国内推荐)"; echo "3. 中科大镜像源"; echo "4. 网易镜像源"; echo "5. 腾讯云镜像源"
    read -p "请输入选择(1-5): " registry_choice
    local registry_url=""
    case $registry_choice in
        1) ;;
        2) registry_url="https://registry.cn-hangzhou.aliyuncs.com" ;;
        3) registry_url="https://docker.mirrors.ustc.edu.cn" ;;
        4) registry_url="http://hub-mirror.c.163.com" ;;
        5) registry_url="https://mirror.ccs.tencentyun.com" ;;
        *) echo "无效选择，操作已取消。"; return ;;
    esac
    mkdir -p /etc/docker
    if [ -z "$registry_url" ]; then
        echo '{}' > /etc/docker/daemon.json
        echo "已恢复默认镜像源"
    else
        cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": ["$registry_url"]
}
EOF
        echo "已设置镜像源：$registry_url"
    fi
    echo "正在重启Docker服务..."
    systemctl restart docker
    echo -e "${GREEN}Docker服务已重启，镜像源设置完成${NC}"
    read -p "按回车键继续..."
}

edit_daemon_json() {
    clear
    if [ ! -f /etc/docker/daemon.json ]; then
        mkdir -p /etc/docker; echo "{}" > /etc/docker/daemon.json
    fi
    if ! command -v vi >/dev/null 2>&1 && ! command -v vim >/dev/null 2>&1; then
        echo -e "${RED}未安装 vi/vim 编辑器，请手动编辑 /etc/docker/daemon.json${NC}"; return
    fi
    echo -e "${YELLOW}使用 vi 编辑器编辑 /etc/docker/daemon.json 文件...${NC}"
    vi /etc/docker/daemon.json
    echo "正在重启Docker服务..."
    systemctl restart docker
    echo -e "${GREEN}daemon.json配置已更新，Docker服务已重启${NC}"
    read -p "按回车键继续..."
}

enable_docker_ipv6() {
    clear
    echo "正在启用Docker IPv6访问..."
    if [ ! -f /proc/net/if_inet6 ]; then
        echo -e "${RED}系统不支持IPv6，无法开启Docker IPv6访问。${NC}"; read -p "按回车键继续..."; return
    fi
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

disable_docker_ipv6() {
    clear
    echo "正在禁用Docker IPv6访问..."
    if [ -f /etc/docker/daemon.json ]; then
        if command -v jq >/dev/null 2>&1; then
            jq 'del(.ipv6) | del(.["fixed-cidr-v6"])' /etc/docker/daemon.json > /tmp/daemon.json && mv /tmp/daemon.json /etc/docker/daemon.json
        else
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

backup_restore_docker() {
    clear
    echo "=== Docker环境备份/迁移/还原 ==="
    echo "1. 备份所有容器为镜像"; echo "2. 导出所有镜像"; echo "3. 备份Docker数据卷"; echo "4. 从备份恢复 (手动操作)"; echo "0. 返回上级菜单"; echo ""
    read -p "请选择操作: " choice
    case $choice in
        1)
            echo "正在备份所有容器为镜像..."
            for container in $(docker ps -aq); do name=$(docker inspect --format='{{.Name}}' $container | sed 's/^\///'); docker commit "$container" "${name}-backup:latest"; done
            echo -e "${GREEN}容器备份完成${NC}"
            ;;
        2)
            read -p "请输入导出目录(默认/tmp): " backup_dir; backup_dir=${backup_dir:-/tmp}; mkdir -p "$backup_dir"
            echo "正在导出所有镜像到 $backup_dir ..."
            for image in $(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>"); do filename=$(echo "$image" | tr '/:' '_').tar; docker save -o "$backup_dir/$filename" "$image"; done
            echo -e "${GREEN}镜像导出完成到 $backup_dir 目录${NC}"
            ;;
        3)
            read -p "请输入备份目录(默认/tmp): " backup_dir; backup_dir=${backup_dir:-/tmp}; mkdir -p "$backup_dir/docker-volumes"
            echo "正在备份Docker数据卷到 $backup_dir/docker-volumes ..."
            for volume in $(docker volume ls -q); do docker run --rm -v "$volume:/source:ro" -v "$backup_dir/docker-volumes:/backup" alpine tar czf "/backup/${volume}.tar.gz" -C /source .; done
            echo -e "${GREEN}数据卷备份完成${NC}"
            ;;
        4) echo -e "${YELLOW}恢复功能需要手动操作，请参考Docker文档：${NC}"; echo " - 导入镜像: docker load -i image.tar"; echo " - 恢复卷: 将备份的.tar.gz解压到目标卷中" ;;
        0) return ;;
        *) echo "无效选择" ;;
    esac
    read -p "按回车键继续..."
}

uninstall_docker() {
    clear
    echo -e "${RED}警告：此操作将彻底卸载Docker并删除所有数据！${NC}"
    read -p "确定要卸载Docker吗？(y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then echo -e "${YELLOW}卸载操作已取消${NC}"; read -p "按回车键继续..."; return; fi
    echo "正在停止和删除所有容器..."; docker stop $(docker ps -aq) 2>/dev/null; docker rm $(docker ps -aq) 2>/dev/null
    echo "正在删除所有镜像和卷..."; docker rmi $(docker images -q) 2>/dev/null; docker volume rm $(docker volume ls -q) 2>/dev/null
    echo "正在删除所有网络..."; docker network rm $(docker network ls | grep -v "bridge\|host\|none" | awk 'NR>1 {print $1}') 2>/dev/null
    if command -v apt >/dev/null 2>&1; then
        apt purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; apt autoremove -y
    elif command -v yum >/dev/null 2>&1; then
        yum remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi
    rm -rf /var/lib/docker; rm -rf /var/lib/containerd; rm -rf /etc/docker
    echo -e "${GREEN}Docker环境已彻底卸载${NC}"
    read -p "按回车键继续..."
}

docker_management_menu() {
    while true; do
        clear
        echo -e "${CYAN}"; echo "=========================================="; echo "                Docker管理                "; echo "=========================================="; echo -e "${NC}"
        check_docker_status
        echo ""; echo "1. 安装/更新Docker环境"; echo "2. 查看Docker全局状态"; echo "3. Docker容器管理"; echo "4. Docker镜像管理"; echo "5. Docker网络管理"; echo "6. Docker卷管理"; echo "7. 清理无用的Docker资源"; echo "8. 更换Docker源"; echo "9. 编辑daemon.json文件"; echo "10. 开启Docker-IPv6访问"; echo "11. 关闭Docker-IPv6访问"; echo "12. 备份/迁移/还原Docker环境"; echo "13. 卸载Docker环境"; echo "0. 返回主菜单"; echo "=========================================="; echo ""
        read -p "请输入你的选择: " choice
        case $choice in
            1) install_update_docker ;; 2) show_docker_status ;; 3) docker_container_management ;; 4) docker_image_management ;; 5) docker_network_management ;; 6) docker_volume_management ;; 7) clean_docker_resources ;; 8) change_docker_registry ;; 9) edit_daemon_json ;; 10) enable_docker_ipv6 ;; 11) disable_docker_ipv6 ;; 12) backup_restore_docker ;; 13) uninstall_docker ;;
            0) echo "返回主菜单..."; break ;;
            *) echo -e "${RED}无效选择，请重新输入${NC}"; read -p "按回车键继续..." ;;
        esac
    done
}

# ====================================================================
# +++ 系统工具功能实现 +++
# ====================================================================

# -------------------------------
# 1. 高级防火墙管理 (占位菜单 - 保持不变)
# -------------------------------
advanced_firewall_menu() {
    while true; do
        clear
        echo -e "${CYAN}"
        echo "=========================================="
        echo "              高级防火墙管理              "
        echo "=========================================="
        if command -v iptables &>/dev/null; then
            echo -e "${BLUE}当前防火墙 (iptables/nftables) 状态:${NC}"
            iptables -L INPUT -n --line-numbers 2>/dev/null | head -n 5
        fi
        echo "------------------------------------------"
        echo -e "${NC}"
        echo "1. 开放指定端口        2. 关闭指定端口"
        echo "3. 开放所有端口        4. 关闭所有端口"
        echo "------------------------------------------"
        echo "5. IP白名单            6. IP黑名单"
        echo "7. 清除指定IP          8. 启动/停止防火墙 (占位)"
        echo "------------------------------------------"
        echo "11. 允许PING           12. 禁止PING"
        echo "13. 启动DDOS防御       14. 关闭DDOS防御"
        echo "------------------------------------------"
        echo "15. 阻止指定国家IP       16. 仅允许指定国家IP"
        echo "17. 解除指定国家IP限制   18. 查看当前规则 (占位)"
        echo "------------------------------------------"
        echo "0. 返回上级选单"
        echo "=========================================="

        read -p "请输入你的选择: " fw_choice

        case $fw_choice in
            1|2|3|4) echo -e "${YELLOW}功能占位：端口操作。请填充您的 Firewalld/UFW/Iptables 端口操作命令。${NC}" ;;
            5|6|7) echo -e "${YELLOW}功能占位：IP黑白名单。请填充您的 Firewalld/UFW/Iptables IP 白名单/黑名单命令。${NC}" ;;
            8) echo -e "${YELLOW}功能占位：启停防火墙。请填充您的 systemctl stop/start firewalld 或 ufw disable/enable 命令。${NC}" ;;
            11|12) echo -e "${YELLOW}功能占位：PING控制。请填充您的 Firewalld/Iptables 针对 ICMP 协议的操作命令。${NC}" ;;
            13|14) echo -e "${YELLOW}功能占位：DDOS防御。请填充您的 DDOS 防御（如：配置限速、安装工具）的启动/关闭命令。${NC}" ;;
            15|16|17) echo -e "${YELLOW}功能占位：国家IP限制。请填充您的 IP 库查询和基于 iptables/ipset 的国家 IP 限制命令。${NC}" ;;
            18) echo -e "${YELLOW}功能占位：查看规则。请填充您的 iptables -L -n 或 firewall-cmd --list-all 命令。${NC}" ;;
            0) return ;;
            *) echo -e "${RED}无效的选项，请重新输入！${NC}"; sleep 1 ;;
        esac
        
        if [ "$fw_choice" != "0" ]; then
            read -p "按回车键继续..."
        fi
    done
}

# -------------------------------
# 2. 修改登录密码
# -------------------------------
change_login_password() {
    clear
    echo -e "${CYAN}=========================================="
    echo "              修改登录密码                "
    echo "=========================================="
    echo -e "${NC}"
    echo -e "${YELLOW}⚠️ 注意：此操作将修改当前用户的密码。${NC}"
    
    # 始终修改当前执行脚本的用户的密码，即 root
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}错误：请使用 root 权限运行本脚本。${NC}"
        read -p "按回车键继续..."
        return
    fi
    
    # 使用 passwd 命令修改密码
    passwd root
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 密码修改成功！${NC}"
    else
        echo -e "${RED}❌ 密码修改失败，请检查输入或系统日志。${NC}"
    fi
    
    read -p "按回车键继续..."
}

# -------------------------------
# 3. 修改 SSH 连接端口
# -------------------------------
change_ssh_port() {
    clear
    echo -e "${CYAN}=========================================="
    echo "            修改 SSH 连接端口             "
    echo "=========================================="
    echo -e "${NC}"
    
    current_port=$(grep -E '^Port\s' /etc/ssh/sshd_config | awk '{print $2}' | head -1)
    if [ -z "$current_port" ]; then
        current_port=22
    fi
    echo -e "${BLUE}当前 SSH 端口: ${YELLOW}$current_port${NC}"
    
    read -p "请输入新的 SSH 端口号 (1024-65535, 留空取消): " new_port
    
    if [ -z "$new_port" ]; then
        echo -e "${YELLOW}操作已取消。${NC}"
        read -p "按回车键继续..."
        return
    fi

    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1024 ] || [ "$new_port" -gt 65535 ]; then
        echo -e "${RED}无效的端口号！端口必须是 1024 到 65535 之间的数字。${NC}"
        read -p "按回车键继续..."
        return
    fi
    
    if [ "$new_port" -eq "$current_port" ]; then
        echo -e "${YELLOW}新端口与当前端口相同，无需修改。${NC}"
        read -p "按回车键继续..."
        return
    fi
    
    echo -e "${YELLOW}正在备份 /etc/ssh/sshd_config 到 /etc/ssh/sshd_config.bak...${NC}"
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    
    echo -e "${YELLOW}正在修改 SSH 配置文件...${NC}"
    # 确保注释掉所有 Port 行，并添加新的 Port
    sed -i "/^Port\s/d" /etc/ssh/sshd_config
    echo "Port $new_port" >> /etc/ssh/sshd_config
    
    # 尝试更新防火墙规则
    echo -e "${YELLOW}正在尝试更新防火墙规则 (开放新端口)...${NC}"
    if command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --zone=public --add-port=$new_port/tcp --permanent >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
        echo -e "${GREEN}✅ Firewalld 已开放新端口 $new_port/tcp${NC}"
    elif command -v ufw >/dev/null 2>&1; then
        ufw allow $new_port/tcp >/dev/null 2>&1
        echo -e "${GREEN}✅ UFW 已开放新端口 $new_port/tcp${NC}"
    elif command -v iptables >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️ 发现 Iptables，请手动添加持久化规则，本脚本不自动添加。${NC}"
    else
        echo -e "${YELLOW}⚠️ 未发现 Firewalld 或 UFW，请手动配置防火墙开放新端口 $new_port。${NC}"
    fi

    # 尝试重启 SSH 服务
    echo -e "${YELLOW}正在重启 SSH 服务...${NC}"
    if systemctl restart sshd; then
        echo -e "${GREEN}✅ SSH 端口修改完成！请使用新端口 ${new_port} 重新连接。${NC}"
        echo -e "${RED}!!! 警告：请立即打开一个新的终端窗口，并测试新端口是否能够连接。如果连接失败，请通过 VNC/控制台恢复 /etc/ssh/sshd_config.bak 文件。 !!!${NC}"
    else
        echo -e "${RED}❌ SSH 服务重启失败！请检查日志。已回滚配置文件...${NC}"
        mv /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
        systemctl restart sshd # 尝试恢复后再次重启
    fi

    read -p "按回车键继续..."
}

# -------------------------------
# 4. 切换优先 IPV4/IPV6 (增强版，添加IPv6开关功能)
# -------------------------------
toggle_ipv_priority() {
    while true; do
        clear
        echo -e "${CYAN}=========================================="
        echo "            IPv4/IPv6 协议管理           "
        echo "=========================================="
        echo -e "${NC}"
        
        # 检查当前IPv6状态
        IPV6_STATUS=$(sysctl net.ipv6.conf.all.disable_ipv6 2>/dev/null | awk '{print $3}')
        if [ "$IPV6_STATUS" = "1" ]; then
            IPV6_STATUS_TEXT="${RED}已禁用${NC}"
        else
            IPV6_STATUS_TEXT="${GREEN}已启用${NC}"
        fi
        
        # 检查当前优先级设置
        GAI_CONF="/etc/gai.conf"
        if grep -q "^precedence ::ffff:0:0/96" "$GAI_CONF" 2>/dev/null; then
            PRIORITY_STATUS="${GREEN}IPv4优先${NC}"
        else
            PRIORITY_STATUS="${BLUE}IPv6优先${NC}"
        fi
        
        echo -e "${BLUE}当前IPv6状态: ${IPV6_STATUS_TEXT}${NC}"
        echo -e "${BLUE}当前连接优先级: ${PRIORITY_STATUS}${NC}"
        echo ""
        echo "请选择操作："
        echo "1. 优先使用 IPv4 (修改gai.conf)"
        echo "2. 优先使用 IPv6 (恢复默认)"
        echo "3. 完全禁用 IPv6"
        echo "4. 启用 IPv6"
        echo "5. 查看当前网络配置"
        echo "0. 返回上级菜单"
        echo "=========================================="
        
        read -p "请输入选项编号: " choice
        
        case $choice in
            1)
                # 优先 IPv4
                echo -e "${YELLOW}正在配置优先使用 IPv4...${NC}"
                [ -f "$GAI_CONF" ] && cp "$GAI_CONF" "$GAI_CONF.bak"
                sed -i '/^#\s*precedence/!s/^\s*precedence/# precedence/g' "$GAI_CONF" 2>/dev/null
                touch "$GAI_CONF"
                sed -i '/^precedence\s*::ffff:0:0\/96/d' "$GAI_CONF"
                echo "precedence ::ffff:0:0/96  100" >> "$GAI_CONF"
                echo -e "${GREEN}✅ 配置完成。系统将优先使用 IPv4。${NC}"
                ;;
            2)
                # 优先 IPv6 (恢复默认)
                echo -e "${YELLOW}正在配置优先使用 IPv6 (恢复默认)...${NC}"
                [ -f "$GAI_CONF" ] && cp "$GAI_CONF" "$GAI_CONF.bak"
                sed -i '/^#\s*precedence/!s/^\s*precedence/# precedence/g' "$GAI_CONF" 2>/dev/null
                touch "$GAI_CONF"
                sed -i '/^precedence\s*::ffff:0:0\/96/d' "$GAI_CONF"
                echo -e "${GREEN}✅ 配置完成。系统将按默认配置优先解析 IPv6。${NC}"
                ;;
            3)
                # 禁用 IPv6
                echo -e "${YELLOW}正在禁用 IPv6...${NC}"
                echo -e "${RED}⚠️ 警告：禁用IPv6可能会影响网络连接，请谨慎操作！${NC}"
                read -p "确定要禁用IPv6吗？(y/N): " confirm
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    # 临时禁用
                    sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
                    sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1
                    
                    # 永久禁用（写入sysctl.conf）
                    if grep -q "net.ipv6.conf.all.disable_ipv6" /etc/sysctl.conf 2>/dev/null; then
                        sed -i 's/^.*net.ipv6.conf.all.disable_ipv6.*$/net.ipv6.conf.all.disable_ipv6 = 1/' /etc/sysctl.conf
                    else
                        echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
                    fi
                    
                    if grep -q "net.ipv6.conf.default.disable_ipv6" /etc/sysctl.conf 2>/dev/null; then
                        sed -i 's/^.*net.ipv6.conf.default.disable_ipv6.*$/net.ipv6.conf.default.disable_ipv6 = 1/' /etc/sysctl.conf
                    else
                        echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
                    fi
                    
                    echo -e "${GREEN}✅ IPv6 已禁用。部分设置需要重启生效。${NC}"
                else
                    echo -e "${YELLOW}操作已取消。${NC}"
                fi
                ;;
            4)
                # 启用 IPv6
                echo -e "${YELLOW}正在启用 IPv6...${NC}"
                # 临时启用
                sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null 2>&1
                sysctl -w net.ipv6.conf.default.disable_ipv6=0 >/dev/null 2>&1
                
                # 从sysctl.conf中移除禁用设置
                sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf 2>/dev/null
                sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf 2>/dev/null
                
                echo -e "${GREEN}✅ IPv6 已启用。${NC}"
                ;;
            5)
                # 查看当前网络配置
                echo -e "${CYAN}=== 当前网络配置信息 ===${NC}"
                echo -e "${BLUE}IPv6 状态:${NC}"
                sysctl net.ipv6.conf.all.disable_ipv6 2>/dev/null || echo "无法获取IPv6状态"
                echo ""
                echo -e "${BLUE}IP地址信息:${NC}"
                ip addr show | grep -E "inet6? " | grep -v "127.0.0.1" | head -10
                echo ""
                echo -e "${BLUE}路由信息:${NC}"
                ip route | head -5
                echo ""
                echo -e "${BLUE}DNS配置:${NC}"
                cat /etc/resolv.conf 2>/dev/null | grep -v "^#" | head -5
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效的选项。${NC}"
                ;;
        esac
        
        if [ "$choice" != "0" ]; then
            echo ""
            read -p "按回车键继续..."
        fi
    done
}

# -------------------------------
# 5. 修改主机名
# -------------------------------
change_hostname() {
    clear
    echo -e "${CYAN}=========================================="
    echo "                修改主机名                "
    echo "=========================================="
    echo -e "${NC}"
    
    current_hostname=$(hostname)
    echo -e "${BLUE}当前主机名: ${YELLOW}$current_hostname${NC}"
    
    read -p "请输入新的主机名 (留空取消): " new_hostname
    
    if [ -z "$new_hostname" ]; then
        echo -e "${YELLOW}操作已取消。${NC}"
        read -p "按回车键继续..."
        return
    fi
    
    if command -v hostnamectl >/dev/null 2>&1; then
        echo -e "${YELLOW}正在使用 hostnamectl 修改主机名...${NC}"
        hostnamectl set-hostname "$new_hostname"
    else
        echo -e "${YELLOW}正在修改 /etc/hostname 文件...${NC}"
        echo "$new_hostname" > /etc/hostname
        /bin/hostname "$new_hostname" # 立即生效
    fi
    
    # 检查并更新 /etc/hosts 文件
    if grep -q "$current_hostname" /etc/hosts; then
        echo -e "${YELLOW}正在更新 /etc/hosts 文件...${NC}"
        sed -i "s/$current_hostname/$new_hostname/g" /etc/hosts
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 主机名修改成功！新主机名: ${new_hostname}${NC}"
        echo -e "${YELLOW}请重新连接 SSH 会话以看到提示符更改。${NC}"
    else
        echo -e "${RED}❌ 主机名修改失败，请检查系统日志。${NC}"
    fi
    
    read -p "按回车键继续..."
}

# -------------------------------
# 6. 系统时区调整
# -------------------------------
change_system_timezone() {
    clear
    echo -e "${CYAN}=========================================="
    echo "              系统时区调整                "
    echo "=========================================="
    echo -e "${NC}"
    
    current_timezone=$(timedatectl show --property=Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo "未知")
    echo -e "${BLUE}当前时区: ${YELLOW}$current_timezone${NC}"
    
    echo "常用时区选项："
    echo "1. 亚洲/上海 (Asia/Shanghai) - 北京时间"
    echo "2. 亚洲/东京 (Asia/Tokyo)"
    echo "3. 欧洲/伦敦 (Europe/London)"
    echo "4. 美国/纽约 (America/New_York)"
    echo "0. 取消操作"
    read -p "请输入选项编号或直接输入时区名称 (如 Asia/Singapore): " choice
    
    case $choice in
        1) new_timezone="Asia/Shanghai" ;;
        2) new_timezone="Asia/Tokyo" ;;
        3) new_timezone="Europe/London" ;;
        4) new_timezone="America/New_York" ;;
        0) echo -e "${YELLOW}操作已取消。${NC}"; read -p "按回车键继续..."; return ;;
        *) new_timezone="$choice" ;; # 允许用户输入自定义时区
    esac
    
    if [ ! -f "/usr/share/zoneinfo/$new_timezone" ]; then
        echo -e "${RED}❌ 无效的时区名称: $new_timezone。请检查输入。${NC}"
        read -p "按回车键继续..."
        return
    fi
    
    if command -v timedatectl >/dev/null 2>&1; then
        echo -e "${YELLOW}正在使用 timedatectl 设置时区到 $new_timezone...${NC}"
        timedatectl set-timezone "$new_timezone"
    else
        echo -e "${YELLOW}正在手动设置时区到 $new_timezone...${NC}"
        ln -sf "/usr/share/zoneinfo/$new_timezone" /etc/localtime
        if [ -f /etc/timezone ]; then
            echo "$new_timezone" > /etc/timezone
        fi
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 时区设置成功！新时区: $new_timezone${NC}"
        # 再次显示当前时间确认
        current_time=$(date +'%Y-%m-%d %H:%M:%S %Z')
        echo -e "${BLUE}当前系统时间: ${YELLOW}$current_time${NC}"
    else
        echo -e "${RED}❌ 时区设置失败，请检查系统日志。${NC}"
    fi
    
    read -p "按回车键继续..."
}

# -------------------------------
# 7. 修改虚拟内存大小 (Swap)
# -------------------------------
manage_swap() {
    clear
    echo -e "${CYAN}=========================================="
    echo "            修改虚拟内存 (Swap)           "
    echo "=========================================="
    echo -e "${NC}"
    
    # 检查当前 Swap 状态
    current_swap=$(free -m | awk '/Swap:/ {print $2}')
    echo -e "${BLUE}当前 Swap 总大小: ${YELLOW}${current_swap}MB${NC}"
    
    read -p "请输入新的 Swap 文件大小 (MB，输入 0 表示禁用，留空取消): " swap_size_mb
    
    if [ -z "$swap_size_mb" ]; then
        echo -e "${YELLOW}操作已取消。${NC}"
        read -p "按回车键继续..."
        return
    fi

    if ! [[ "$swap_size_mb" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}无效输入！请输入纯数字大小 (MB)。${NC}"
        read -p "按回车键继续..."
        return
    fi
    
    SWAP_FILE="/swapfile"
    
    if [ "$swap_size_mb" -eq 0 ]; then
        # 禁用 Swap
        echo -e "${YELLOW}正在禁用和删除 Swap 文件...${NC}"
        if swapoff "$SWAP_FILE" 2>/dev/null; then
            echo -e "${GREEN}✅ 已禁用 Swap。${NC}"
        fi
        if rm -f "$SWAP_FILE"; then
            echo -e "${GREEN}✅ 已删除 Swap 文件 $SWAP_FILE。${NC}"
        fi
        
        # 从 fstab 中移除
        sed -i '\/swapfile/d' /etc/fstab
        echo -e "${GREEN}✅ Swap 已清理完成。${NC}"
    elif [ "$swap_size_mb" -gt 0 ]; then
        # 创建或调整 Swap
        echo -e "${YELLOW}正在创建/调整 Swap 文件到 ${swap_size_mb}MB...${NC}"
        
        # 禁用现有 Swap
        swapoff "$SWAP_FILE" 2>/dev/null
        
        # 创建新的 Swap 文件 (block size = 1M)
        if command -v fallocate >/dev/null 2>&1; then
            fallocate -l "${swap_size_mb}M" "$SWAP_FILE"
        else
            dd if=/dev/zero of="$SWAP_FILE" bs=1M count="$swap_size_mb"
        fi
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ Swap 文件创建失败！${NC}"
            read -p "按回车键继续..."
            return
        fi

        chmod 600 "$SWAP_FILE"
        mkswap "$SWAP_FILE"
        swapon "$SWAP_FILE"
        
        # 更新 fstab (确保只有一行)
        sed -i '\/swapfile/d' /etc/fstab
        echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
        
        # 设置 Swappiness
        sysctl vm.swappiness=10
        echo "vm.swappiness=10" >> /etc/sysctl.conf

        echo -e "${GREEN}✅ Swap 创建/调整成功！新大小：$(free -m | awk '/Swap:/ {print $2}')MB${NC}"
    fi

    read -p "按回车键继续..."
}


# -------------------------------
# 8. 重启服务器
# -------------------------------
reboot_server() {
    clear
    echo -e "${CYAN}=========================================="
    echo "                重启服务器                "
    echo "=========================================="
    echo -e "${NC}"
    
    echo -e "${RED}!!! 警告：此操作将立即重启您的服务器！手动重启命令 reboot !!!${NC}"
    read -p "确定要重启吗？(y/N): " confirm
    
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        echo -e "${YELLOW}正在发送重启命令...${NC}"
        # 使用 shutdown 命令提供倒计时和警告
        shutdown -r now "System reboot initiated by script"
    else
        echo -e "${YELLOW}操作已取消。${NC}"
    fi
    
    read -p "按回车键继续..."
}

# -------------------------------
# 9. 卸载本脚本
# -------------------------------
uninstall_script() {
    clear
    echo -e "${CYAN}=========================================="
    echo "                卸载本脚本                "
    echo "=========================================="
    echo -e "${NC}"
    
    # 获取当前脚本的绝对路径
    SCRIPT_PATH=$(readlink -f "$0")
    
    echo -e "${RED}!!! 警告：此操作将删除脚本文件：$SCRIPT_PATH !!!${NC}"
    read -p "确定要删除本脚本文件吗？(y/N): " confirm
    
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        echo -e "${YELLOW}正在删除脚本文件...${NC}"
        rm -f "$SCRIPT_PATH"
        
        # 尝试删除可能创建的临时文件
        rm -f "$RESULT_FILE"
        
        echo -e "${GREEN}✅ 脚本卸载完成！${NC}"
        echo -e "${YELLOW}程序即将退出。请手动清除您的终端历史记录。${NC}"
        exit 0 # 立即退出脚本执行
    else
        echo -e "${YELLOW}操作已取消。${NC}"
    fi
    
    read -p "按回车键继续..."
}

# -------------------------------
# 10. Nginx Proxy Manager 管理
# -------------------------------
nginx_proxy_manager_menu() {
    clear
    echo -e "${CYAN}=========================================="
    echo "          Nginx Proxy Manager 管理         "
    echo "=========================================="
    echo -e "${NC}"

    # 检查 Docker
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}未检测到 Docker，请先安装 Docker。${NC}"
        read -p "按回车键返回..." 
        return
    fi

    echo "1. 安装并启动 Nginx Proxy Manager"
    echo "2. 停止并删除 Nginx Proxy Manager"
    echo "3. 查看 NPM 容器日志"
    echo "4. 查看访问信息"
    echo "0. 返回上级菜单"
    read -p "请输入选项编号: " npm_choice

    case $npm_choice in
        1)
            mkdir -p /opt/npm
            cat > /opt/npm/docker-compose.yml <<EOF
version: '3'
services:
  app:
    image: jc21/nginx-proxy-manager:latest
    restart: unless-stopped
    ports:
      - "80:80"
      - "81:81"
      - "443:443"
    volumes:
      - /opt/npm/data:/data
      - /opt/npm/letsencrypt:/etc/letsencrypt
EOF
            cd /opt/npm && docker compose up -d
            echo -e "${GREEN}✅ Nginx Proxy Manager 已启动！${NC}"
            echo -e "${YELLOW}默认登录：http://服务器IP:81${NC}"
            echo -e "${YELLOW}初始账号：admin@example.com / 密码：admin${NC}"
            ;;
        2)
            cd /opt/npm && docker compose down
            rm -rf /opt/npm
            echo -e "${GREEN}✅ 已停止并删除 Nginx Proxy Manager 容器和数据${NC}"
            ;;
        3)
            docker logs -f $(docker ps -qf "ancestor=jc21/nginx-proxy-manager:latest")
            ;;
        4)
            echo -e "${GREEN}访问地址: http://$(curl -s4 ifconfig.me):81${NC}"
            echo -e "${YELLOW}初始登录：admin@example.com / admin${NC}"
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选项，请重试${NC}"
            ;;
    esac
    read -p "按回车键继续..."
}

# -------------------------------
# 查看端口占用状态
# -------------------------------
check_port_usage() {
    clear
    echo -e "${CYAN}=========================================="
    echo "              查看端口占用状态            "
    echo "==========================================${NC}"
    echo ""

    # 检查必要命令
    if ! command -v ss >/dev/null 2>&1 && ! command -v netstat >/dev/null 2>&1; then
        echo -e "${YELLOW}未检测到 ss 或 netstat 工具，正在安装...${NC}"
        if command -v apt >/dev/null 2>&1; then
            apt update -y && apt install -y net-tools
        elif command -v yum >/dev/null 2>&1; then
            yum install -y net-tools
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y net-tools
        fi
    fi

    echo "请选择操作："
    echo "1. 查看所有被占用的端口"
    echo "2. 查询指定端口的占用情况"
    echo "0. 返回上级菜单"
    echo "=========================================="
    read -p "请输入选项编号: " port_choice

    case $port_choice in
        1)
            echo ""
            echo -e "${GREEN}当前被占用的端口及进程信息:${NC}"
            if command -v ss >/dev/null 2>&1; then
                ss -tulpen
            else
                netstat -tulpen
            fi
            ;;
        2)
            read -p "请输入要查询的端口号: " port
            if [ -z "$port" ]; then
                echo -e "${YELLOW}未输入端口号，操作取消。${NC}"
            else
                echo ""
                echo -e "${GREEN}端口 ${port} 的占用情况:${NC}"
                if command -v ss >/dev/null 2>&1; then
                    ss -tulpen | grep ":${port}\b" || echo -e "${RED}未找到端口 ${port} 的占用信息。${NC}"
                else
                    netstat -tulpen | grep ":${port}\b" || echo -e "${RED}未找到端口 ${port} 的占用信息。${NC}"
                fi
            fi
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效的选项，请重新输入！${NC}"
            ;;
    esac
    echo ""
    read -p "按回车键继续..."
}

# -------------------------------
# 12. 修改 DNS 服务器 (新增功能)
# -------------------------------
change_dns_servers() {
    clear
    echo -e "${CYAN}=========================================="
    echo "              修改 DNS 服务器             "
    echo "=========================================="
    echo -e "${NC}"
    
    # 备份当前 resolv.conf
    RESOLV_CONF="/etc/resolv.conf"
    if [ -f "$RESOLV_CONF" ]; then
        echo -e "${YELLOW}正在备份 ${RESOLV_CONF} 到 ${RESOLV_CONF}.bak...${NC}"
        cp "$RESOLV_CONF" "$RESOLV_CONF.bak"
    else
        echo -e "${YELLOW}⚠️ ${RESOLV_CONF} 文件不存在，将创建新文件。${NC}"
    fi

    echo -e "${BLUE}当前 DNS 服务器设置:${NC}"
    grep -E '^nameserver' "$RESOLV_CONF" 2>/dev/null || echo -e "${YELLOW}未找到 nameserver 配置。${NC}"
    echo ""

    echo "常用公共 DNS 选项："
    echo "1. 阿里云 DNS (223.5.5.5 / 223.6.6.6)"
    echo "2. 腾讯云 DNS (119.29.29.29 / 183.60.83.19)"
    echo "3. Google DNS (8.8.8.8 / 8.8.4.4)"
    echo "4. Cloudflare DNS (1.1.1.1 / 1.0.0.1)"
    echo "0. 取消操作"
    read -p "请输入选项编号 (1-4) 或直接输入自定义的 **主DNS** (留空取消): " choice
    
    local primary_dns=""
    local secondary_dns=""
    
    case $choice in
        1) 
            primary_dns="223.5.5.5"
            secondary_dns="223.6.6.6"
            echo -e "${YELLOW}选择了 阿里云 DNS。${NC}"
            ;;
        2) 
            primary_dns="119.29.29.29"
            secondary_dns="183.60.83.19"
            echo -e "${YELLOW}选择了 腾讯云 DNS。${NC}"
            ;;
        3) 
            primary_dns="8.8.8.8"
            secondary_dns="8.8.4.4"
            echo -e "${YELLOW}选择了 Google DNS。${NC}"
            ;;
        4) 
            primary_dns="1.1.1.1"
            secondary_dns="1.0.0.1"
            echo -e "${YELLOW}选择了 Cloudflare DNS。${NC}"
            ;;
        0) 
            echo -e "${YELLOW}操作已取消。${NC}"
            read -p "按回车键继续..."
            return 
            ;;
        *) 
            if [[ -z "$choice" ]]; then
                echo -e "${YELLOW}操作已取消。${NC}"
                read -p "按回车键继续..."
                return
            fi
            primary_dns="$choice"
            read -p "请输入自定义的 **备用DNS** (留空不设置): " custom_secondary
            secondary_dns="$custom_secondary"
            ;;
    esac
    
    # 写入新的 DNS 配置
    echo -e "${YELLOW}正在写入新的 DNS 配置...${NC}"
    cat > "$RESOLV_CONF" << EOF
# Generated by CGG-VPS script
nameserver $primary_dns
EOF
    if [ -n "$secondary_dns" ]; then
        echo "nameserver $secondary_dns" >> "$RESOLV_CONF"
    fi
    
    echo -e "${GREEN}✅ DNS 服务器设置成功！${NC}"
    echo -e "${BLUE}主 DNS: ${YELLOW}$primary_dns${NC}"
    if [ -n "$secondary_dns" ]; then
        echo -e "${BLUE}备用 DNS: ${YELLOW}$secondary_dns${NC}"
    fi

    # 尝试禁用 NetworkManager 对 resolv.conf 的管理 (防止配置被覆盖)
    if command -v systemctl >/dev/null 2>&1 && systemctl is-active NetworkManager >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️ 发现 NetworkManager 正在运行，请注意它可能会覆盖 /etc/resolv.conf。${NC}"
    fi
    
    read -p "按回车键继续..."
}

# -------------------------------
# 磁盘空间分析函数 (新增)
# -------------------------------
analyze_disk_usage() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "             磁盘空间分析工具            "
    echo "=========================================="
    echo -e "${NC}"
    
    echo -e "${YELLOW}正在分析磁盘使用情况，这可能需要一些时间...${NC}"
    echo ""
    
    # 显示总体磁盘使用情况
    echo -e "${GREEN}=== 总体磁盘使用情况 ===${NC}"
    df -h
    
    echo ""
    echo -e "${GREEN}=== 前10大目录（按大小排序）===${NC}"
    # 避免扫描特殊文件系统，从根目录开始但排除某些目录
    du -h --max-depth=1 / 2>/dev/null | grep -v -E '/(proc|sys|dev|run|snap)' | sort -hr | head -n 10 | while read size path; do
        echo -e "${BLUE}$size\t$path${NC}"
    done
    
    echo ""
    echo -e "${GREEN}=== 前10大文件（大于100MB）===${NC}"
    find / -type f -size +100M 2>/dev/null | xargs ls -lh 2>/dev/null | sort -k5 -hr | head -n 10 | while read line; do
        echo -e "${YELLOW}$line${NC}"
    done
    
    echo ""
    echo -e "${GREEN}=== 按文件类型统计大小 ===${NC}"
    echo -e "${BLUE}日志文件 (.log):${NC}"
    find /var/log -name "*.log" -type f -exec du -ch {} + 2>/dev/null | tail -1 | awk '{print $1}'
    
    echo -e "${BLUE}缓存文件:${NC}"
    du -sh /var/cache/ 2>/dev/null || echo "无法访问"
    
    echo -e "${BLUE}临时文件:${NC}"
    du -sh /tmp/ /var/tmp/ 2>/dev/null | while read size path; do
        echo -e "$size\t$path"
    done
    
    echo ""
    echo -e "${GREEN}=== 清理建议 ===${NC}"
    echo -e "${YELLOW}1. 可安全清理的项目：${NC}"
    echo "   - /tmp/*, /var/tmp/* (临时文件)"
    echo "   - /var/cache/ (包管理器缓存)"
    echo "   - 旧日志文件 (/var/log/*.log.*)"
    echo -e "${YELLOW}2. 谨慎清理的项目：${NC}"
    echo "   - /var/lib/docker/ (Docker镜像和容器)"
    echo "   - 用户家目录的大文件"
    
    echo ""
    read -p "按回车键返回菜单..."
}

# -------------------------------
# 内存加速清理函数 (新增)
# -------------------------------
accelerate_memory_clean() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "            内存加速清理工具            "
    echo "=========================================="
    echo -e "${NC}"
    
    # 显示当前内存状态
    echo -e "${GREEN}=== 当前内存状态 ===${NC}"
    free -h
    echo ""
    
    echo -e "${YELLOW}⚠️ 内存加速清理将释放缓存，可能会暂时影响性能${NC}"
    read -p "是否继续执行内存加速清理？(y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then 
        echo -e "${YELLOW}已取消内存加速清理${NC}"
        read -p "按回车键返回菜单..."
        return
    fi
    
    echo -e "${BLUE}开始内存加速清理...${NC}"
    
    # 记录清理前内存状态
    MEM_BEFORE=$(free -m | awk 'NR==2{printf "Used: %sMB, Free: %sMB, Cached: %sMB", $3, $4, $6}')
    
    # 1. 同步数据到磁盘
    echo -e "${CYAN}[1/6] 同步数据到磁盘...${NC}"
    sync
    
    # 2. 清理页面缓存
    echo -e "${CYAN}[2/6] 清理页面缓存...${NC}"
    echo 1 > /proc/sys/vm/drop_caches 2>/dev/null
    
    # 3. 清理目录项和inode缓存
    echo -e "${CYAN}[3/6] 清理目录项和inode缓存...${NC}"
    echo 2 > /proc/sys/vm/drop_caches 2>/dev/null
    
    # 4. 清理所有缓存（页面缓存+目录项+inode）
    echo -e "${CYAN}[4/6] 清理所有缓存...${NC}"
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
    
    # 5. 清理slab缓存
    echo -e "${CYAN}[5/6] 清理slab缓存...${NC}"
    if command -v slabtop >/dev/null 2>&1; then
        echo -e "${YELLOW}优化slab分配器...${NC}"
    fi
    
    # 6. 重置swap（如果物理内存充足）
    echo -e "${CYAN}[6/6] 优化swap空间...${NC}"
    SWAP_USED=$(free | awk 'NR==3{print $3}')
    if [ "$SWAP_USED" -gt 0 ]; then
        echo -e "${YELLOW}检测到swap使用，尝试优化...${NC}"
        swapoff -a 2>/dev/null && swapon -a 2>/dev/null
        echo -e "${GREEN}✅ Swap空间已优化${NC}"
    else
        echo -e "${GREEN}✅ Swap使用正常，无需优化${NC}"
    fi
    
    # 显示清理结果
    echo ""
    echo -e "${GREEN}=== 内存加速清理完成 ===${NC}"
    echo -e "${BLUE}清理前: $MEM_BEFORE${NC}"
    
    MEM_AFTER=$(free -m | awk 'NR==2{printf "Used: %sMB, Free: %sMB, Cached: %sMB", $3, $4, $6}')
    echo -e "${BLUE}清理后: $MEM_AFTER${NC}"
    
    # 显示释放的内存
    FREE_BEFORE=$(echo "$MEM_BEFORE" | grep -o 'Free: [0-9]*' | cut -d' ' -f2)
    FREE_AFTER=$(echo "$MEM_AFTER" | grep -o 'Free: [0-9]*' | cut -d' ' -f2)
    if [ -n "$FREE_BEFORE" ] && [ -n "$FREE_AFTER" ]; then
        MEM_FREED=$((FREE_AFTER - FREE_BEFORE))
        if [ "$MEM_FREED" -gt 0 ]; then
            echo -e "${GREEN}✅ 成功释放内存: ${MEM_FREED}MB${NC}"
        else
            echo -e "${YELLOW}⚠️ 内存释放效果不明显，可能已处于优化状态${NC}"
        fi
    fi
    
    echo ""
    echo -e "${YELLOW}💡 提示：内存清理是临时性的，系统会根据需要重新建立缓存${NC}"
    
    read -p "按回车键返回菜单..."
}

# -------------------------------
# 实用工具箱函数 (新增)
# -------------------------------


# -------------------------------
# 1. 服务器性能全面测试
# -------------------------------
server_benchmark() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "          服务器性能全面测试             "
    echo "=========================================="
    echo -e "${NC}"
    
    echo -e "${YELLOW}请选择测试脚本：${NC}"
    echo "1. Bench.sh (综合性能测试)"
    echo "2. SuperBench.sh (超级基准测试)"
    echo "3. LemonBench (综合检测)"
    echo "0. 返回"
    
    read -p "请输入选择: " bench_choice
    
    case $bench_choice in
        1)
            echo -e "${GREEN}正在运行 Bench.sh 测试...${NC}"
            curl -Lso- bench.sh | bash
            ;;
        2)
            echo -e "${GREEN}正在运行 SuperBench.sh 测试...${NC}"
            wget -qO- --no-check-certificate https://raw.githubusercontent.com/oooldking/script/master/superbench.sh | bash
            ;;
        3)
            echo -e "${GREEN}正在运行 LemonBench 测试...${NC}"
            curl -fsL https://ilemonra.in/LemonBenchIntl | bash -s fast
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选择!${NC}"
            ;;
    esac
    
    read -p "按回车键返回..."
}

# -------------------------------
# 2. 流媒体解锁检测
# -------------------------------
streaming_unlock_test() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "           流媒体解锁检测               "
    echo "=========================================="
    echo -e "${NC}"
    
    echo -e "${YELLOW}请选择检测脚本：${NC}"
    echo "1. RegionRestrictionCheck (综合检测)"
    echo "2. NFCheck (Netflix专用)"
    echo "3. Disney+ 解锁检测"
    echo "0. 返回"
    
    read -p "请输入选择: " stream_choice
    
    case $stream_choice in
        1)
            echo -e "${GREEN}正在运行流媒体解锁检测...${NC}"
            bash <(curl -L -s https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh)
            ;;
        2)
            echo -e "${GREEN}正在检测Netflix解锁情况...${NC}"
            wget -O nfcheck.sh -q https://github.com/sjlleo/nf-check/raw/main/check.sh && bash nfcheck.sh
            ;;
        3)
            echo -e "${GREEN}正在检测Disney+解锁情况...${NC}"
            wget -O dpcheck.sh -q https://github.com/sjlleo/VerifyDisneyPlus/raw/main/verify.sh && bash dpcheck.sh
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选择!${NC}"
            ;;
    esac
    
    read -p "按回车键返回..."
}

# -------------------------------
# 3. 回程路由测试
# -------------------------------
routing_test() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "            回程路由测试                "
    echo "=========================================="
    echo -e "${NC}"
    
    echo -e "${YELLOW}请选择路由测试工具：${NC}"
    echo "1. BestTrace (IPIP.net)"
    echo "2. NextTrace (新式路由跟踪)"
    echo "3. MTR (综合路由测试)"
    echo "0. 返回"
    
    read -p "请输入选择: " route_choice
    
    case $route_choice in
        1)
            echo -e "${GREEN}正在安装并运行BestTrace...${NC}"
            wget -qO /tmp/besttrace.tar.gz https://cdn.ipip.net/17mon/besttrace4linux.tar.gz
            tar -zxvf /tmp/besttrace.tar.gz -C /tmp/
            chmod +x /tmp/besttrace
            /tmp/besttrace 114.114.114.114
            ;;
        2)
            echo -e "${GREEN}正在安装并运行NextTrace...${NC}"
            bash <(curl -Ls https://raw.githubusercontent.com/sjlleo/nexttrace/main/nt_install.sh)
            nexttrace 114.114.114.114
            ;;
        3)
            echo -e "${GREEN}正在运行MTR路由测试...${NC}"
            if ! command -v mtr >/dev/null 2>&1; then
                echo -e "${YELLOW}正在安装mtr...${NC}"
                if command -v apt >/dev/null 2>&1; then
                    apt update && apt install -y mtr
                elif command -v yum >/dev/null 2>&1; then
                    yum install -y mtr
                fi
            fi
            mtr -r -c 10 114.114.114.114
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选择!${NC}"
            ;;
    esac
    
    read -p "按回车键返回..."
}

# -------------------------------
# 4. 炫酷系统信息显示
# -------------------------------
cool_system_info() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "          炫酷系统信息显示              "
    echo "=========================================="
    echo -e "${NC}"
    
    echo -e "${YELLOW}请选择信息显示工具：${NC}"
    echo "1. Neofetch (推荐)"
    echo "2. ScreenFetch"
    echo "3. Linux_Logo"
    echo "4. Macchina (现代化)"
    echo "0. 返回"
    
    read -p "请输入选择: " info_choice
    
    case $info_choice in
        1)
            if ! command -v neofetch >/dev/null 2>&1; then
                echo -e "${YELLOW}正在安装neofetch...${NC}"
                if command -v apt >/dev/null 2>&1; then
                    apt update && apt install -y neofetch
                elif command -v yum >/dev/null 2>&1; then
                    yum install -y epel-release && yum install -y neofetch
                elif command -v dnf >/dev/null 2>&1; then
                    dnf install -y neofetch
                fi
            fi
            neofetch
            ;;
        2)
            if ! command -v screenfetch >/dev/null 2>&1; then
                echo -e "${YELLOW}正在安装screenfetch...${NC}"
                if command -v apt >/dev/null 2>&1; then
                    apt update && apt install -y screenfetch
                elif command -v yum >/dev/null 2>&1; then
                    yum install -y epel-release && yum install -y screenfetch
                fi
            fi
            screenfetch
            ;;
        3)
            if ! command -v linuxlogo >/dev/null 2>&1; then
                echo -e "${YELLOW}正在安装linux-logo...${NC}"
                if command -v apt >/dev/null 2>&1; then
                    apt update && apt install -y linuxlogo
                elif command -v yum >/dev/null 2>&1; then
                    yum install -y linuxlogo
                fi
            fi
            linuxlogo
            ;;
        4)
            echo -e "${YELLOW}正在安装macchina...${NC}"
            curl -Ls https://github.com/Macchina-CLI/macchina/releases/latest/download/macchina-linux-x86_64 -o /tmp/macchina
            chmod +x /tmp/macchina
            /tmp/macchina
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选择!${NC}"
            ;;
    esac
    
    read -p "按回车键返回..."
}

# -------------------------------
# 5. 实时系统监控仪表板
# -------------------------------
system_monitor_dashboard() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "         实时系统监控仪表板             "
    echo "=========================================="
    echo -e "${NC}"
    
    echo -e "${YELLOW}请选择监控工具：${NC}"
    echo "1. Gtop (Node.js仪表板)"
    echo "2. Bpytop (Python高级监控)"
    echo "3. Htop (增强版top)"
    echo "4. Vtop (可视化top)"
    echo "0. 返回"
    
    read -p "请输入选择: " monitor_choice
    
    case $monitor_choice in
        1)
            if ! command -v gtop >/dev/null 2>&1; then
                echo -e "${YELLOW}正在安装gtop...${NC}"
                npm install -g gtop
            fi
            gtop
            ;;
        2)
            if ! command -v bpytop >/dev/null 2>&1; then
                echo -e "${YELLOW}正在安装bpytop...${NC}"
                pip3 install bpytop
            fi
            bpytop
            ;;
        3)
            if ! command -v htop >/dev/null 2>&1; then
                echo -e "${YELLOW}正在安装htop...${NC}"
                if command -v apt >/dev/null 2>&1; then
                    apt update && apt install -y htop
                elif command -v yum >/dev/null 2>&1; then
                    yum install -y htop
                fi
            fi
            htop
            ;;
        4)
            if ! command -v vtop >/dev/null 2>&1; then
                echo -e "${YELLOW}正在安装vtop...${NC}"
                npm install -g vtop
            fi
            vtop
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选择!${NC}"
            ;;
    esac
    
    read -p "按回车键返回..."
}

# -------------------------------
# 6. 网速多节点测试
# -------------------------------
multi_speedtest() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "           网速多节点测试               "
    echo "=========================================="
    echo -e "${NC}"
    
    echo -e "${YELLOW}请选择测速工具：${NC}"
    echo "1. Speedtest-cli (Ookla)"
    echo "2. LibreSpeed (开源测速)"
    echo "3. Speedtest-X (自建测速)"
    echo "0. 返回"
    
    read -p "请输入选择: " speed_choice
    
    case $speed_choice in
        1)
            if ! command -v speedtest-cli >/dev/null 2>&1; then
                echo -e "${YELLOW}正在安装speedtest-cli...${NC}"
                if command -v apt >/dev/null 2>&1; then
                    apt update && apt install -y speedtest-cli
                elif command -v yum >/dev/null 2>&1; then
                    yum install -y speedtest-cli
                fi
            fi
            speedtest-cli
            ;;
        2)
            echo -e "${GREEN}正在运行LibreSpeed测试...${NC}"
            curl -s https://raw.githubusercontent.com/librespeed/speedtest-cli/master/speedtest.py | python3 -
            ;;
        3)
            echo -e "${GREEN}正在运行Speedtest-X测试...${NC}"
            bash <(curl -Ls https://raw.githubusercontent.com/BadApple9/speedtest-x/master/speedtest.sh)
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选择!${NC}"
            ;;
    esac
    
    read -p "按回车键返回..."
}

# -------------------------------
# 7. 端口扫描工具
# -------------------------------
port_scanner_tool() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "             端口扫描工具               "
    echo "=========================================="
    echo -e "${NC}"
    
    if ! command -v nmap >/dev/null 2>&1; then
        echo -e "${YELLOW}正在安装nmap...${NC}"
        if command -v apt >/dev/null 2>&1; then
            apt update && apt install -y nmap
        elif command -v yum >/dev/null 2>&1; then
            yum install -y nmap
        fi
    fi
    
    read -p "请输入要扫描的目标IP或域名: " target
    if [ -z "$target" ]; then
        echo -e "${RED}目标不能为空!${NC}"
        read -p "按回车键返回..."
        return
    fi
    
    echo -e "${YELLOW}请选择扫描类型：${NC}"
    echo "1. 快速扫描 (常用端口)"
    echo "2. 全面扫描 (所有端口)"
    echo "3. 服务版本检测"
    echo "4. 操作系统检测"
    echo "0. 返回"
    
    read -p "请输入选择: " scan_choice
    
    case $scan_choice in
        1)
            echo -e "${GREEN}正在快速扫描 $target ...${NC}"
            nmap -T4 -F $target
            ;;
        2)
            echo -e "${GREEN}正在全面扫描 $target ...${NC}"
            nmap -T4 -p- $target
            ;;
        3)
            echo -e "${GREEN}正在服务版本检测 $target ...${NC}"
            nmap -T4 -sV $target
            ;;
        4)
            echo -e "${GREEN}正在操作系统检测 $target ...${NC}"
            nmap -T4 -O $target
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选择!${NC}"
            ;;
    esac
    
    read -p "按回车键返回..."
}

# -------------------------------
# 8. 证书管理工具
# -------------------------------
ssl_cert_manager() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "            SSL证书管理工具             "
    echo "=========================================="
    echo -e "${NC}"
    
    echo -e "${YELLOW}请选择证书管理工具：${NC}"
    echo "1. Acme.sh (推荐)"
    echo "2. Certbot (官方)"
    echo "3. 查看当前证书"
    echo "0. 返回"
    
    read -p "请输入选择: " cert_choice
    
    case $cert_choice in
        1)
            echo -e "${GREEN}正在安装acme.sh...${NC}"
            curl https://get.acme.sh | sh
            echo -e "${YELLOW}acme.sh已安装，请使用: ~/.acme.sh/acme.sh 管理证书${NC}"
            ;;
        2)
            if command -v apt >/dev/null 2>&1; then
                apt update && apt install -y certbot
            elif command -v yum >/dev/null 2>&1; then
                yum install -y certbot
            fi
            echo -e "${YELLOW}certbot已安装，请使用: certbot 管理证书${NC}"
            ;;
        3)
            echo -e "${GREEN}当前SSL证书信息：${NC}"
            find /etc -name "*.crt" -o -name "*.pem" 2>/dev/null | head -10 | while read cert; do
                echo -e "${BLUE}证书: $cert${NC}"
                openssl x509 -in "$cert" -noout -subject -dates 2>/dev/null | head -2
                echo "---"
            done
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选择!${NC}"
            ;;
    esac
    
    read -p "按回车键返回..."
}

# -------------------------------
# 9. 服务器延迟测试
# -------------------------------
server_latency_test() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "           服务器延迟测试               "
    echo "=========================================="
    echo -e "${NC}"
    
    echo -e "${YELLOW}选择测试节点类型：${NC}"
    echo "1. 国内节点测试"
    echo "2. 国际节点测试"
    echo "3. 自定义节点测试"
    echo "0. 返回"
    
    read -p "请输入选择: " latency_choice
    
    case $latency_choice in
        1)
            nodes=("114.114.114.114" "119.29.29.29" "223.5.5.5" "180.76.76.76")
            echo -e "${GREEN}测试国内节点延迟...${NC}"
            for node in "${nodes[@]}"; do
                ping -c 4 $node | grep -E "statistics|min/avg/max"
            done
            ;;
        2)
            nodes=("8.8.8.8" "1.1.1.1" "9.9.9.9" "208.67.222.222")
            echo -e "${GREEN}测试国际节点延迟...${NC}"
            for node in "${nodes[@]}"; do
                ping -c 4 $node | grep -E "statistics|min/avg/max"
            done
            ;;
        3)
            read -p "请输入要测试的IP或域名: " custom_node
            if [ -n "$custom_node" ]; then
                ping -c 10 $custom_node
            fi
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选择!${NC}"
            ;;
    esac
    
    read -p "按回车键返回..."
}

# -------------------------------
# 10. 磁盘性能测试
# -------------------------------
disk_performance_test() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "           磁盘性能测试                 "
    echo "=========================================="
    echo -e "${NC}"
    
    if ! command -v fio >/dev/null 2>&1; then
        echo -e "${YELLOW}正在安装fio...${NC}"
        if command -v apt >/dev/null 2>&1; then
            apt update && apt install -y fio
        elif command -v yum >/dev/null 2>&1; then
            yum install -y fio
        fi
    fi
    
    echo -e "${YELLOW}请选择测试类型：${NC}"
    echo "1. 顺序读写测试"
    echo "2. 随机读写测试"
    echo "3. IOPS测试"
    echo "0. 返回"
    
    read -p "请输入选择: " disk_choice
    
    TEST_FILE="/tmp/testfile"
    SIZE="1G"
    
    case $disk_choice in
        1)
            echo -e "${GREEN}顺序读写测试中...${NC}"
            fio --name=seq_read --filename=$TEST_FILE --size=$SIZE --rw=read --direct=1 --output=seq_read.txt
            fio --name=seq_write --filename=$TEST_FILE --size=$SIZE --rw=write --direct=1 --output=seq_write.txt
            echo -e "${GREEN}顺序读取结果:${NC}"
            cat seq_read.txt | grep -E "read.*bw="
            echo -e "${GREEN}顺序写入结果:${NC}"
            cat seq_write.txt | grep -E "write.*bw="
            rm -f $TEST_FILE seq_read.txt seq_write.txt
            ;;
        2)
            echo -e "${GREEN}随机读写测试中...${NC}"
            fio --name=rand_read --filename=$TEST_FILE --size=$SIZE --rw=randread --direct=1 --output=rand_read.txt
            fio --name=rand_write --filename=$TEST_FILE --size=$SIZE --rw=randwrite --direct=1 --output=rand_write.txt
            echo -e "${GREEN}随机读取结果:${NC}"
            cat rand_read.txt | grep -E "read.*bw="
            echo -e "${GREEN}随机写入结果:${NC}"
            cat rand_write.txt | grep -E "write.*bw="
            rm -f $TEST_FILE rand_read.txt rand_write.txt
            ;;
        3)
            echo -e "${GREEN}IOPS测试中...${NC}"
            fio --name=iops_test --filename=$TEST_FILE --size=$SIZE --rw=randrw --direct=1 --output=iops_test.txt
            echo -e "${GREEN}IOPS测试结果:${NC}"
            cat iops_test.txt | grep -E "iops="
            rm -f $TEST_FILE iops_test.txt
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选择!${NC}"
            ;;
    esac
    
    read -p "按回车键返回..."
}

# -------------------------------
# 11. 系统安全扫描
# -------------------------------
system_security_scan() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "           系统安全扫描                 "
    echo "=========================================="
    echo -e "${NC}"
    
    echo -e "${YELLOW}请选择安全扫描工具：${NC}"
    echo "1. Lynis (系统安全审计)"
    echo "2. Rkhunter (Rootkit检测)"
    echo "3. Chkrootkit (Rootkit检测)"
    echo "4. ClamAV (病毒扫描)"
    echo "0. 返回"
    
    read -p "请输入选择: " security_choice
    
    case $security_choice in
        1)
            if ! command -v lynis >/dev/null 2>&1; then
                echo -e "${YELLOW}正在安装Lynis...${NC}"
                if command -v apt >/dev/null 2>&1; then
                    apt update && apt install -y lynis
                elif command -v yum >/dev/null 2>&1; then
                    yum install -y epel-release && yum install -y lynis
                fi
            fi
            echo -e "${GREEN}运行Lynis系统安全审计...${NC}"
            lynis audit system
            ;;
        2)
            if ! command -v rkhunter >/dev/null 2>&1; then
                echo -e "${YELLOW}正在安装Rkhunter...${NC}"
                if command -v apt >/dev/null 2>&1; then
                    apt update && apt install -y rkhunter
                elif command -v yum >/dev/null 2>&1; then
                    yum install -y rkhunter
                fi
            fi
            echo -e "${GREEN}运行Rkhunter Rootkit检测...${NC}"
            rkhunter --check
            ;;
        3)
            if ! command -v chkrootkit >/dev/null 2>&1; then
                echo -e "${YELLOW}正在安装Chkrootkit...${NC}"
                if command -v apt >/dev/null 2>&1; then
                    apt update && apt install -y chkrootkit
                elif command -v yum >/dev/null 2>&1; then
                    yum install -y chkrootkit
                fi
            fi
            echo -e "${GREEN}运行Chkrootkit Rootkit检测...${NC}"
            chkrootkit
            ;;
        4)
            if ! command -v clamscan >/dev/null 2>&1; then
                echo -e "${YELLOW}正在安装ClamAV...${NC}"
                if command -v apt >/dev/null 2>&1; then
                    apt update && apt install -y clamav clamav-daemon
                elif command -v yum >/dev/null 2>&1; then
                    yum install -y clamav clamav-update
                fi
            fi
            echo -e "${GREEN}运行ClamAV病毒扫描...${NC}"
            clamscan --recursive --infected /home
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选择!${NC}"
            ;;
    esac
    
    read -p "按回车键返回..."
}

# -------------------------------
# 12. 文件完整性检查
# -------------------------------
file_integrity_check() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "           文件完整性检查               "
    echo "=========================================="
    echo -e "${NC}"
    
    echo -e "${YELLOW}请选择完整性检查工具：${NC}"
    echo "1. AIDE (高级入侵检测环境)"
    echo "2. Tripwire (文件完整性检查)"
    echo "3. 手动MD5校验"
    echo "0. 返回"
    
    read -p "请输入选择: " integrity_choice
    
    case $integrity_choice in
        1)
            if ! command -v aide >/dev/null 2>&1; then
                echo -e "${YELLOW}正在安装AIDE...${NC}"
                if command -v apt >/dev/null 2>&1; then
                    apt update && apt install -y aide
                elif command -v yum >/dev/null 2>&1; then
                    yum install -y aide
                fi
            fi
            echo -e "${GREEN}初始化AIDE数据库...${NC}"
            aide --init
            echo -e "${GREEN}运行AIDE完整性检查...${NC}"
            aide --check
            ;;
        2)
            if ! command -v tripwire >/dev/null 2>&1; then
                echo -e "${YELLOW}正在安装Tripwire...${NC}"
                if command -v apt >/dev/null 2>&1; then
                    apt update && apt install -y tripwire
                elif command -v yum >/dev/null 2>&1; then
                    yum install -y tripwire
                fi
            fi
            echo -e "${GREEN}初始化Tripwire数据库...${NC}"
            tripwire --init
            echo -e "${GREEN}运行Tripwire完整性检查...${NC}"
            tripwire --check
            ;;
        3)
            read -p "请输入要校验的文件路径: " file_path
            if [ -f "$file_path" ]; then
                echo -e "${GREEN}计算文件MD5校验和...${NC}"
                md5sum "$file_path"
                echo -e "${GREEN}计算文件SHA256校验和...${NC}"
                sha256sum "$file_path"
            else
                echo -e "${RED}文件不存在!${NC}"
            fi
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选择!${NC}"
            ;;
    esac
    
    read -p "按回车键返回..."
}

# -------------------------------
# 系统工具主菜单 (更新，调用实际函数)
# -------------------------------
system_tools_menu() {
    while true; do
        clear
        echo -e "${CYAN}"
        echo "=========================================="
        echo "              系统工具菜单                "
        echo "=========================================="
        echo -e "${NC}"
        printf "${GREEN}%-40s %-35s${NC}\n" "1. 高级防火墙管理" "14. 磁盘空间分析"
        printf "${GREEN}%-40s %-35s${NC}\n" "2. 修改登录密码" "15. 服务器性能全面测试 (Bench.sh)"
        printf "${GREEN}%-40s %-35s${NC}\n" "3. 修改SSH 连接端口" "16. 流媒体解锁检测 (RegionRestrictionCheck)"
        printf "${GREEN}%-40s %-35s${NC}\n" "4. 切换优先 IPV4/IPV6" "17. 回程路由测试 (BestTrace)"
        printf "${GREEN}%-40s %-35s${NC}\n" "5. 修改主机名" "18. 炫酷系统信息显示 (neofetch)"
        printf "${GREEN}%-40s %-35s${NC}\n" "6. 系统时区调整" "19. 实时系统监控仪表板 (gtop/bpytop)"
        printf "${GREEN}%-40s %-35s${NC}\n" "7. 修改虚拟内存大小 (Swap)" "20. 网速多节点测试 (Speedtest-X)"
        printf "${GREEN}%-40s %-35s${NC}\n" "8. 内存加速清理" "21. 端口扫描工具 (nmap)"
        printf "${GREEN}%-40s %-35s${NC}\n" "9. 重启服务器" "22. 证书管理工具 (acme.sh)"
        printf "${GREEN}%-40s %-35s${NC}\n" "10. 卸载本脚本" "23. 服务器延迟测试 (Ping测试)"
        printf "${GREEN}%-40s %-35s${NC}\n" "11. Nginx Proxy Manager 管理" "24. 磁盘性能测试 (fio/iozone)"
        printf "${GREEN}%-40s %-35s${NC}\n" "12. 查看端口占用状态" "25. 系统安全扫描 (Lynis)"
        printf "${GREEN}%-40s %-35s${NC}\n" "13. 修改DNS 服务器" "26. 文件完整性检查 (AIDE)"
        echo -e "${GREEN}0. 返回主菜单${NC}"
        echo "=========================================="

        read -p "请输入选项编号: " tools_choice

        case $tools_choice in
            1) advanced_firewall_menu ;;
            2) change_login_password ;;
            3) change_ssh_port ;;
            4) toggle_ipv_priority ;;
            5) change_hostname ;;
            6) change_system_timezone ;;
            7) manage_swap ;;
            8) accelerate_memory_clean ;;
            9) reboot_server ;;
            10) uninstall_script ;;
            11) nginx_proxy_manager_menu ;;
            12) check_port_usage ;;
            13) change_dns_servers ;;
            14) analyze_disk_usage ;;
            15) server_benchmark ;;
            16) streaming_unlock_test ;;
            17) routing_test ;;
            18) cool_system_info ;;
            19) system_monitor_dashboard ;;
            20) multi_speedtest ;;
            21) port_scanner_tool ;;
            22) ssl_cert_manager ;;
            23) server_latency_test ;;
            24) disk_performance_test ;;
            25) system_security_scan ;;
            26) file_integrity_check ;;
            0) return ;;
            *) echo -e "${RED}无效的选项，请重新输入！${NC}"; sleep 1 ;;
        esac
    done
}

# -------------------------------
# VPS网络测试子菜单
# -------------------------------
vps_network_test_menu() {
    while true; do
        clear
        echo -e "${CYAN}=========================================="
        echo "            VPS网络全面测试             "
        echo "=========================================="
        echo -e "${NC}"
        echo "1. 网络速度测速（完整测速NodeQuality）"
        echo "2. 网络质量体检"（完整交互版）
        echo "0. 返回主菜单"
        echo "=========================================="

        read -p "请输入选项编号: " network_choice

        case $network_choice in
            1)
                vps_speed_test
                ;;
            2)
                network_health_check
                ;;
            0)
                echo "返回主菜单..."
                break
                ;;
            *)
                echo -e "${RED}无效的选项，请重新输入！${NC}"
                sleep 1
                ;;
        esac
    done
}

# -------------------------------
# 1. 网络速度测速 (原有功能)
# -------------------------------
vps_speed_test() {
    clear
    echo -e "${CYAN}=========================================="
    echo "         网络速度测速（NodeQuality）           "
    echo "=========================================="
    echo -e "${NC}"
    echo -e "${YELLOW}正在下载并运行网络测速脚本...${NC}"
    echo -e "${BLUE}来源: NodeQuality.com${NC}"
    
    # 检查是否安装curl
    if ! command -v curl > /dev/null 2>&1; then
        echo -e "${YELLOW}未检测到curl，正在尝试安装...${NC}"
        if command -v apt > /dev/null 2>&1; then
            apt update -y && apt install -y curl
        elif command -v yum > /dev/null 2>&1; then
            yum install -y curl
        elif command -v dnf > /dev/null 2>&1; then
            dnf install -y curl
        else
            echo -e "${RED}无法安装curl，请手动安装后重试${NC}"
            read -p "按回车键返回..."
            return
        fi
    fi
    
    # 运行网络测速
    echo -e "${GREEN}✅ 开始网络测速...${NC}"
    echo -e "${YELLOW}这可能需要几分钟时间，请耐心等待...${NC}"
    bash <(curl -sL https://run.NodeQuality.com)
    
    echo -e "${CYAN}"
    echo "=========================================="
    echo -e "${NC}"
    read -p "测速完成，按回车键返回..."
}

# -------------------------------
# 2. 网络质量体检 (新增功能)
# -------------------------------
network_health_check() {
    clear
    echo -e "${CYAN}=========================================="
    echo "           网络质量延迟脚本交互                "
    echo "=========================================="
    echo -e "${NC}"
    echo -e "${YELLOW}正在下载并运行网络质量检测脚本...${NC}"
    echo -e "${BLUE}来源: Check.Place${NC}"
    echo -e "${GREEN}功能特点:${NC}"
    echo "• 全面的网络连接质量分析"
    echo "• 路由追踪和延迟检测"
    echo "• 网络稳定性评估"
    echo "• 详细的诊断报告"
    
    # 检查是否安装curl
    if ! command -v curl > /dev/null 2>&1; then
        echo -e "${YELLOW}未检测到curl，正在尝试安装...${NC}"
        if command -v apt > /dev/null 2>&1; then
            apt update -y && apt install -y curl
        elif command -v yum > /dev/null 2>&1; then
            yum install -y curl
        elif command -v dnf > /dev/null 2>&1; then
            dnf install -y curl
        else
            echo -e "${RED}无法安装curl，请手动安装后重试${NC}"
            read -p "按回车键返回..."
            return
        fi
    fi
    
    # 运行网络质量体检
    echo -e "${GREEN}✅ 开始网络质量体检...${NC}"
    echo -e "${YELLOW}正在进行全面网络诊断，请稍候...${NC}"
    echo -e "${BLUE}执行命令: bash <(curl -Ls https://Check.Place) -N${NC}"
    bash <(curl -Ls https://Check.Place) -N
    
    echo -e "${CYAN}"
    echo "=========================================="
    echo -e "${NC}"
    echo -e "${GREEN}网络质量体检完成！${NC}"
    echo -e "${YELLOW}请参考上面的报告了解网络状况${NC}"
    read -p "按回车键返回..."
}

# ====================================================================
# +++ 主菜单函数更新 +++
# ====================================================================

show_menu() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "       CGG-VPS 脚本管理菜单 v3.3         "
    echo "=========================================="
    echo -e "${NC}"
    echo "1. 系统信息查询"
    echo "2. 系统更新"
    echo "3. 系统清理"
    echo "4. 基础工具"
    echo "5. BBR管理"
    echo "6. Docker管理"
    echo "7. 系统工具"
    echo "8. VPS测试IP网络"
    echo "0. 退出脚本"
    echo "=========================================="
}

# ====================================================================
# +++ 主执行逻辑更新 +++
# ====================================================================

# 脚本启动时，首先检查root权限和依赖
check_root
check_deps

# 无限循环，直到用户选择退出
while true; do
    show_menu
    read -p "请输入你的选择 (0-8): " main_choice

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
            system_tools_menu
            ;;
        8)
            vps_network_test_menu
            ;;
        0)
            echo -e "${GREEN}感谢使用，正在退出脚本...${NC}"
            exit 0  # 改为 exit 0 确保完全退出
            ;;
        *)
            echo -e "${RED}无效的选项，请重新输入！${NC}"
            sleep 1
            ;;
    esac
done
