#!/bin/bash
# 增强版VPS工具箱 BBR 管理模块 v2.0.0
# 入口函数: bbr_manager_menu

# 全局变量引用 (来自 vpsgj.sh)
RESULT_FILE="bbr_result.txt"
RED="\033[1;31m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
RESET="\033[0m"

# -------------------------------
# 核心功能：BBR 测速 (原 run_test)
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
        *) # 增加一个默认情况以防意外输入
            echo -e "${YELLOW}未知 BBR 模式: $MODE${RESET}"
            ;;
    esac
    
    # 执行测速
    if ! command -v speedtest-cli >/dev/null 2>&1; then
        echo -e "${RED}未安装 speedtest-cli，无法测速。${RESET}"
        return
    fi
    RAW=$(speedtest-cli --simple 2>/dev/null)
    # 原始脚本中的备用测速方法已移除，依赖 speedtest-cli

    if [ -z "$RAW" ]; then
        echo -e "${RED}$MODE 测速失败 (无结果)${RESET}" | tee -a "$RESULT_FILE" 
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
# BBR 综合测速 (原 bbr_test_menu)
# -------------------------------
bbr_test_run() {
    echo -e "${CYAN}=== 开始 BBR 综合测速 ===${RESET}"
    > "$RESULT_FILE"
    
    # 自动安装 speedtest-cli
    if ! command -v speedtest-cli >/dev/null 2>&1; then
        echo -e "${YELLOW}正在安装 speedtest-cli...${RESET}"
        if command -v apt >/dev/null 2>&1; then
            apt update -y && apt install -y speedtest-cli
        elif command -v yum >/dev/null 2>&1; then
            yum install -y speedtest-cli
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y speedtest-cli
        else
            echo -e "${RED}无法自动安装 speedtest-cli，请手动安装。${RESET}"
            read -n1 -p "按任意键返回..."
            return
        fi
    fi

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
# 安装/切换 BBR 内核 (原 run_bbr_switch)
# -------------------------------
bbr_switch_run() {
    echo -e "${CYAN}正在下载并运行 BBR 切换脚本... (来自 ylx2016/Linux-NetSpeed)${RESET}"
    wget -O tcp.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌❌ 下载或运行脚本失败，请检查网络连接${RESET}"
    fi
    rm -f tcp.sh # 清理临时文件
    read -n1 -p "按任意键返回菜单..."
}

# -------------------------------
# 模块入口菜单
# -------------------------------
bbr_manager_menu() {
    while true; do
        clear
        echo -e "${MAGENTA}=== BBR 管理 ===${RESET}"
        echo "1) BBR 综合测速 (BBR/BBR Plus/BBRv2/BBRv3 对比)"
        echo "2) 安装/切换 BBR 内核"
        echo "0) 返回主菜单"
        echo ""
        read -p "请输入你的选择: " choice
        
        case "$choice" in
            1) bbr_test_run ;;
            2) bbr_switch_run ;;
            0) return ;;
            *) echo -e "${RED}无效选项${RESET}"; sleep 1 ;;
        esac
    done
}
