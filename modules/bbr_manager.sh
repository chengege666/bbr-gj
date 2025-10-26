#!/bin/bash
# BBR 管理模块 (从 vpsgj.sh 提取并合并)

# -------------------------------
# 依赖于主脚本的颜色定义和文件路径 (如果单独运行，请在脚本开头定义)
# 假设主脚本已经定义了: RESULT_FILE, RED, GREEN, YELLOW, CYAN, RESET
# -------------------------------

# 示例颜色定义 (如果主脚本未引入，需要打开以下注释)
# RED="\033[1;31m"
# GREEN="\033[1;32m"
# YELLOW="\033[1;33m"
# CYAN="\033[1;36m"
# RESET="\033[0m"
# RESULT_FILE="bbr_result.txt"

# -------------------------------
# BBR 测速核心功能：切换算法并执行测速
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
        *)
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
# 功能 1: BBR 综合测速菜单
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
# 功能 2: 安装/切换 BBR 内核
# -------------------------------
run_bbr_switch() {
    echo -e "${CYAN}正在下载并运行 BBR 切换脚本... (来自 ylx2016/Linux-NetSpeed)${RESET}"
    # 注意: 脚本下载后会在当前目录留下 tcp.sh 文件，卸载时需要清理
    wget -O tcp.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌❌ 下载或运行脚本失败，请检查网络连接${RESET}"
    fi
    read -n1 -p "按任意键返回菜单..."
}

# -------------------------------
# BBR 状态查询 (用于信息查看)
# -------------------------------
show_bbr_status() {
    # BBR信息
    CURRENT_BBR=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    CURRENT_QDISC=$(sysctl net.core.default_qdisc 2>/dev/null | awk '{print $3}')
    echo -e "${GREEN}当前拥塞控制算法:${RESET} $CURRENT_BBR"
    echo -e "${GREEN}当前队列规则:${RESET} $CURRENT_QDISC"
}

# -------------------------------
# BBR 主菜单 (如果需要单独运行此模块)
# -------------------------------
bbr_manager_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== BBR 加速管理 ===${RESET}"
        show_bbr_status
        echo "------------------------------------------------"
        echo "1. BBR 综合测速 (BBR/BBR Plus/BBRv2/BBRv3 对比)"
        echo "2. 安装/切换 BBR 内核"
        echo "0. 返回主菜单"
        echo "------------------------------------------------"
        read -p "请输入你的选择: " choice
        
        case "$choice" in
            1) bbr_test_menu ;;
            2) run_bbr_switch ;;
            0) break ;;
            *) echo -e "${RED}无效选项，请输入 0-2${RESET}"; sleep 2 ;;
        esac
    done
}
