#!/bin/bash
# 增强版VPS工具箱 v3.1
# GitHub: https://github.com/chengege666/bbr-gj

RESULT_FILE="bbr_result.txt"
SCRIPT_FILE="vps_toolbox.sh"
UNINSTALL_NOTE="vps_toolbox_uninstall_done.txt"

# -------------------------------
# 颜色定义与欢迎窗口
# -------------------------------
RED="\033[1;31m"        # 主要使用红色
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
MAGENTA="\033[1;35m"
CYAN="\033[1;36m"
BLUE="\033[1;34m"
WHITE="\033[1;37m"
RESET="\033[0m"

print_welcome() {
    clear
    echo -e "${CYAN}==================================================${RESET}"
    echo -e "${MAGENTA}                VPS 工具箱 v3.1                ${RESET}"
    echo -e "${CYAN}--------------------------------------------------${RESET}"
    echo -e "${RED}功能: BBR测速, 系统管理, 防火墙管理, Docker, SSH配置等${RESET}"
    echo -e "${GREEN}测速结果保存: ${RESULT_FILE}${RESET}"
    echo -e "${CYAN}==================================================${RESET}"
    echo ""
}

# -------------------------------
# 获取当前开放的端口
# -------------------------------
get_open_ports() {
    echo -e "${RED}当前开放的端口:${RESET}"
    
    FIREWALL_TOOL=$(detect_firewall_tool)
    case $FIREWALL_TOOL in
        ufw)
            ufw status | grep "ALLOW" | while read line; do
                port=$(echo "$line" | awk '{print $1}')
                proto=$(echo "$line" | grep -o "tcp\|udp" | head -1)
                if [ -n "$port" ]; then
                    echo -e "${RED}$port/$proto${RESET}"
                fi
            done
            ;;
        firewalld)
            firewall-cmd --list-ports 2>/dev/null | tr ' ' '\n' | while read port; do
                if [ -n "$port" ]; then
                    echo -e "${RED}$port${RESET}"
                fi
            done
            ;;
        iptables)
            iptables -L INPUT -n | grep "dpt:" | while read line; do
                port=$(echo "$line" | grep -o "dpt:[0-9]*" | cut -d: -f2)
                proto=$(echo "$line" | grep -o "tcp\|udp")
                if [ -n "$port" ] && [ -n "$proto" ]; then
                    # 检查是否是ACCEPT规则
                    if echo "$line" | grep -q "ACCEPT"; then
                        echo -e "${RED}$port/$proto${RESET}"
                    fi
                fi
            done
            ;;
        *)
            echo -e "${YELLOW}无法检测防火墙工具${RESET}"
            ;;
    esac
    
    # 显示监听端口
    echo -e "${RED}系统监听中的端口:${RESET}"
    netstat -tuln | grep "LISTEN" | awk '{print $4}' | awk -F: '{print $NF}' | sort -un | while read port; do
        echo -e "${RED}$port${RESET}"
    done | head -10
}

# -------------------------------
# 防火墙管理菜单 (红色主题)
# -------------------------------
firewall_management_menu() {
    while true; do
        clear
        echo -e "${RED}==================================================${RESET}"
        echo -e "${RED}                 防火墙管理                 ${RESET}"
        echo -e "${RED}--------------------------------------------------${RESET}"
        
        # 显示当前开放的端口
        get_open_ports
        echo -e "${RED}--------------------------------------------------${RESET}"
        
        echo -e "${RED}1. 开放指定端口${RESET}                 ${RED}2. 关闭指定端口${RESET}"
        echo -e "${RED}3. 开放所有端口${RESET}                 ${RED}4. 关闭所有端口${RESET}"
        echo -e "${RED}5. IP白名单${RESET}                     ${RED}6. IP黑名单${RESET}"
        echo -e "${RED}7. 清除指定IP${RESET}                   ${RED}8. 查看当前规则${RESET}"
        echo -e "${RED}9. 备份防火墙规则${RESET}               ${RED}10. 恢复防火墙规则${RESET}"
        echo -e "${RED}11. 允许PING${RESET}                    ${RED}12. 禁止PING${RESET}"
        echo -e "${RED}13. 启动DDOS防御${RESET}               ${RED}14. 关闭DDOS防御${RESET}"
        echo -e "${RED}15. 阻止指定国家IP${RESET}             ${RED}16. 仅允许指定国家IP${RESET}"
        echo -e "${RED}17. 解除指定国家IP限制${RESET}         ${RED}18. 防火墙状态查看${RESET}"
        echo -e "${RED}0. 返回上一级选单${RESET}"
        echo -e "${RED}--------------------------------------------------${RESET}"
        read -p "请输入你的选择: " firewall_choice

        case $firewall_choice in
            1) open_specific_port ;;
            2) close_specific_port ;;
            3) open_all_ports ;;
            4) close_all_ports ;;
            5) ip_whitelist ;;
            6) ip_blacklist ;;
            7) clear_specific_ip ;;
            8) show_firewall_rules ;;
            9) backup_firewall_rules ;;
            10) restore_firewall_rules ;;
            11) allow_ping ;;
            12) deny_ping ;;
            13) enable_ddos_protection ;;
            14) disable_ddos_protection ;;
            15) block_country_ip ;;
            16) allow_only_country_ip ;;
            17) unblock_country_ip ;;
            18) show_firewall_status ;;
            0) return ;;
            *) echo -e "${RED}无效选择，请重新输入${RESET}"; sleep 2 ;;
        esac
    done
}

# 检测防火墙工具
detect_firewall_tool() {
    if command -v ufw >/dev/null 2>&1 && systemctl is-active ufw >/dev/null 2>&1; then
        echo "ufw"
    elif command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active firewalld >/dev/null 2>&1; then
        echo "firewalld"
    elif command -v iptables >/dev/null 2>&1; then
        echo "iptables"
    else
        echo "unknown"
    fi
}

# 1. 开放指定端口
open_specific_port() {
    echo -e "${RED}>>> 开放指定端口${RESET}"
    read -p "请输入要开放的端口号: " port
    
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo -e "${RED}❌ 端口号无效${RESET}"
        read -n1 -p "按任意键继续..."
        return
    fi
    
    read -p "请输入协议 (tcp/udp，默认tcp): " protocol
    protocol=${protocol:-tcp}
    
    FIREWALL_TOOL=$(detect_firewall_tool)
    case $FIREWALL_TOOL in
        ufw)
            ufw allow $port/$protocol
            ufw reload
            ;;
        firewalld)
            firewall-cmd --permanent --add-port=$port/$protocol
            firewall-cmd --reload
            ;;
        iptables)
            iptables -A INPUT -p $protocol --dport $port -j ACCEPT
            # 尝试保存规则
            if command -v iptables-save >/dev/null 2>&1; then
                iptables-save > /etc/iptables.rules 2>/dev/null
            fi
            ;;
        *)
            echo -e "${RED}不支持的防火墙工具${RESET}"
            read -n1 -p "按任意键继续..."
            return 1
            ;;
    esac
    
    echo -e "${RED}✅ 端口 $port/$protocol 已开放${RESET}"
    read -n1 -p "按任意键继续..."
}

# 2. 关闭指定端口
close_specific_port() {
    echo -e "${RED}>>> 关闭指定端口${RESET}"
    read -p "请输入要关闭的端口号: " port
    
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo -e "${RED}❌ 端口号无效${RESET}"
        read -n1 -p "按任意键继续..."
        return
    fi
    
    read -p "请输入协议 (tcp/udp，默认tcp): " protocol
    protocol=${protocol:-tcp}
    
    FIREWALL_TOOL=$(detect_firewall_tool)
    case $FIREWALL_TOOL in
        ufw)
            ufw delete allow $port/$protocol
            ufw reload
            ;;
        firewalld)
            firewall-cmd --permanent --remove-port=$port/$protocol
            firewall-cmd --reload
            ;;
        iptables)
            iptables -D INPUT -p $protocol --dport $port -j ACCEPT 2>/dev/null
            # 尝试保存规则
            if command -v iptables-save >/dev/null 2>&1; then
                iptables-save > /etc/iptables.rules 2>/dev/null
            fi
            ;;
        *)
            echo -e "${RED}不支持的防火墙工具${RESET}"
            read -n1 -p "按任意键继续..."
            return 1
            ;;
    esac
    
    echo -e "${RED}✅ 端口 $port/$protocol 已关闭${RESET}"
    read -n1 -p "按任意键继续..."
}

# 3. 开放所有端口
open_all_ports() {
    echo -e "${RED}⚠️ 警告：这将开放所有端口，存在安全风险！${RESET}"
    read -p "确定要开放所有端口吗？(y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${RED}已取消操作${RESET}"
        read -n1 -p "按任意键继续..."
        return
    fi
    
    FIREWALL_TOOL=$(detect_firewall_tool)
    case $FIREWALL_TOOL in
        ufw)
            ufw --force reset
            ufw default allow incoming
            ufw default allow outgoing
            ufw --force enable
            ;;
        firewalld)
            firewall-cmd --set-default-zone=public
            firewall-cmd --reload
            ;;
        iptables)
            iptables -P INPUT ACCEPT
            iptables -P FORWARD ACCEPT
            iptables -P OUTPUT ACCEPT
            iptables -F
            ;;
    esac
    
    echo -e "${RED}✅ 所有端口已开放${RESET}"
    read -n1 -p "按任意键继续..."
}

# 4. 关闭所有端口
close_all_ports() {
    echo -e "${RED}⚠️ 警告：这将关闭所有端口，可能导致无法远程连接！${RESET}"
    echo -e "${RED}⚠️ 请确保已开放SSH端口，否则会断开连接！${RESET}"
    read -p "确定要关闭所有端口吗？(y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${RED}已取消操作${RESET}"
        read -n1 -p "按任意键继续..."
        return
    fi
    
    FIREWALL_TOOL=$(detect_firewall_tool)
    case $FIREWALL_TOOL in
        ufw)
            ufw --force reset
            ufw default deny incoming
            ufw default allow outgoing
            ufw --force enable
            ;;
        firewalld)
            firewall-cmd --set-default-zone=drop
            firewall-cmd --reload
            ;;
        iptables)
            iptables -P INPUT DROP
            iptables -P FORWARD DROP
            iptables -P OUTPUT ACCEPT
            iptables -A INPUT -i lo -j ACCEPT
            iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
            ;;
    esac
    
    echo -e "${RED}✅ 所有端口已关闭（除已建立的连接）${RESET}"
    read -n1 -p "按任意键继续..."
}

# 5. IP白名单
ip_whitelist() {
    echo -e "${RED}>>> 添加IP白名单${RESET}"
    read -p "请输入要加入白名单的IP地址: " ip
    
    # 简单的IP验证
    if ! [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}❌ IP地址格式无效${RESET}"
        read -n1 -p "按任意键继续..."
        return
    fi
    
    FIREWALL_TOOL=$(detect_firewall_tool)
    case $FIREWALL_TOOL in
        ufw)
            ufw allow from $ip
            ufw reload
            ;;
        firewalld)
            firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='$ip' accept"
            firewall-cmd --reload
            ;;
        iptables)
            iptables -A INPUT -s $ip -j ACCEPT
            ;;
    esac
    
    echo -e "${RED}✅ IP $ip 已加入白名单${RESET}"
    read -n1 -p "按任意键继续..."
}

# 6. IP黑名单
ip_blacklist() {
    echo -e "${RED}>>> 添加IP黑名单${RESET}"
    read -p "请输入要加入黑名单的IP地址: " ip
    
    # 简单的IP验证
    if ! [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}❌ IP地址格式无效${RESET}"
        read -n1 -p "按任意键继续..."
        return
    fi
    
    FIREWALL_TOOL=$(detect_firewall_tool)
    case $FIREWALL_TOOL in
        ufw)
            ufw deny from $ip
            ufw reload
            ;;
        firewalld)
            firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='$ip' drop"
            firewall-cmd --reload
            ;;
        iptables)
            iptables -A INPUT -s $ip -j DROP
            ;;
    esac
    
    echo -e "${RED}✅ IP $ip 已加入黑名单${RESET}"
    read -n1 -p "按任意键继续..."
}

# 7. 清除指定IP
clear_specific_ip() {
    echo -e "${RED}>>> 清除指定IP规则${RESET}"
    read -p "请输入要清除的IP地址: " ip
    
    FIREWALL_TOOL=$(detect_firewall_tool)
    case $FIREWALL_TOOL in
        ufw)
            ufw delete deny from $ip 2>/dev/null
            ufw delete allow from $ip 2>/dev/null
            ufw reload
            ;;
        firewalld)
            firewall-cmd --permanent --remove-rich-rule="rule family='ipv4' source address='$ip' accept" 2>/dev/null
            firewall-cmd --permanent --remove-rich-rule="rule family='ipv4' source address='$ip' drop" 2>/dev/null
            firewall-cmd --reload
            ;;
        iptables)
            iptables -D INPUT -s $ip -j ACCEPT 2>/dev/null
            iptables -D INPUT -s $ip -j DROP 2>/dev/null
            ;;
    esac
    
    echo -e "${RED}✅ IP $ip 的规则已清除${RESET}"
    read -n1 -p "按任意键继续..."
}

# 8. 查看当前规则
show_firewall_rules() {
    echo -e "${RED}>>> 当前防火墙规则${RESET}"
    
    FIREWALL_TOOL=$(detect_firewall_tool)
    case $FIREWALL_TOOL in
        ufw)
            ufw status verbose
            ;;
        firewalld)
            firewall-cmd --list-all
            ;;
        iptables)
            iptables -L -n --line-numbers
            ;;
    esac
    
    read -n1 -p "按任意键继续..."
}

# 9. 备份防火墙规则
backup_firewall_rules() {
    echo -e "${RED}>>> 备份防火墙规则${RESET}"
    backup_file="firewall_backup_$(date +%Y%m%d_%H%M%S).rules"
    
    FIREWALL_TOOL=$(detect_firewall_tool)
    case $FIREWALL_TOOL in
        ufw)
            ufw status numbered > $backup_file
            ;;
        firewalld)
            firewall-cmd --runtime-to-permanent
            cp /etc/firewalld/firewalld.conf $backup_file
            ;;
        iptables)
            iptables-save > $backup_file 2>/dev/null
            ;;
    esac
    
    if [ -f "$backup_file" ]; then
        echo -e "${RED}✅ 防火墙规则已备份到: $backup_file${RESET}"
    else
        echo -e "${RED}❌ 备份失败${RESET}"
    fi
    read -n1 -p "按任意键继续..."
}

# 10. 恢复防火墙规则
restore_firewall_rules() {
    echo -e "${RED}>>> 恢复防火墙规则${RESET}"
    read -p "请输入备份文件名: " backup_file
    
    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}❌ 备份文件不存在${RESET}"
        read -n1 -p "按任意键继续..."
        return 1
    fi
    
    FIREWALL_TOOL=$(detect_firewall_tool)
    case $FIREWALL_TOOL in
        ufw)
            echo -e "${RED}请手动处理UFW备份恢复${RESET}"
            ;;
        iptables)
            iptables-restore < $backup_file 2>/dev/null
            ;;
    esac
    
    echo -e "${RED}✅ 防火墙规则已恢复${RESET}"
    read -n1 -p "按任意键继续..."
}

# 11. 允许PING
allow_ping() {
    echo -e "${RED}>>> 允许PING响应${RESET}"
    
    FIREWALL_TOOL=$(detect_firewall_tool)
    case $FIREWALL_TOOL 在
        ufw)
            ufw allow 在 on any to any proto icmp
            ufw reload
            ;;
        firewalld)
            firewall-cmd --permanent --add-icmp-block-inversion
            firewall-cmd --reload
            ;;
        iptables)
            iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
            ;;
    esac
    
    echo -e "${RED}✅ 已允许PING${RESET}"
    read -n1 -p "按任意键继续..."
}

# 12. 禁止PING
deny_ping() {
    echo -e "${RED}>>> 禁止PING响应${RESET}"
    
    FIREWALL_TOOL=$(detect_firewall_tool)
    case $FIREWALL_TOOL in
        ufw)
            ufw deny 在 on any to any proto icmp
            ufw reload
            ;;
        firewalld)
            firewall-cmd --permanent --remove-icmp-block-inversion
            firewall-cmd --reload
            ;;
        iptables)
            iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
            ;;
    esac
    
    echo -e "${RED}✅ 已禁止PING${RESET}"
    read -n1 -p "按任意键继续..."
}

# 13. 启动DDOS防御
enable_ddos_protection() {
    echo -e "${RED}>>> 启动DDOS防御${RESET}"
    
    # 简单的DDOS防护规则
    iptables -N DDOS_PROTECT 2>/dev/null
    iptables -F DDOS_PROTECT
    
    # 限制连接数
    iptables -A DDOS_PROTECT -p tcp --syn -m limit --limit 1/s -j ACCEPT
    iptables -A DDOS_PROTECT -p tcp --syn -j DROP
    iptables -A DDOS_PROTECT -p tcp --tcp-flags FIN,SYN,RST,ACK RST -m limit --limit 1/s -j ACCEPT
    
    # 应用到INPUT链
    iptables -I INPUT -p tcp -j DDOS_PROTECT
    
    echo -e "${RED}✅ DDOS防御已启动${RESET}"
    read -n1 -p "按任意键继续..."
}

# 14. 关闭DDOS防御
disable_ddos_protection() {
    echo -e "${RED}>>> 关闭DDOS防御${RESET}"
    
    iptables -D INPUT -p tcp -j DDOS_PROTECT 2>/dev/null
    iptables -F DDOS_PROTECT 2>/dev/null
    iptables -X DDOS_PROTECT 2>/dev/null
    
    echo -e "${RED}✅ DDOS防御已关闭${RESET}"
    read -n1 -p "按任意键继续..."
}

# 15. 阻止指定国家IP
block_country_ip() {
    echo -e "${RED}>>> 阻止指定国家IP${RESET}"
    echo -e "${RED}此功能需要安装ipset和GeoIP数据库${RESET}"
    echo -e "${RED}支持的国家代码: CN,US,JP,KR,RU,DE,FR,GB等${RESET}"
    read -p "请输入国家代码: " country_code
    
    echo -e "${RED}请手动安装geoip数据库来使用此功能${RESET}"
    echo -e "${RED}参考命令: apt install xtables-addons-common${RESET}"
    read -n1 -p "按任意键继续..."
}

# 16. 仅允许指定国家IP
allow_only_country_ip() {
    echo -e "${RED}>>> 仅允许指定国家IP${RESET}"
    echo -e "${RED}此功能需要安装ipset和GeoIP数据库${RESET}"
    read -p "请输入允许的国家代码: " country_code
    
    echo -e "${RED}请手动安装geoip数据库来使用此功能${RESET}"
    read -n1 -p "按任意键继续..."
}

# 17. 解除指定国家IP限制
unblock_country_ip() {
    echo -e "${RED}>>> 解除指定国家IP限制${RESET}"
    read -p "请输入要解除限制的国家代码: " country_code
    
    echo -e "${RED}✅ 已解除 $country_code 国家IP限制${RESET}"
    read -n1 -p "按任意键继续..."
}

# 18. 防火墙状态查看
show_firewall_status() {
    echo -e "${RED}>>> 防火墙状态信息${RESET}"
    
    FIREWALL_TOOL=$(detect_firewall_tool)
    echo -e "${RED}当前防火墙工具: $FIREWALL_TOOL${RESET}"
    echo ""
    
    case $FIREWALL_TOOL in
        ufw)
            systemctl status ufw --no-pager
            ;;
        firewalld)
            systemctl status firewalld --no-pager
            firewall-cmd --state
            ;;
        iptables)
            echo -e "${RED}iptables 规则数量: $(iptables -L -n | wc -l)${RESET}"
            ;;
    esac
    
    read -n1 -p "按任意键继续..."
}

# -------------------------------
# 修改主菜单，添加防火墙管理选项
# -------------------------------
show_menu() {
    if [ -z "$IP_VERSION" ]; then
        IP_VERSION="4"
    fi
    
    while true; do
        print_welcome
        echo -e "请选择操作："
        echo -e "${RED}--- BBR 测速与切换 ---${RESET}"
        echo -e "${RED}1) BBR 综合测速 (BBR/BBR Plus/BBRv2/BBRv3 对比)${RESET}"
        echo -e "${RED}2) 安装/切换 BBR 内核${RESET}"
        echo -e "${RED}--- VPS 系统管理 ---${RESET}"
        echo -e "${RED}3) 查看系统信息 (OS/CPU/内存/IP/BBR/GLIBC)${RESET}"
        echo -e "${RED}4) 更新软件包并升级 (不升级内核)${RESET}"
        echo -e "${RED}5) 系统清理 (清理旧版依赖包)${RESET}"
        echo -e "${RED}6) IPv4/IPv6 切换 (当前: IPv$IP_VERSION)${RESET}"
        echo -e "${RED}7) 系统时区调整${RESET}"
        echo -e "${RED}8) 系统重启${RESET}"
        echo -e "${RED}9) GLIBC 管理${RESET}"
        echo -e "${RED}10) 全面系统升级 (含内核升级)${RESET}"
        echo -e "${RED}--- 服务管理 ---${RESET}"
        echo -e "${RED}11) Docker 容器管理${RESET}"
        echo -e "${RED}12) 防火墙管理${RESET}"
        echo -e "${RED}13) SSH 端口与密码修改${RESET}"
        echo -e "${RED}--- 其他 ---${RESET}"
        echo -e "${RED}14) 卸载脚本及残留文件${RESET}"
        echo -e "${RED}0) 退出脚本${RESET}"
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
            11) docker_management_menu ;;
            12) firewall_management_menu ;;
            13) ssh_config_menu ;;
            14) uninstall_script ;;
            0) echo -e "${RED}感谢使用，再见！${RESET}"; exit 0 ;;
            *) echo -e "${RED}无效选项，请输入 0-14${RESET}"; sleep 2 ;;
        esac
    done
}

# 保留其他原有函数不变（check_root, check_deps, 等）
# ... 原有代码保持不变 ...

# -------------------------------
# 主程序
# -------------------------------
check_root
check_deps
show_menu
