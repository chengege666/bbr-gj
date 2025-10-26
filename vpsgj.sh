#!/bin/bash

# VPS一键管理脚本 v0.7.1 (集成高级防火墙管理)
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
    PKGS="curl wget git net-tools iptables"
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
    for CMD in curl wget git iptables; do
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
    echo "          VPS 脚本管理菜单 v0.7.1         "
    echo "=========================================="
    echo -e "${NC}"
    echo "1. 系统信息查询"
    echo "2. 系统更新"
    echo "3. 系统清理"
    echo "4. 基础工具"
    echo "5. BBR管理"
    echo "6. Docker管理"
    echo "7. 系统工具 (包含防火墙管理)"
    echo "0. 退出脚本"
    echo "=========================================="
}

# -------------------------------
# 检查BBR状态函数 (保留原逻辑，修复行号问题)
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
        fi # <--- 之前错误指向的区域
        
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

# (系统信息、系统更新、系统清理、基础工具、BBR管理、Docker管理等其他函数省略，与v0.6保持一致)

# -------------------------------
# 基础工具安装函数 (修复了中文错别字)
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

# (为保持精简，省略其余原有的 BBR 和 Docker 函数，这些函数在您的文件中是完整的)

# ====================================================================
# +++ 新增：高级防火墙管理函数 +++
# ====================================================================

# -------------------------------
# Iptables/Firewalld 兼容性检查和警告
# -------------------------------
check_firewall_system() {
    # 优先检查 iptables 命令是否存在
    if command -v iptables &>/dev/null; then
        echo -e "${YELLOW}⚠️ 警告：本功能依赖 iptables。系统可能同时运行 firewalld 或 ufw，请注意配置冲突。${NC}"
        return 0 # 0表示通过
    else
        echo -e "${RED}❌ 错误：未检测到 iptables 命令。请确保系统已安装 iptables。${NC}"
        read -p "按回车键返回..."
        return 1
    fi
}

# -------------------------------
# 开放/关闭端口的基础函数
# -------------------------------
manage_port() {
    local action="$1" # 'OPEN' or 'CLOSE'
    local port="$2"
    local proto="$3" # 'tcp' or 'udp' or 'both'
    
    if [ "$proto" == "both" ]; then
        manage_port "$action" "$port" "tcp"
        manage_port "$action" "$port" "udp"
        return
    fi

    if [ "$action" == "OPEN" ]; then
        iptables -A INPUT -p "$proto" --dport "$port" -j ACCEPT
        echo -e "${GREEN}✅ 已开放端口：${port}/${proto}${NC}"
    elif [ "$action" == "CLOSE" ]; then
        iptables -D INPUT -p "$proto" --dport "$port" -j ACCEPT 2>/dev/null
        iptables -A INPUT -p "$proto" --dport "$port" -j DROP
        echo -e "${YELLOW}🚫 已关闭端口：${port}/${proto}${NC}"
    fi
}

# -------------------------------
# 1. 开放指定端口 (Open specified port)
# -------------------------------
open_port() {
    read -p "请输入要开放的端口号 (如 80 或 22): " port
    read -p "请输入协议 (tcp/udp/both): " proto
    proto=${proto:-tcp}
    manage_port "OPEN" "$port" "$proto"
}

# -------------------------------
# 2. 关闭指定端口 (Close specified port)
# -------------------------------
close_port() {
    read -p "请输入要关闭的端口号 (如 80 或 22): " port
    read -p "请输入协议 (tcp/udp/both): " proto
    proto=${proto:-tcp}
    manage_port "CLOSE" "$port" "$proto"
}

# -------------------------------
# 3. 开放所有端口 (Open all ports)
# -------------------------------
open_all_ports() {
    echo -e "${RED}⚠️ 警告：开放所有端口具有高风险！${NC}"
    read -p "确定要继续吗? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then return; fi
    iptables -F INPUT # 清除所有INPUT规则
    iptables -A INPUT -j ACCEPT # 默认接受所有连接
    echo -e "${GREEN}✅ 已开放所有端口（ACCEPT策略）${NC}"
}

# -------------------------------
# 4. 关闭所有端口 (Close all ports)
# -------------------------------
close_all_ports() {
    echo -e "${RED}⚠️ 警告：关闭所有端口将中断所有连接，包括 SSH！${NC}"
    read -p "确定要继续吗? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then return; fi
    iptables -P INPUT DROP # 默认拒绝所有连接
    echo -e "${RED}🚫 已关闭所有端口（DROP策略），当前 SSH 会话可能断开！${NC}"
}

# -------------------------------
# 7. 清除指定 IP (Remove specified IP)
# -------------------------------
remove_ip_rule() {
    read -p "请输入要清除规则的 IP 地址: " ip_addr
    
    echo -e "${YELLOW}正在清除 IP: ${ip_addr} 的相关规则...${NC}"
    # 尝试删除所有 chain 中的相关规则 (A=Append, D=Delete)
    # 尝试删除 INPUT, OUTPUT, FORWARD 中的相关规则，通常只关注 INPUT
    iptables -D INPUT -s "$ip_addr" -j ACCEPT 2>/dev/null
    iptables -D INPUT -s "$ip_addr" -j DROP 2>/dev/null
    iptables -D INPUT -s "$ip_addr" -j REJECT 2>/dev/null
    
    echo -e "${GREEN}✅ IP: ${ip_addr} 的规则已清除。${NC}"
}

# -------------------------------
# 5/6. IP 白/黑名单 (IP Whitelist/Blacklist)
# -------------------------------
ip_management() {
    local action="$1" # 'WHITELIST' or 'BLACKLIST'
    read -p "请输入要添加到 ${action} 的 IP 地址或 IP 段 (如 1.1.1.1 或 1.1.1.0/24): " ip_addr
    
    if [ "$action" == "WHITELIST" ]; then
        # 白名单：在第一条插入 ACCEPT 规则，确保其优先于所有 DROP 规则
        iptables -I INPUT 1 -s "$ip_addr" -j ACCEPT
        echo -e "${GREEN}✅ IP: ${ip_addr} 已加入白名单 (ACCEPT)。${NC}"
    elif [ "$action" == "BLACKLIST" ]; then
        # 黑名单：追加 DROP 规则
        iptables -A INPUT -s "$ip_addr" -j DROP
        echo -e "${RED}🚫 IP: ${ip_addr} 已加入黑名单 (DROP)。${NC}"
    fi
}

# -------------------------------
# 11/12. 允许/禁止PING (Allow/Deny PING)
# -------------------------------
manage_ping() {
    local action="$1" # 'ALLOW' or 'DENY'
    if [ "$action" == "ALLOW" ]; then
        # 删除所有 DENY 规则（以防万一）
        iptables -D INPUT -p icmp --icmp-type echo-request -j DROP 2>/dev/null
        # 允许 PING
        iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
        echo -e "${GREEN}✅ PING 已允许。${NC}"
    elif [ "$action" == "DENY" ]; then
        # 禁止 PING
        iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
        echo -e "${RED}🚫 PING 已禁止。${NC}"
    fi
}

# -------------------------------
# 0. 返回上级选单 (Show Current Iptables)
# -------------------------------
show_iptables_status() {
    clear
    echo -e "${CYAN}=== 当前 Iptables 规则 (IPv4) ===${NC}"
    # 显示链的默认策略
    echo -e "${BLUE}Chain INPUT (policy $(iptables -L INPUT -n | awk 'NR==1 {print $4}'))${NC}"
    echo -e "${BLUE}Chain FORWARD (policy $(iptables -L FORWARD -n | awk 'NR==1 {print $4}'))${NC}"
    echo -e "${BLUE}Chain OUTPUT (policy $(iptables -L OUTPUT -n | awk 'NR==1 {print $4}'))${NC}"
    echo ""
    
    # 详细列出 INPUT 规则
    iptables -L INPUT -n --line-numbers
    echo -e "${CYAN}==================================${NC}"
}


# -------------------------------
# 防火墙持久化保存（Firewall Persistence Save）
# -------------------------------
save_iptables() {
    echo -e "${YELLOW}⚠️ 警告：Iptables 规则在重启后默认不会保存！${NC}"
    read -p "是否尝试持久化保存当前 Iptables 规则? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then return; fi
    
    if command -v iptables-save &>/dev/null; then
        echo -e "${YELLOW}正在尝试使用 iptables-persistent / netfilter-persistent 方式保存规则...${NC}"
        # 适用于 Debian/Ubuntu
        if [ -f /etc/debian_version ]; then
            iptables-save > /etc/iptables/rules.v4
            echo -e "${GREEN}✅ 规则已保存至 /etc/iptables/rules.v4${NC}"
        # 适用于 CentOS/RHEL
        elif [ -f /etc/redhat-release ]; then
            iptables-save > /etc/sysconfig/iptables
            echo -e "${GREEN}✅ 规则已保存至 /etc/sysconfig/iptables${NC}"
            
        else
            # 通用保存
            iptables-save > /etc/iptables.up.rules
            echo -e "${GREEN}✅ 规则已保存至 /etc/iptables.up.rules (可能需要手动配置启动加载) ${NC}"
        fi
        
        echo -e "${YELLOW}请确保您的系统已安装 iptables-persistent 或 netfilter-persistent 服务来自动加载规则。${NC}"
    else
        echo -e "${RED}❌ 错误：未找到 iptables-save 命令。无法保存规则。${NC}"
    fi
}


# -------------------------------
# 高级防火墙管理主菜单
# -------------------------------
advanced_firewall_management() {
    clear
    # 首先检查系统是否具备执行条件
    if ! check_firewall_system; then return; fi
    
    while true; do
        show_iptables_status # 每次显示前都打印状态
        
        echo -e "${CYAN}"
        echo "=========================================="
        echo "           高级防火墙管理 (Iptables)      "
        echo "=========================================="
        echo -e "${NC}"
        echo "  --- 端口管理 ---"
        echo "1. 开放指定端口        2. 关闭指定端口"
        echo "3. 开放所有端口        4. 关闭所有端口"
        echo "  --- IP 过滤 ---"
        echo "5. IP 白名单 (ACCEPT)  6. IP 黑名单 (DROP)"
        echo "7. 清除指定 IP 规则    8. 允许 PING"
        echo "9. 禁止 PING           10. 清空所有规则 (极度危险)"
        echo "  --- 规则操作 ---"
        echo "11. 保存当前规则 (持久化)  12. 重载已保存规则"
        echo "0. 返回系统工具菜单"
        echo "=========================================="
        
        read -p "请输入选项编号: " fw_choice
        
        case $fw_choice in
            1) open_port ;;
            2) close_port ;;
            3) open_all_ports ;;
            4) close_all_ports ;;
            5) ip_management "WHITELIST" ;;
            6) ip_management "BLACKLIST" ;;
            7) remove_ip_rule ;;
            8) manage_ping "ALLOW" ;;
            9) manage_ping "DENY" ;;
            10)
                echo -e "${RED}!!! 极度危险：清空所有规则将移除所有防火墙保护！ !!!${NC}"
                read -p "输入 'CONFIRM' 清空所有规则: " confirm_clear
                if [ "$confirm_clear" == "CONFIRM" ]; then
                    iptables -F # 清空所有规则
                    iptables -X # 清空所有自定义链
                    iptables -Z # 计数器清零
                    echo -e "${GREEN}✅ 所有 Iptables 规则已清空！${NC}"
                else
                    echo -e "${YELLOW}操作已取消。${NC}"
                fi
                ;;
            11) save_iptables ;;
            12)
                echo -e "${YELLOW}正在尝试加载已保存的规则...${NC}"
                if command -v iptables-restore &>/dev/null; then
                    # 适用于 Debian/Ubuntu
                    if [ -f /etc/iptables/rules.v4 ]; then
                        iptables-restore < /etc/iptables/rules.v4
                        echo -e "${GREEN}✅ 规则已从 /etc/iptables/rules.v4 加载。${NC}"
                    # 适用于 CentOS/RHEL
                    elif [ -f /etc/sysconfig/iptables ]; then
                        iptables-restore < /etc/sysconfig/iptables
                        echo -e "${GREEN}✅ 规则已从 /etc/sysconfig/iptables 加载。${NC}"
                    else
                        echo -e "${RED}❌ 未找到已保存的规则文件。${NC}"
                    fi
                else
                    echo -e "${RED}❌ 错误：未找到 iptables-restore 命令。${NC}"
                fi
                ;;
            0)
                echo -e "${YELLOW}返回系统工具菜单...${NC}"
                return
                ;;
            *)
                echo -e "${RED}无效的选项，请重新输入！${NC}"
                ;;
        esac
        
        read -p "按回车键继续..."
    done
}


# -------------------------------
# 系统工具菜单 (新增功能入口)
# -------------------------------
system_tools_menu() {
    while true; do
        clear
        echo -e "${CYAN}"
        echo "=========================================="
        echo "              系统工具菜单                "
        echo "=========================================="
        echo -e "${NC}"
        echo "1. 修改登录密码 (TODO)"
        echo "2. 修改 SSH 连接端口 (TODO)"
        echo "3. 切换优先 IPV4/IPV6 (TODO)"
        echo "4. 修改主机名 (TODO)"
        echo "5. 系统时区调整 (TODO)"
        echo "6. 修改虚拟内存大小 (Swap) (TODO)"
        echo "7. 重启服务器 (TODO)"
        echo "8. 卸载本脚本 (TODO)"
        echo ""
        echo "9. 高级防火墙管理"
        echo "0. 返回主菜单"
        echo "=========================================="

        read -p "请输入选项编号: " tools_choice

        case $tools_choice in
            1) echo -e "${YELLOW}功能 1 暂未实现。${NC}" ;;
            2) echo -e "${YELLOW}功能 2 暂未实现。${NC}" ;;
            3) echo -e "${YELLOW}功能 3 暂未实现。${NC}" ;;
            4) echo -e "${YELLOW}功能 4 暂未实现。${NC}" ;;
            5) echo -e "${YELLOW}功能 5 暂未实现。${NC}" ;;
            6) echo -e "${YELLOW}功能 6 暂未实现。${NC}" ;;
            7) echo -e "${YELLOW}功能 7 暂未实现。${NC}" ;;
            8) echo -e "${YELLOW}功能 8 暂未实现。${NC}" ;;
            9) advanced_firewall_management ;; # 调用新增的防火墙函数
            0) return ;;
            *)
                echo -e "${RED}无效的选项，请重新输入！${NC}"
                sleep 1
                ;;
        esac
        [ "$tools_choice" != "9" ] && [ "$tools_choice" != "0" ] && read -p "按回车键继续..."
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
        1) system_info ;;
        2) system_update ;;
        3) system_clean ;;
        4) basic_tools ;;
        5) bbr_management ;;
        6) docker_management_menu ;;
        7) system_tools_menu ;; # 调用系统工具菜单
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
# 修复：删除脚本末尾多余的 '}'
