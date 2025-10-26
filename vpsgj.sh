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


# ====================================================================
# +++ 高级防火墙管理功能 (新增) +++
# ====================================================================

# -------------------------------
# 依赖检查和安装 (iptables/ipset)
# -------------------------------
check_firewall_deps() {
    PKGS_FW="iptables iptables-persistent ipset"
    local needs_install=false
    for CMD in iptables ipset; do
        if ! command -v $CMD >/dev/null 2>&1; then
            needs_install=true
            break
        fi
    done

    if $needs_install; then
        echo -e "${YELLOW}未检测到 iptables/ipset，正在尝试安装...${NC}"
        if command -v apt >/dev/null 2>&1; then
            apt update -y
            apt install -y $PKGS_FW
            if command -v netfilter-persistent >/dev/null 2>&1; then
                # 针对Debian/Ubuntu，安装保存规则的工具
                echo -e "${GREEN}✅ 已安装 iptables-persistent (netfilter-persistent)${NC}"
            fi
        elif command -v yum >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
            if command -v yum >/dev/null 2>&1; then
                yum install -y $PKGS_FW
            else
                dnf install -y $PKGS_FW
            fi
        else
            echo -e "${RED}❌ 无法自动安装防火墙依赖。请手动安装: $PKGS_FW${NC}"
            read -p "按回车键返回..."
            return 1
        fi
        
        # 针对CentOS/RHEL，启用服务
        if command -v systemctl >/dev/null 2>&1 && systemctl status iptables &>/dev/null; then
             systemctl enable iptables; systemctl start iptables
        fi
        
        # 第一次安装后，设置默认策略
        if iptables -L INPUT -n | grep -q "Chain INPUT (policy ACCEPT)"; then
            echo -e "${YELLOW}正在设置默认防火墙规则...${NC}"
            save_iptables_rules
        fi
        
        return 0
    else
        return 0
    fi
}

# -------------------------------
# 保存 iptables 规则
# -------------------------------
save_iptables_rules() {
    echo -e "${YELLOW}正在保存 iptables 规则...${NC}"
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save
    elif command -v iptables-save >/dev/null 2>&1; then
        # 适用于大多数系统
        iptables-save > /etc/iptables/rules.v4 2>/dev/null
        if [ $? -ne 0 ]; then
            iptables-save > /etc/sysconfig/iptables 2>/dev/null
        fi
    fi
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ iptables 规则保存成功！${NC}"
    else
        echo -e "${RED}❌ 规则保存失败，请检查系统是否支持 iptables-persistent 或 systemd/init.d 机制。${NC}"
    fi
}

# -------------------------------
# 显示防火墙状态 (菜单顶部)
# -------------------------------
show_firewall_status() {
    echo -e "${CYAN}=========================================="
    echo "          高级防火墙管理状态              "
    echo "=========================================="
    echo -e "${NC}"
    echo -e "${BLUE}Chain INPUT (policy ${YELLOW}$(iptables -L INPUT -n | grep 'Chain INPUT' | awk '{print $4}' | tr -d '()' )${NC}${BLUE})${NC}"
    echo "target     prot opt source               destination"
    # 只显示前几条自定义规则
    iptables -L INPUT -n --line-numbers | head -n 10
    echo ""
}

# -------------------------------
# 1. 开放指定端口
# -------------------------------
open_specified_port() {
    read -p "请输入要开放的端口号 (e.g., 80, 22, 3000-3005): " PORT
    read -p "请输入协议 (tcp/udp, 默认tcp): " PROTO
    PROTO=${PROTO:-tcp}
    
    echo -e "${YELLOW}正在开放 ${PORT}/${PROTO}...${NC}"
    
    if iptables -C INPUT -p "$PROTO" --dport "$PORT" -j ACCEPT 2>/dev/null; then
        echo -e "${YELLOW}⚠️ 端口 ${PORT}/${PROTO} 已开放，跳过。${NC}"
    else
        iptables -I INPUT -p "$PROTO" --dport "$PORT" -j ACCEPT
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ 端口 ${PORT}/${PROTO} 开放成功。${NC}"
            save_iptables_rules
        else
            echo -e "${RED}❌ 开放端口失败。${NC}"
        fi
    fi
}

# -------------------------------
# 2. 关闭指定端口
# -------------------------------
close_specified_port() {
    read -p "请输入要关闭的端口号 (e.g., 80, 22): " PORT
    read -p "请输入协议 (tcp/udp, 默认tcp): " PROTO
    PROTO=${PROTO:-tcp}

    echo -e "${YELLOW}正在关闭 ${PORT}/${PROTO}...${NC}"
    
    # 尝试删除规则，如果存在
    if iptables -D INPUT -p "$PROTO" --dport "$PORT" -j ACCEPT 2>/dev/null; then
        echo -e "${GREEN}✅ 端口 ${PORT}/${PROTO} 关闭成功 (ACCEPT规则已移除)。${NC}"
        save_iptables_rules
    else
        echo -e "${YELLOW}⚠️ 未找到端口 ${PORT}/${PROTO} 的开放规则，操作完成。${NC}"
    fi
}

# -------------------------------
# 3. 开放所有端口 (设置默认策略为ACCEPT)
# -------------------------------
open_all_ports() {
    echo -e "${RED}!!! 警告：此操作将允许所有传入连接，非常不安全！ !!!${NC}"
    read -p "输入 'yes' 确认开放所有端口: " confirm
    if [ "$confirm" == "yes" ]; then
        echo -e "${YELLOW}正在设置 INPUT 链默认策略为 ACCEPT...${NC}"
        iptables -P INPUT ACCEPT
        iptables -P FORWARD ACCEPT
        iptables -P OUTPUT ACCEPT
        iptables -F # 清空所有规则
        save_iptables_rules
        echo -e "${GREEN}✅ 所有端口已开放，防火墙已禁用。${NC}"
    else
        echo -e "${GREEN}已取消操作。${NC}"
    fi
}

# -------------------------------
# 4. 关闭所有端口 (设置默认策略为DROP)
# -------------------------------
close_all_ports() {
    echo -e "${RED}!!! 警告：此操作将断开您的 SSH 连接！请确保您已添加 SSH 端口的 ACCEPT 规则！ !!!${NC}"
    read -p "输入 'yes' 确认关闭所有端口: " confirm
    if [ "$confirm" == "yes" ]; then
        # 0. 获取当前SSH端口
        local ssh_port=$(grep -E '^\s*Port\s+[0-9]+' /etc/ssh/sshd_config | awk '{print $2}' | head -1)
        ssh_port=${ssh_port:-22}
        
        echo -e "${YELLOW}正在清空所有规则并设置默认策略为 DROP...${NC}"
        
        # 1. 清空所有规则
        iptables -F
        
        # 2. 确保 SSH 端口开放（防止失联）
        iptables -A INPUT -p tcp --dport "$ssh_port" -j ACCEPT
        iptables -A INPUT -p tcp --dport "22" -j ACCEPT
        
        # 3. 允许本地回环
        iptables -A INPUT -i lo -j ACCEPT
        
        # 4. 允许已建立的连接
        iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
        
        # 5. 设置默认策略为 DROP
        iptables -P INPUT DROP
        iptables -P FORWARD DROP
        iptables -P OUTPUT ACCEPT # OUTPUT通常保持ACCEPT以保证正常对外访问
        
        save_iptables_rules
        echo -e "${GREEN}✅ 所有端口已关闭，SSH(tcp/$ssh_port) 端口已保留。${NC}"
    else
        echo -e "${GREEN}已取消操作。${NC}"
    fi
}

# -------------------------------
# 5/6. IP 白名单/黑名单 辅助函数
# -------------------------------
manage_ip_set() {
    local set_name="$1"
    local ip_or_cidr="$2"
    local action="$3" # add or del
    
    if ! ipset list "$set_name" &>/dev/null; then
        echo -e "${YELLOW}创建 IPset 集合 $set_name...${NC}"
        ipset create "$set_name" hash:net
        # 针对黑名单，确保 iptables 规则存在 (DROP)
        if [ "$set_name" == "IP_BLACKLIST" ]; then
            if ! iptables -C INPUT -m set --match-set "$set_name" src -j DROP 2>/dev/null; then
                iptables -I INPUT -m set --match-set "$set_name" src -j DROP
                save_iptables_rules
            fi
        # 针对白名单，确保 iptables 规则存在 (ACCEPT)
        elif [ "$set_name" == "IP_WHITELIST" ]; then
            if ! iptables -C INPUT -m set --match-set "$set_name" src -j ACCEPT 2>/dev/null; then
                iptables -I INPUT -m set --match-set "$set_name" src -j ACCEPT
                save_iptables_rules
            fi
        fi
    fi
    
    echo -e "${YELLOW}正在 ${action} IP/CIDR ${ip_or_cidr} 到 $set_name...${NC}"
    if ipset "$action" "$set_name" "$ip_or_cidr" 2>/dev/null; then
        echo -e "${GREEN}✅ 操作成功。${NC}"
        ipset save > /etc/ipset/rules.v4 2>/dev/null # 保存 ipset 规则
    else
        echo -e "${RED}❌ 操作失败，请检查 IP/CIDR 格式。${NC}"
    fi
}

# 5. IP 白名单
ip_whitelist() {
    read -p "请输入要添加到白名单的 IP 地址或 CIDR (e.g., 1.1.1.1 或 1.1.1.0/24): " IP
    manage_ip_set "IP_WHITELIST" "$IP" "add"
}

# 6. IP 黑名单
ip_blacklist() {
    read -p "请输入要添加到黑名单的 IP 地址或 CIDR (e.g., 2.2.2.2 或 2.2.2.0/24): " IP
    manage_ip_set "IP_BLACKLIST" "$IP" "add"
}

# 7. 清除指定 IP
clear_specified_ip() {
    read -p "请输入要清除的 IP 地址或 CIDR: " IP
    
    if ipset del "IP_WHITELIST" "$IP" 2>/dev/null; then
        echo -e "${GREEN}✅ IP ${IP} 已从白名单中清除。${NC}"
    fi
    
    if ipset del "IP_BLACKLIST" "$IP" 2>/dev/null; then
        echo -e "${GREEN}✅ IP ${IP} 已从黑名单中清除。${NC}"
    fi
    
    if [ $? -eq 0 ]; then
        ipset save > /etc/ipset/rules.v4 2>/dev/null
    else
        echo -e "${YELLOW}⚠️ IP ${IP} 不在任何列表中。${NC}"
    fi
}

# -------------------------------
# 11/12. 允许/禁止 PING
# -------------------------------
# 辅助函数: 检查和移除 PING 规则
remove_ping_rule() {
    local chain="$1"
    # 查找并删除所有 icmp-echo-request 规则
    iptables -L "$chain" --line-numbers -n | grep "icmp.*echo-request" | sort -nr | while read -r LINE; do
        local num=$(echo "$LINE" | awk '{print $1}')
        if [[ "$num" =~ ^[0-9]+$ ]]; then
            iptables -D "$chain" "$num"
        fi
    done
}

# 11. 允许 PING
allow_ping() {
    echo -e "${YELLOW}正在设置允许 PING (ICMP Echo Request)...${NC}"
    remove_ping_rule "INPUT" # 先清除所有 PING 规则
    iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ PING 已允许。${NC}"
        save_iptables_rules
    else
        echo -e "${RED}❌ 允许 PING 失败。${NC}"
    fi
}

# 12. 禁止 PING
forbid_ping() {
    echo -e "${YELLOW}正在设置禁止 PING (ICMP Echo Request)...${NC}"
    remove_ping_rule "INPUT" # 先清除所有 PING 规则
    # 将 DROP 规则插入到链的顶部
    iptables -I INPUT -p icmp --icmp-type echo-request -j DROP
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ PING 已禁止。${NC}"
        save_iptables_rules
    else
        echo -e "${RED}❌ 禁止 PING 失败。${NC}"
    fi
}

# -------------------------------
# 13/14. DDOS 防御 (简易)
# -------------------------------
# 辅助函数: 检查和清除 DDOS 规则
remove_ddos_rules() {
    # 移除 syn-flood 规则
    iptables -D INPUT -p tcp --syn -m limit --limit 1/s --limit-burst 3 -j ACCEPT 2>/dev/null
    iptables -D INPUT -p tcp --syn -j DROP 2>/dev/null
    # 移除单个 IP 连接数限制规则
    iptables -D INPUT -p tcp -m connlimit --connlimit-above 50 --connlimit-mask 32 -j REJECT --reject-with tcp-reset 2>/dev/null
    # 移除单个 IP 新连接速率限制规则
    iptables -D INPUT -p tcp --syn -m connlimit --connlimit-above 20 --connlimit-mask 32 -j DROP 2>/dev/null
}

# 13. 启动 DDOS 防御
start_ddos_protection() {
    echo -e "${YELLOW}正在启动简易 DDOS 防御 (限制 SYN/连接数)...${NC}"
    
    # 1. SYN-Flood 防御 (限制每秒 1 个新连接，爆发 3 个)
    iptables -A INPUT -p tcp --syn -m limit --limit 1/s --limit-burst 3 -j ACCEPT
    iptables -A INPUT -p tcp --syn -j DROP
    
    # 2. 限制单个 IP 的总连接数 (超过 50 个连接的 IP)
    iptables -A INPUT -p tcp -m connlimit --connlimit-above 50 --connlimit-mask 32 -j REJECT --reject-with tcp-reset
    
    # 3. 限制单个 IP 的新连接速率 (每秒 20 个新连接)
    iptables -A INPUT -p tcp --syn -m connlimit --connlimit-above 20 --connlimit-mask 32 -j DROP
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 简易 DDOS 防御已启动。${NC}"
        save_iptables_rules
    else
        echo -e "${RED}❌ 启动 DDOS 防御失败。${NC}"
        remove_ddos_rules # 失败后尝试回滚
    fi
}

# 14. 关闭 DDOS 防御
close_ddos_protection() {
    echo -e "${YELLOW}正在关闭 DDOS 防御...${NC}"
    remove_ddos_rules
    save_iptables_rules
    echo -e "${GREEN}✅ DDOS 防御规则已清除。${NC}"
}

# -------------------------------
# 15/16/17. 国家 IP 限制
# -------------------------------

# 国家 IP 限制辅助函数
manage_country_ip() {
    local action="$1" # block/allow/clear
    local country_code
    local set_name="COUNTRY_SET"
    local geoip_url="https://raw.githubusercontent.com/ip2location/ip2location-country-blocklists/master/firewall/iptables/$country_code.net"

    if [ "$action" != "clear" ]; then
        read -p "请输入国家代码 (e.g., CN, US, RU): " country_code
        if [ -z "$country_code" ]; then
            echo -e "${RED}❌ 国家代码不能为空。${NC}"; return
        fi
        
        local ip_list_file="/tmp/${country_code}_ip.txt"
        echo -e "${YELLOW}正在下载 ${country_code} 的 IP 列表...${NC}"
        wget -qO "$ip_list_file" "https://raw.githubusercontent.com/ip2location/ip2location-country-blocklists/master/firewall/iptables/${country_code}.net"
        
        if [ ! -f "$ip_list_file" ] || [ ! -s "$ip_list_file" ]; then
            echo -e "${RED}❌ 下载 IP 列表失败或文件为空。${NC}"; return
        fi
    fi
    
    # 核心 IPSET 和 IPTABLES 规则设置
    if ! ipset list "$set_name" &>/dev/null; then
        ipset create "$set_name" hash:net
    fi

    if [ "$action" == "block" ]; then
        echo -e "${YELLOW}正在添加 ${country_code} 到 IPset 并设置 DROP 规则...${NC}"
        # 1. 导入 IP 到 IPset
        cat "$ip_list_file" | grep -v '^#' | while read -r IP_CIDR; do
            if [ -n "$IP_CIDR" ]; then ipset add "$set_name" "$IP_CIDR" 2>/dev/null; fi
        done
        # 2. 设置 IPTABLES 规则 (DROP)
        if ! iptables -C INPUT -m set --match-set "$set_name" src -j DROP 2>/dev/null; then
            # 插入到 INPUT 链的靠前位置
            iptables -I INPUT 2 -m set --match-set "$set_name" src -j DROP
            echo -e "${GREEN}✅ 国家 ${country_code} 已被成功阻止。${NC}"
        fi
    elif [ "$action" == "allow" ]; then
        echo -e "${YELLOW}正在设置仅允许 ${country_code} 访问...${NC}"
        # 1. 导入 IP 到 IPset
        cat "$ip_list_file" | grep -v '^#' | while read -r IP_CIDR; do
            if [ -n "$IP_CIDR" ]; then ipset add "$set_name" "$IP_CIDR" 2>/dev/null; fi
        done
        # 2. 设置 IPTABLES 规则 (DROP 其他所有 IP)
        # 必须先添加允许规则，再设置默认策略为 DROP
        if ! iptables -C INPUT -m set --match-set "$set_name" src -j ACCEPT 2>/dev/null; then
            iptables -I INPUT 1 -m set --match-set "$set_name" src -j ACCEPT
        fi
        
        # 3. 设置默认策略为 DROP（如果 INPUT 策略不是 DROP）
        if ! iptables -L INPUT -n | grep 'Chain INPUT' | grep -q "policy DROP"; then
            echo -e "${RED}!!! 警告：设置默认策略为 DROP，仅 ${country_code} 可访问！${NC}"
            read -p "输入 'yes' 确认设置: " confirm_drop
            if [ "$confirm_drop" == "yes" ]; then
                 # 确保 SSH 和 ESTABLISHED/RELATED 规则在 DROP 之前
                 close_all_ports # 此函数会先设置 SSH 规则，然后设置 DROP
                 echo -e "${GREEN}✅ 已设置 INPUT 链默认 DROP，且仅 ${country_code} IP 可访问。${NC}"
            else
                echo -e "${YELLOW}已取消设置默认 DROP 策略。${NC}"
                return
            fi
        fi
    fi
    
    # 清理
    rm -f "$ip_list_file"
    save_iptables_rules
    ipset save > /etc/ipset/rules.v4 2>/dev/null
}

# 15. 阻止指定国家 IP
block_country_ip() {
    manage_country_ip "block"
}

# 16. 仅允许指定国家 IP
allow_only_country_ip() {
    manage_country_ip "allow"
}

# 17. 解除指定国家 IP 限制
clear_country_ip_restriction() {
    echo -e "${YELLOW}正在清除所有国家/地区 IP 限制规则和集合...${NC}"
    
    # 1. 删除 iptables 中与 COUNTRY_SET 相关的规则
    if iptables -D INPUT -m set --match-set COUNTRY_SET src -j DROP 2>/dev/null; then
        echo -e "${GREEN}✅ DROP 规则已删除。${NC}"
    fi
    if iptables -D INPUT -m set --match-set COUNTRY_SET src -j ACCEPT 2>/dev/null; then
        echo -e "${GREEN}✅ ACCEPT 规则已删除。${NC}"
    fi

    # 2. 销毁 IPset 集合
    if ipset destroy COUNTRY_SET 2>/dev/null; then
        echo -e "${GREEN}✅ IPset 集合 COUNTRY_SET 已销毁。${NC}"
    else
        echo -e "${YELLOW}⚠️ IPset 集合不存在或已被清除。${NC}"
    fi

    save_iptables_rules
    ipset save > /etc/ipset/rules.v4 2>/dev/null
    read -p "按回车键返回..."
}

# -------------------------------
# 高级防火墙管理主菜单
# -------------------------------
firewall_management_menu() {
    # 确保依赖已安装
    if ! check_firewall_deps; then
        read -p "依赖安装失败，按回车键返回主菜单..."
        return
    fi
    
    while true; do
        clear
        show_firewall_status # 显示当前规则和策略
        echo "------------------------------------------"
        echo "1. 开放指定端口        2. 关闭指定端口"
        echo "3. 开放所有端口        4. 关闭所有端口"
        echo "------------------------------------------"
        echo "5. IP 白名单           6. IP 黑名单"
        echo "7. 清除指定 IP         "
        echo "------------------------------------------"
        echo "11. 允许 PING           12. 禁止 PING"
        echo "13. 启动 DDOS 防御      14. 关闭 DDOS 防御"
        echo "------------------------------------------"
        echo "15. 阻止指定国家 IP     16. 仅允许指定国家 IP"
        echo "17. 解除指定国家 IP 限制"
        echo "------------------------------------------"
        echo "0. 返回上一级选单"
        echo "------------------------------------------"
        read -p "请输入你的选择: " fw_choice

        case $fw_choice in
            1) open_specified_port ;;
            2) close_specified_port ;;
            3) open_all_ports ;;
            4) close_all_ports ;;
            5) ip_whitelist ;;
            6) ip_blacklist ;;
            7) clear_specified_ip ;;
            11) allow_ping ;;
            12) forbid_ping ;;
            13) start_ddos_protection ;;
            14) close_ddos_protection ;;
            15) block_country_ip ;;
            16) allow_only_country_ip ;;
            17) clear_country_ip_restriction ;;
            0) return ;;
            *) echo -e "${RED}无效的选项，请重新输入！${NC}"; sleep 1 ;;
        esac
        # 确保每个操作后能看到结果
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
