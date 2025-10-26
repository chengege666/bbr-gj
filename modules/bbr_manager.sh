#!/bin/bash
# BBR管理模块

main() {
    echo -e "${CYAN}=== BBR 管理 ===${RESET}"
    echo "1) 安装/启用 BBR"
    echo "2) 查看当前 BBR 状态"
    echo "3) 返回主菜单"
    
    read -p "请输入选择: " bbr_choice
    case "$bbr_choice" in
        1)
            echo -e "${YELLOW}安装 BBR...${RESET}"
            modprobe tcp_bbr
            echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
            echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
            echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
            sysctl -p
            echo -e "${GREEN}BBR 安装完成${RESET}"
            ;;
        2)
            echo -e "${CYAN}当前 BBR 状态:${RESET}"
            sysctl net.ipv4.tcp_congestion_control
            sysctl net.core.default_qdisc
            lsmod | grep bbr
            ;;
        3) return ;;
        *) echo -e "${RED}无效选择${RESET}" ;;
    esac
    read -n1 -p "按任意键继续..."
    echo
}
