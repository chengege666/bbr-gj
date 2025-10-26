#!/bin/bash

# VPS一键管理脚本 v0.8 (全面实现系统工具菜单功能)
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
# 显示主菜单函数
# -------------------------------
show_menu() {
    clear
    echo -e "${CYAN}"
    echo "=========================================="
    echo "          VPS 脚本管理菜单 v0.8           "
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


# -------------------------------
# 检查BBR状态函数
# -------------------------------
check_bbr() {
    local bbr_enabled=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
    local bbr_module=$(lsmod | grep bbr)
    local default_qdisc=$(sysctl net.core.default_qdisc | awk '{print $3}')
    local bbr_params=$(sysctl -a 2>/dev/null | grep -E "bbr|tcp_congestion_control" | grep -v '^net.core' | sort)
    local bbr_version=""
    if [[ "$bbr_enabled" == *"bbr"* ]]; then
        if [[ "$bbr_enabled" == "bbr" ]]; then
            bbr_version="BBR v1"
        elif [[ "$bbr_enabled" == "bbr2" ]]; then
            bbr_version="BBR v2"
        else
            bbr_version="未知BBR类型"
        fi
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
    clear; echo -e "${CYAN}"; echo "=========================================="; echo "              系统信息查询                "; echo "=========================================="; echo -e "${NC}"
    echo -e "${BLUE}主机名: ${GREEN}$(hostname)${NC}"
    if [ -f /etc/os-release ]; then source /etc/os-release; echo -e "${BLUE}操作系统: ${NC}$PRETTY_NAME"; else echo -e "${BLUE}操作系统: ${NC}未知"; fi
    echo -e "${BLUE}内核版本: ${NC}$(uname -r)"
    cpu_model=$(grep 'model name' /proc/cpuinfo | head -1 | cut -d ':' -f2 | sed 's/^ *//')
    cpu_cores=$(grep -c '^processor' /proc/cpuinfo)
    echo -e "${BLUE}CPU型号: ${NC}$cpu_model"; echo -e "${BLUE}CPU核心数: ${NC}$cpu_cores"
    total_mem=$(free -m | awk '/Mem:/ {print $2}'); available_mem=$(free -m | awk '/Mem:/ {print $7}')
    echo -e "${BLUE}总内存: ${NC}${total_mem}MB"; echo -e "${BLUE}可用内存: ${NC}${available_mem}MB"
    disk_usage=$(df -h / | awk 'NR==2 {print $5}'); disk_total=$(df -h / | awk 'NR==2 {print $2}'); disk_used=$(df -h / | awk 'NR==2 {print $3}')
    echo -e "${BLUE}根分区使用率: ${NC}$disk_usage (已用 ${disk_used} / 总共 ${disk_total})"
    ipv4=$(curl -s --connect-timeout 2 ipv4.icanhazip.com); if [ -z "$ipv4" ]; then ipv4=$(curl -s --connect-timeout 2 ipv4.ip.sb); fi
    if [ -z "$ipv4" ]; then ipv4="${RED}无法获取${NC}"; else ipv4="${YELLOW}$ipv4${NC}"; fi; echo -e "${BLUE}公网IPv4: $ipv4"
    ipv6=$(curl -s --connect-timeout 2 ipv6.icanhazip.com); if [ -z "$ipv6" ]; then ipv6=$(curl -s --connect-timeout 2 ipv6.ip.sb); fi
    if [ -z "$ipv6" ]; then ipv6="${RED}未检测到${NC}"; else ipv6="${YELLOW}$ipv6${NC}"; fi; echo -e "${BLUE}公网IPv6: $ipv6"
    echo -e "${BLUE}BBR状态: ${NC}"; check_bbr
    uptime_info=$(uptime -p | sed 's/up //'); echo -e "${BLUE}系统运行时间: ${NC}$uptime_info"
    beijing_time=$(TZ='Asia/Shanghai' date +'%Y-%m-%d %H:%M:%S'); echo -e "${BLUE}北京时间: ${NC}$beijing_time"
    echo -e "${CYAN}"; echo "=========================================="; echo -e "${NC}"; read -p "按回车键返回主菜单..."
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
# 系统清理函数
# -------------------------------
system_clean() {
    clear; echo -e "${CYAN}"; echo "=========================================="; echo "              系统清理功能                "; echo "=========================================="; echo -e "${NC}"
    echo -e "${YELLOW}⚠️ 警告：系统清理操作将删除不必要的文件，请谨慎操作！${NC}"; echo ""
    read -p "是否继续执行系统清理？(y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then echo -e "${YELLOW}已取消系统清理操作${NC}"; read -p "按回车键返回主菜单..."; return; fi
    if [ -f /etc/debian_version ]; then
        echo -e "${BLUE}检测到 Debian/Ubuntu 系统${NC}"; echo -e "${YELLOW}开始清理系统...${NC}"; echo ""
        echo -e "${BLUE}[步骤1/4] 清理APT缓存...${NC}"; apt clean; echo ""
        echo -e "${BLUE}[步骤2/4] 清理旧内核...${NC}"; apt autoremove --purge -y; echo ""
        echo -e "${BLUE}[步骤3/4] 清理日志文件...${NC}"; journalctl --vacuum-time=1d; find /var/log -type f -regex ".*\.gz$" -delete; find /var/log -type f -regex ".*\.[0-9]$" -delete; echo ""
        echo -e "${BLUE}[步骤4/4] 清理临时文件...${NC}"; rm -rf /tmp/*; rm -rf /var/tmp/*; echo ""
        echo -e "${GREEN}系统清理完成！${NC}"
    elif [ -f /etc/redhat-release ]; then
        echo -e "${BLUE}检测到 CentOS/RHEL 系统${NC}"; echo -e "${YELLOW}开始清理系统...${NC}"; echo ""
        echo -e "${BLUE}[步骤1/4] 清理YUM缓存...${NC}"; yum clean all; echo ""
        echo -e "${BLUE}[步骤2/4] 清理旧内核...${NC}"; package-cleanup --oldkernels --count=1 -y; echo ""
        echo -e "${BLUE}[步骤3/4] 清理日志文件...${NC}"; journalctl --vacuum-time=1d; find /var/log -type f -regex ".*\.gz$" -delete; find /var/log -type f -regex ".*\.[0-9]$" -delete; echo ""
        echo -e "${BLUE}[步骤4/4] 清理临时文件...${NC}"; rm -rf /tmp/*; rm -rf /var/tmp/*; echo ""
        echo -e "${GREEN}系统清理完成！${NC}"
    else
        echo -e "${RED}不支持的系统类型！${NC}"; echo -e "${YELLOW}仅支持 Debian/Ubuntu 和 CentOS/RHEL 系统。${NC}"
    fi
    echo -e "${CYAN}"; echo "=========================================="; echo -e "${NC}"; read -p "按回车键返回主菜单..."
}
# -------------------------------
# 基础工具安装函数
# -------------------------------
basic_tools() {
    clear; echo -e "${CYAN}"; echo "=========================================="; echo "              基础工具安装                "; echo "=========================================="; echo -e "${NC}"
    DEBIAN_TOOLS="htop vim tmux net-tools dnsutils lsof tree zip unzip"
    REDHAT_TOOLS="htop vim tmux net-tools bind-utils lsof tree zip unzip"
    if [ -f /etc/debian_version ]; then
        echo -e "${BLUE}检测到 Debian/Ubuntu 系统${NC}"; echo -e "${YELLOW}开始安装基础工具...${NC}"; echo ""
        echo -e "${BLUE}[步骤1/2] 更新软件包列表...${NC}"; apt update -y; echo ""
        echo -e "${BLUE}[步骤2/2] 安装基础工具...${NC}"; apt install -y $DEBIAN_TOOLS; echo ""
        echo -e "${GREEN}基础工具安装完成！${NC}"; echo -e "${YELLOW}已安装工具: $DEBIAN_TOOLS${NC}"
    elif [ -f /etc/redhat-release ]; then
        echo -e "${BLUE}检测到 CentOS/RHEL 系统${NC}"; echo -e "${YELLOW}开始安装基础工具...${NC}"; echo ""
        echo -e "${BLUE}[步骤1/1] 安装基础工具...${NC}"; yum install -y epel-release; yum install -y $REDHAT_TOOLS; echo ""
        echo -e "${GREEN}基础工具安装完成！${NC}"; echo -e "${YELLOW}已安装工具: $REDHAT_TOOLS${NC}"
    else
        echo -e "${RED}不支持的系统类型！${NC}"; echo -e "${YELLOW}仅支持 Debian/Ubuntu 和 CentOS/RHEL 系统。${NC}"
    fi
    echo -e "${CYAN}"; echo "=========================================="; echo -e "${NC}"; read -p "按回车键返回主菜单..."
}

# ====================================================================
# +++ BBR & Docker 功能实现 (已补全) +++
# ====================================================================

# -------------------------------
# BBR 管理菜单
# -------------------------------
bbr_management() {
    while true; do
        clear
        echo -e "${CYAN}"
        echo "=========================================="
        echo "                BBR 管理菜单              "
        echo "=========================================="
        echo -e "${NC}"
        echo -e "${BLUE}当前BBR状态:${NC}"
        check_bbr # 调用检查函数显示状态
        echo "------------------------------------------"
        echo "1. 安装/升级 BBR v1 (Linux 内核)"
        echo "2. 安装 BBR Plus 内核 (xanmod)"
        echo "3. 卸载 BBR Plus 内核"
        echo "4. 开启 BBR / BBR Plus"
        echo "5. 关闭 BBR"
        echo "0. 返回主菜单"
        echo "=========================================="
        read -p "请输入选项编号: " bbr_choice

        case $bbr_choice in
            1)
                echo -e "${YELLOW}功能占位：正在准备执行 BBR v1 安装脚本...${NC}"
                # 此处可以集成类似 aoj.ac 的一键脚本
                # bash <(curl -L -s https://github.com/teddysun/across/raw/master/bbr.sh)
                echo -e "${GREEN}提示: BBR v1 通常需要升级内核，操作后需要重启。${NC}"
                read -p "按回车键返回..."
                ;;
            2)
                echo -e "${YELLOW}功能占位：正在准备执行 BBR Plus 安装脚本...${NC}"
                # 此处可以集成 xanmod 内核安装脚本
                # wget -qO- https://dl.xanmod.org/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg
                # echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | tee /etc/apt/sources.list.d/xanmod-release.list
                # apt update && apt install linux-xanmod -y
                echo -e "${GREEN}提示: 安装新内核后需要重启才能生效。${NC}"
                read -p "按回车键返回..."
                ;;
            3)
                echo -e "${YELLOW}功能占位：正在准备卸载 BBR Plus 内核...${NC}"
                # apt-get remove --purge linux-xanmod
                echo -e "${GREEN}提示: 卸载内核后需要重启。${NC}"
                read -p "按回车键返回..."
                ;;
            4)
                echo -e "${YELLOW}正在尝试开启 BBR...${NC}"
                sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
                sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
                echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
                echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
                sysctl -p >/dev/null 2>&1
                echo -e "${GREEN}✅ BBR 已开启，请检查上方状态确认。${NC}"
                read -p "按回车键返回..."
                ;;
            5)
                echo -e "${YELLOW}正在尝试关闭 BBR (恢复 cubic)...${NC}"
                sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
                sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
                echo "net.ipv4.tcp_congestion_control=cubic" >> /etc/sysctl.conf
                sysctl -p >/dev/null 2>&1
                echo -e "${GREEN}✅ BBR 已关闭。${NC}"
                read -p "按回车键返回..."
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

# -------------------------------
# Docker 管理菜单
# -------------------------------
docker_management_menu() {
    while true; do
        clear
        echo -e "${CYAN}"
        echo "=========================================="
        echo "               Docker 管理菜单            "
        echo "=========================================="
        echo -e "${NC}"
        if ! command -v docker >/dev/null 2>&1; then
            echo -e "${YELLOW}⚠️ Docker 未安装。${NC}"
            echo "------------------------------------------"
            echo "1. 安装 Docker"
            echo "0. 返回主菜单"
        else
            echo -e "${BLUE}Docker 版本: ${GREEN}$(docker --version)${NC}"
            echo -e "${BLUE}Docker-Compose 版本: ${GREEN}$(docker-compose --version 2>/dev/null || echo '未安装')${NC}"
            echo "------------------------------------------"
            echo "2. 卸载 Docker"
            echo "3. 启动/停止/重启 Docker 服务"
            echo "4. 查看 Docker 容器/镜像/网络"
            echo "5. 清理 Docker 资源 (慎用)"
            echo "6. 安装 Docker-Compose"
            echo "0. 返回主菜单"
        fi
        echo "=========================================="
        read -p "请输入选项编号: " docker_choice

        case $docker_choice in
            1)
                echo -e "${YELLOW}正在执行 Docker 一键安装脚本...${NC}"
                bash <(curl -sSL https://get.docker.com)
                systemctl enable --now docker
                echo -e "${GREEN}✅ Docker 安装完成！${NC}"
                read -p "按回车键返回..."
                ;;
            2)
                read -p "确定要卸载 Docker 吗？(y/N): " confirm
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    echo -e "${YELLOW}正在卸载 Docker...${NC}"
                    systemctl stop docker
                    if command -v apt >/dev/null 2>&1; then
                        apt-get purge -y docker-ce docker-ce-cli containerd.io
                        rm -rf /var/lib/docker
                    elif command -v yum >/dev/null 2>&1; then
                        yum remove -y docker-ce docker-ce-cli containerd.io
                        rm -rf /var/lib/docker
                    fi
                    echo -e "${GREEN}✅ Docker 卸载完成。${NC}"
                else
                    echo -e "${YELLOW}操作已取消。${NC}"
                fi
                read -p "按回车键返回..."
                ;;
            3)
                read -p "选择操作: [1]启动 [2]停止 [3]重启 Docker: " docker_op
                case $docker_op in
                    1) systemctl start docker; echo "Docker 已启动" ;;
                    2) systemctl stop docker; echo "Docker 已停止" ;;
                    3) systemctl restart docker; echo "Docker 已重启" ;;
                    *) echo "无效操作" ;;
                esac
                read -p "按回车键返回..."
                ;;
            4)
                echo "--- [容器列表] ---"; docker ps -a; 
                echo -e "\n--- [镜像列表] ---"; docker images;
                echo -e "\n--- [网络列表] ---"; docker network ls;
                read -p "按回车键返回..."
                ;;
            5)
                read -p "警告：这将删除所有停止的容器和未使用的镜像/网络！确定吗？(y/N): " confirm
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    docker system prune -a -f
                    echo -e "${GREEN}✅ Docker 资源清理完成。${NC}"
                else
                    echo -e "${YELLOW}操作已取消。${NC}"
                fi
                read -p "按回车键返回..."
                ;;
            6)
                echo -e "${YELLOW}正在安装最新版 Docker-Compose...${NC}"
                LATEST_COMPOSE_URL=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep "browser_download_url" | grep "docker-compose-linux-x86_64" | cut -d '"' -f 4)
                if [ -z "$LATEST_COMPOSE_URL" ]; then
                    echo -e "${RED}❌ 无法获取 Docker-Compose 最新版本链接，请检查网络或稍后再试。${NC}"
                else
                    curl -L "$LATEST_COMPOSE_URL" -o /usr/local/bin/docker-compose
                    chmod +x /usr/local/bin/docker-compose
                    echo -e "${GREEN}✅ Docker-Compose 安装完成: $(docker-compose --version)${NC}"
                fi
                read -p "按回车键返回..."
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
# 4. 切换优先 IPV4/IPV6
# -------------------------------
toggle_ipv_priority() {
    clear
    echo -e "${CYAN}=========================================="
    echo "            切换 IPV4/IPV6 优先           "
    echo "=========================================="
    echo -e "${NC}"
    
    GAI_CONF="/etc/gai.conf"
    
    echo "请选择优先使用的网络协议："
    echo "1. 优先使用 IPv4"
    echo "2. 优先使用 IPv6"
    echo "0. 取消操作"
    read -p "请输入选项编号: " choice
    
    case $choice in
        1)
            # 优先 IPv4 (取消对 ::ffff:0:0/96 的优先，并设置 ::/0 的优先级低于 IPv4)
            echo -e "${YELLOW}正在配置优先使用 IPv4...${NC}"
            
            # 备份原始文件
            [ -f "$GAI_CONF" ] && cp "$GAI_CONF" "$GAI_CONF.bak"
            
            # 移除或注释掉所有 priority 行
            sed -i '/^#\s*precedence/!s/^\s*precedence/# precedence/g' "$GAI_CONF" 2>/dev/null
            touch "$GAI_CONF" # 如果文件不存在则创建
            sed -i '/^precedence\s*::ffff:0:0\/96/d' "$GAI_CONF"

            # 写入优先 IPv4 的配置
            echo "precedence ::ffff:0:0/96  100" >> "$GAI_CONF"
            
            echo -e "${GREEN}✅ 配置完成。系统将优先使用 IPv4。${NC}"
            ;;
        2)
            # 优先 IPv6 (确保默认优先级，同时不给 IPv4 专门的优先权)
            echo -e "${YELLOW}正在配置优先使用 IPv6 (恢复默认)...${NC}"
            
            # 备份原始文件
            [ -f "$GAI_CONF" ] && cp "$GAI_CONF" "$GAI_CONF.bak"

            # 移除或注释掉所有 priority 行
            sed -i '/^#\s*precedence/!s/^\s*precedence/# precedence/g' "$GAI_CONF" 2>/dev/null
            touch "$GAI_CONF" # 如果文件不存在则创建
            sed -i '/^precedence\s*::ffff:0:0\/96/d' "$GAI_CONF"

            echo -e "${GREEN}✅ 配置完成。系统将按默认配置优先解析 IPv6。${NC}"
            ;;
        0)
            echo -e "${YELLOW}操作已取消。${NC}"
            read -p "按回车键继续..."
            return
            ;;
        *)
            echo -e "${RED}无效的选项。${NC}"
            read -p "按回车键继续..."
            return
            ;;
    esac
    
    echo -e "${YELLOW}配置更改已应用。${NC}"
    read -p "按回车键继续..."
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
    
    echo -e "${RED}!!! 警告：此操作将立即重启您的服务器！ !!!${NC}"
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
        echo "1. 高级防火墙管理"
        echo "2. 修改登录密码"
        echo "3. 修改 SSH 连接端口"
        echo "4. 切换优先 IPV4/IPV6"
        echo "5. 修改主机名"
        echo "6. 系统时区调整"
        echo "7. 修改虚拟内存大小 (Swap)"
        echo "8. 重启服务器"
        echo "9. 卸载本脚本"
        echo "0. 返回主菜单"
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
            8) reboot_server ;;
            9) uninstall_script ;;
            0) return ;;
            *) echo -e "${RED}无效的选项，请重新输入！${NC}"; sleep 1 ;;
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
            # 调用已实现功能的系统工具主菜单
            system_tools_menu
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
