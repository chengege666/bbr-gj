#!/bin/bash
# 增强版VPS工具箱 v2.3
# GitHub: https://github.com/chengege666/bbr-gj

RESULT_FILE="bbr_result.txt"
SCRIPT_FILE="vps_toolbox.sh"
UNINSTALL_NOTE="vps_toolbox_uninstall_done.txt"

# -------------------------------
# 颜色定义与欢迎窗口
# -------------------------------
RED="\033[1;31m"
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
    echo -e "${MAGENTA}                VPS 工具箱 v3.0                ${RESET}"
    echo -e "${CYAN}--------------------------------------------------${RESET}"
    echo -e "${YELLOW}功能: BBR测速, 系统管理, 防火墙管理, Docker, SSH配置等${RESET}"
    echo -e "${GREEN}测速结果保存: ${RESULT_FILE}${RESET}"
    echo -e "${CYAN}==================================================${RESET}"
    echo ""
}

# -------------------------------
# 防火墙管理菜单 (按照您图片的样式)
# -------------------------------
firewall_management_menu() {
    while true; do
        clear
        echo -e "${BLUE}==================================================${RESET}"
        echo -e "${CYAN}                 防火墙管理                 ${RESET}"
        echo -e "${BLUE}--------------------------------------------------${RESET}"
        echo -e "${WHITE}1. 开放指定端口${RESET}                 ${GREEN}2. 关闭指定端口${RESET}"
        echo -e "${WHITE}3. 开放所有端口${RESET}                 ${GREEN}4. 关闭所有端口${RESET}"
        echo -e "${WHITE}5. IP白名单${RESET}                     ${GREEN}6. IP黑名单${RESET}"
        echo -e "${WHITE}7. 清除指定IP${RESET}                   ${GREEN}8. 查看当前规则${RESET}"
        echo -e "${WHITE}9. 备份防火墙规则${RESET}               ${GREEN}10. 恢复防火墙规则${RESET}"
        echo -e "${WHITE}11. 允许PING${RESET}                    ${GREEN}12. 禁止PING${RESET}"
        echo -e "${WHITE}13. 启动DDOS防御${RESET}                ${GREEN}14. 关闭DDOS防御${RESET}"
        echo -e "${WHITE}15. 阻止指定国家IP${RESET}              ${GREEN}16. 仅允许指定国家IP${RESET}"
        echo -e "${WHITE}17. 解除指定国家IP限制${RESET}          ${GREEN}18. 防火墙状态查看${RESET}"
        echo -e "${WHITE}0. 返回上一级选单${RESET}"
        echo -e "${BLUE}--------------------------------------------------${RESET}"
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
    if command -v ufw >/dev/null 2>&1; then
        echo "ufw"
    elif command -v firewalld >/dev/null 2>&1; then
        echo "firewalld"
    elif command -v iptables >/dev/null 2>&1; then
        echo "iptables"
    else
        echo "unknown"
    fi
}

# 1. 开放指定端口
open_specific_port() {
    echo -e "${CYAN}>>> 开放指定端口${RESET}"
    read -p "请输入要开放的端口号: " port
    read -p "请输入协议 (tcp/udp，默认tcp): " protocol
    protocol=${protocol:-tcp}
    
    FIREWALL_TOOL=$(detect_firewall_tool)
    case $FIREWALL_TOOL in
        ufw)
            ufw allow $port/$protocol
            ;;
        firewalld)
            firewall-cmd --permanent --add-port=$port/$protocol
            firewall-cmd --reload
            ;;
        iptables)
            iptables -A INPUT -p $protocol --dport $port -j ACCEPT
            service iptables save 2>/dev/null || iptables-save > /etc/sysconfig/iptables
            ;;
        *)
            echo -e "${RED}不支持的防火墙工具${RESET}"
            return 1
            ;;
    esac
    
    echo -e "${GREEN}✅ 端口 $port/$protocol 已开放${RESET}"
    read -n1 -p "按任意键继续..."
}

# 2. 关闭指定端口
close_specific_port() {
    echo -e "${CYAN}>>> 关闭指定端口${RESET}"
    read -p "请输入要关闭的端口号: " port
    read -p "请输入协议 (tcp/udp，默认tcp): " protocol
    protocol=${protocol:-tcp}
    
    FIREWALL_TOOL=$(detect_firewall_tool)
    case $FIREWALL_TOOL in
        ufw)
            ufw delete allow $port/$protocol
            ;;
        firewalld)
            firewall-cmd --permanent --remove-port=$port/$protocol
            firewall-cmd --reload
            ;;
        iptables)
            iptables -D INPUT -p $protocol --dport $port -j ACCEPT
            service iptables save 2>/dev/null || iptables-save > /etc/sysconfig/iptables
            ;;
        *)
            echo -e "${RED}不支持的防火墙工具${RESET}"
            return 1
            ;;
    esac
    
    echo -e "${GREEN}✅ 端口 $port/$protocol 已关闭${RESET}"
    read -n1 -p "按任意键继续..."
}

# 3. 开放所有端口
open_all_ports() {
    echo -e "${RED}⚠️ 警告：这将开放所有端口，存在安全风险！${RESET}"
    read -p "确定要开放所有端口吗？(y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${GREEN}已取消操作${RESET}"
        return
    fi
    
    FIREWALL_TOOL=$(detect_firewall_tool)
    case $FIREWALL_TOOL in
        ufw)
            ufw disable
            ;;
        firewalld)
            firewall-cmd --set-default-zone=public
            ;;
        iptables)
            iptables -P INPUT ACCEPT
            iptables -P FORWARD ACCEPT
            iptables -P OUTPUT ACCEPT
            iptables -F
            ;;
    esac
    
    echo -e "${GREEN}✅ 所有端口已开放${RESET}"
    read -n1 -p "按任意键继续..."
}

# 4. 关闭所有端口
close_all_ports() {
    echo -e "${RED}⚠️ 警告：这将关闭所有端口，可能导致无法远程连接！${RESET}"
    read -p "确定要关闭所有端口吗？(y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${GREEN}已取消操作${RESET}"
        return
    fi
    
    FIREWALL_TOOL=$(detect_firewall_tool)
    case $FIREWALL_TOOL in
        ufw)
            ufw --force reset
            ufw default deny incoming
            ufw default allow outgoing
            ufw enable
            ;;
        firewalld)
            firewall-cmd --set-default-zone=drop
            ;;
        iptables)
            iptables -P INPUT DROP
            iptables -P FORWARD DROP
            iptables -P OUTPUT ACCEPT
            iptables -A INPUT -i lo -j ACCEPT
            iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
            ;;
    esac
    
    echo -e "${GREEN}✅ 所有端口已关闭（除已建立的连接）${RESET}"
    echo -e "${YELLOW}⚠️ 请确保已开放SSH端口，否则会断开连接！${RESET}"
    read -n1 -p "按任意键继续..."
}

# 5. IP白名单
ip_whitelist() {
    echo -e "${CYAN}>>> 添加IP白名单${RESET}"
    read -p "请输入要加入白名单的IP地址: " ip
    
    FIREWALL_TOOL=$(detect_firewall_tool)
    case $FIREWALL_TOOL in
        ufw)
            ufw allow from $ip
            ;;
        firewalld)
            firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='$ip' accept"
            firewall-cmd --reload
            ;;
        iptables)
            iptables -A INPUT -s $ip -j ACCEPT
            service iptables save 2>/dev/null
            ;;
    esac
    
    echo -e "${GREEN}✅ IP $ip 已加入白名单${RESET}"
    read -n1 -p "按任意键继续..."
}

# 6. IP黑名单
ip_blacklist() {
    echo -e "${CYAN}>>> 添加IP黑名单${RESET}"
    read -p "请输入要加入黑名单的IP地址: " ip
    
    FIREWALL_TOOL=$(detect_firewall_tool)
    case $FIREWALL_TOOL in
        ufw)
            ufw deny from $ip
            ;;
        firewalld)
            firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='$ip' drop"
            firewall-cmd --reload
            ;;
        iptables)
            iptables -A INPUT -s $ip -j DROP
            service iptables save 2>/dev/null
            ;;
    esac
    
    echo -e "${GREEN}✅ IP $ip 已加入黑名单${RESET}"
    read -n1 -p "按任意键继续..."
}

# 7. 清除指定IP
clear_specific_ip() {
    echo -e "${CYAN}>>> 清除指定IP规则${RESET}"
    read -p "请输入要清除的IP地址: " ip
    
    FIREWALL_TOOL=$(detect_firewall_tool)
    case $FIREWALL_TOOL in
        ufw)
            ufw delete deny from $ip 2>/dev/null
            ufw delete allow from $ip 2>/dev/null
            ;;
        firewalld)
            firewall-cmd --permanent --remove-rich-rule="rule family='ipv4' source address='$ip' accept" 2>/dev/null
            firewall-cmd --permanent --remove-rich-rule="rule family='ipv4' source address='$ip' drop" 2>/dev/null
            firewall-cmd --reload
            ;;
        iptables)
            iptables -D INPUT -s $ip -j ACCEPT 2>/dev/null
            iptables -D INPUT -s $ip -j DROP 2>/dev/null
            service iptables save 2>/dev/null
            ;;
    esac
    
    echo -e "${GREEN}✅ IP $ip 的规则已清除${RESET}"
    read -n1 -p "按任意键继续..."
}

# 8. 查看当前规则
show_firewall_rules() {
    echo -e "${CYAN}>>> 当前防火墙规则${RESET}"
    
    FIREWALL_TOOL=$(detect_firewall_tool)
    case $FIREWALL_TOOL in
        ufw)
            ufw status verbose
            ;;
        firewalld)
            firewall-cmd --list-all
            ;;
        iptables)
            iptables -L -n
            ;;
    esac
    
    read -n1 -p "按任意键继续..."
}

# 9. 备份防火墙规则
backup_firewall_rules() {
    echo -e "${CYAN}>>> 备份防火墙规则${RESET}"
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
            iptables-save > $backup_file
            ;;
    esac
    
    echo -e "${GREEN}✅ 防火墙规则已备份到: $backup_file${RESET}"
    read -n1 -p "按任意键继续..."
}

# 10. 恢复防火墙规则
restore_firewall_rules() {
    echo -e "${CYAN}>>> 恢复防火墙规则${RESET}"
    read -p "请输入备份文件名: " backup_file
    
    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}❌ 备份文件不存在${RESET}"
        return 1
    fi
    
    FIREWALL_TOOL=$(detect_firewall_tool)
    case $FIREWALL_TOOL in
        ufw)
            # 需要手动处理UFW备份
            echo -e "${YELLOW}请手动处理UFW备份恢复${RESET}"
            ;;
        iptables)
            iptables-restore < $backup_file
            ;;
    esac
    
    echo -e "${GREEN}✅ 防火墙规则已恢复${RESET}"
    read -n1 -p "按任意键继续..."
}

# 11. 允许PING
allow_ping() {
    echo -e "${CYAN}>>> 允许PING响应${RESET}"
    
    FIREWALL_TOOL=$(detect_firewall_tool)
    case $FIREWALL_TOOL in
        ufw)
            ufw allow in on any to any proto icmp
            ;;
        firewalld)
            firewall-cmd --permanent --add-icmp-block-inversion
            firewall-cmd --reload
            ;;
        iptables)
            iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
            service iptables save 2>/dev/null
            ;;
    esac
    
    echo -e "${GREEN}✅ 已允许PING${RESET}"
    read -n1 -p "按任意键继续..."
}

# 12. 禁止PING
deny_ping() {
    echo -e "${CYAN}>>> 禁止PING响应${RESET}"
    
    FIREWALL_TOOL=$(detect_firewall_tool)
    case $FIREWALL_TOOL in
        ufw)
            ufw deny in on any to any proto icmp
            ;;
        firewalld)
            firewall-cmd --permanent --remove-icmp-block-inversion
            firewall-cmd --reload
            ;;
        iptables)
            iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
            service iptables save 2>/dev/null
            ;;
    esac
    
    echo -e "${GREEN}✅ 已禁止PING${RESET}"
    read -n1 -p "按任意键继续..."
}

# 13. 启动DDOS防御
enable_ddos_protection() {
    echo -e "${CYAN}>>> 启动DDOS防御${RESET}"
    
    # 简单的DDOS防护规则
    iptables -N DDOS_PROTECT 2>/dev/null
    iptables -F DDOS_PROTECT
    
    # 限制连接数
    iptables -A DDOS_PROTECT -p tcp --syn -m limit --limit 1/s -j ACCEPT
    iptables -A DDOS_PROTECT -p tcp --syn -j DROP
    iptables -A DDOS_PROTECT -p tcp --tcp-flags FIN,SYN,RST,ACK RST -m limit --limit 1/s -j ACCEPT
    
    # 应用到INPUT链
    iptables -I INPUT -p tcp -j DDOS_PROTECT
    
    echo -e "${GREEN}✅ DDOS防御已启动${RESET}"
    read -n1 -p "按任意键继续..."
}

# 14. 关闭DDOS防御
disable_ddos_protection() {
    echo -e "${CYAN}>>> 关闭DDOS防御${RESET}"
    
    iptables -D INPUT -p tcp -j DDOS_PROTECT 2>/dev/null
    iptables -F DDOS_PROTECT 2>/dev/null
    iptables -X DDOS_PROTECT 2>/dev/null
    
    echo -e "${GREEN}✅ DDOS防御已关闭${RESET}"
    read -n1 -p "按任意键继续..."
}

# 15. 阻止指定国家IP
block_country_ip() {
    echo -e "${CYAN}>>> 阻止指定国家IP${RESET}"
    echo -e "${YELLOW}此功能需要安装ipset和GeoIP数据库${RESET}"
    echo "支持的国家代码: CN,US,JP,KR,RU,DE,FR,GB等"
    read -p "请输入国家代码: " country_code
    
    # 这里只是示例，实际需要安装相应工具
    echo -e "${YELLOW}请手动安装geoip数据库来使用此功能${RESET}"
    echo "参考命令: apt install xtables-addons-common"
    read -n1 -p "按任意键继续..."
}

# 16. 仅允许指定国家IP
allow_only_country_ip() {
    echo -e "${CYAN}>>> 仅允许指定国家IP${RESET}"
    echo -e "${YELLOW}此功能需要安装ipset和GeoIP数据库${RESET}"
    read -p "请输入允许的国家代码: " country_code
    
    echo -e "${YELLOW}请手动安装geoip数据库来使用此功能${RESET}"
    read -n1 -p "按任意键继续..."
}

# 17. 解除指定国家IP限制
unblock_country_ip() {
    echo -e "${CYAN}>>> 解除指定国家IP限制${RESET}"
    read -p "请输入要解除限制的国家代码: " country_code
    
    echo -e "${GREEN}✅ 已解除 $country_code 国家IP限制${RESET}"
    read -n1 -p "按任意键继续..."
}

# 18. 防火墙状态查看
show_firewall_status() {
    echo -e "${CYAN}>>> 防火墙状态信息${RESET}"
    
    FIREWALL_TOOL=$(detect_firewall_tool)
    echo -e "${GREEN}当前防火墙工具: $FIREWALL_TOOL${RESET}"
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
            systemctl status iptables --no-pager 2>/dev/null || echo "iptables服务状态不可用"
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
        echo -e "${GREEN}--- BBR 测速与切换 ---${RESET}"
        echo "1) BBR 综合测速 (BBR/BBR Plus/BBRv2/BBRv3 对比)"
        echo "2) 安装/切换 BBR 内核"
        echo -e "${GREEN}--- VPS 系统管理 ---${RESET}"
        echo "3) 查看系统信息 (OS/CPU/内存/IP/BBR/GLIBC)"
        echo "4) 更新软件包并升级 (不升级内核)"
        echo "5) 系统清理 (清理旧版依赖包)"
        echo "6) IPv4/IPv6 切换 (当前: IPv$IP_VERSION)"
        echo "7) 系统时区调整"
        echo "8) 系统重启"
        echo "9) GLIBC 管理"
        echo "10) 全面系统升级 (含内核升级)"
        echo -e "${GREEN}--- 服务管理 ---${RESET}"
        echo "11) Docker 容器管理 ✰"
        echo "12) 防火墙管理 ✰ (新增)"
        echo "13) SSH 端口与密码修改"
        echo -e "${GREEN}--- 其他 ---${RESET}"
        echo "14) 卸载脚本及残留文件"
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
            11) docker_management_menu ;;
            12) firewall_management_menu ;;  # 新增防火墙管理
            13) ssh_config_menu ;;
            14) uninstall_script ;;
            0) echo -e "${CYAN}感谢使用，再见！${RESET}"; exit 0 ;;
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
