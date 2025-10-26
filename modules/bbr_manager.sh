#!/bin/bash
# BBR 管理模块 (modules/bbr_manager.sh)

# -------------------------------
# 依赖说明：
# 假设主脚本已经定义了以下颜色变量: 
# RED, GREEN, YELLOW, CYAN, RESET
# -------------------------------

# -------------------------------
# 1) 安装/启用 BBR (对应菜单项 1)
# 该功能通过下载并运行外部脚本来实现 BBR 内核的安装和切换。
# -------------------------------
install_enable_bbr() {
    clear
    echo -e "${CYAN}>>> 正在下载并运行 BBR 切换脚本... (来自 ylx2016/Linux-NetSpeed)${RESET}"
    
    # 执行下载并运行外部内核切换脚本
    wget -O tcp.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌❌ 下载或运行脚本失败，请检查网络连接${RESET}"
    else
        echo -e "${GREEN}BBR 切换脚本运行完毕。${RESET}"
    fi
    
    # 清理下载的脚本文件，避免残留
    if [ -f "tcp.sh" ]; then
        rm -f tcp.sh
    fi

    read -n1 -p "按任意键返回菜单..."
}

# -------------------------------
# 2) 查看当前 BBR 状态 (对应菜单项 2)
# -------------------------------
show_bbr_status() {
    clear
    echo -e "${CYAN}=== 当前 BBR 状态 ===${RESET}"
    
    # 拥塞控制算法
    CURRENT_BBR=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    # 队列规则
    CURRENT_QDISC=$(sysctl net.core.default_qdisc 2>/dev/null | awk '{print $3}')
    
    echo -e "${GREEN}当前拥塞控制算法:${RESET} $CURRENT_BBR"
    echo -e "${GREEN}当前队列规则:${RESET} $CURRENT_QDISC"
    
    echo ""
    read -n1 -p "按任意键返回菜单..."
}

# -------------------------------
# 模块主入口：BBR 管理菜单
# -------------------------------
bbr_manager_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== BBR 管理 ===${RESET}"
        echo "1) 安装/启用 BBR"
        echo "2) 查看当前 BBR 状态"
        echo "3) 返回主菜单"
        echo "------------------------------------------------"
        read -p "请输入选择: " choice
        
        case "$choice" in
            1) install_enable_bbr ;;
            2) show_bbr_status ;;
            3) break ;;
            *) echo -e "${RED}无效选项，请输入 1-3${RESET}"; sleep 2 ;;
        esac
    done
}

# 如果主脚本直接 source 这个文件，只需要定义函数。
# 如果需要作为独立脚本运行，可以取消注释下面一行：
# bbr_manager_menu
