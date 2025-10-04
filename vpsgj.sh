#!/bin/bash
# 自动切换 BBR 算法并测速对比（兼容 speedtest-cli）
# GitHub: https://github.com/chengege666/bbr-gj

RESULT_FILE="bbr_result.txt"

# -------------------------------
# 欢迎窗口
# -------------------------------
print_welcome() {
    clear
    RED="\033[1;31m"
    GREEN="\033[1;32m"
    YELLOW="\033[1;33m"
    MAGENTA="\033[1;35m"
    CYAN="\033[1;36m"
    RESET="\033[0m"

    echo -e "${CYAN}==================================================${RESET}"
    echo -e "${MAGENTA}                BBR 测速脚本                     ${RESET}"
    echo -e "${CYAN}--------------------------------------------------${RESET}"
    echo -e "${YELLOW}支持算法: BBR / BBR Plus / BBRv2 / BBRv3${RESET}"
    echo -e "${GREEN}测速结果会保存到文件: ${RESULT_FILE}${RESET}"
    echo -e "${CYAN}==================================================${RESET}"
    echo ""
}

# -------------------------------
# root 权限检查
# -------------------------------
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "❌ 错误：请使用 root 权限运行本脚本"
        echo "👉 使用方法: sudo bash $0"
        exit 1
    fi
}

# -------------------------------
# 安装依赖
# -------------------------------
install_deps() {
    PKGS="curl wget git speedtest-cli"
    if [ -f /etc/debian_version ]; then
        apt update -y
        apt install -y $PKGS
    elif [ -f /etc/redhat-release ]; then
        yum install -y $PKGS 2>/dev/null || dnf install -y $PKGS
    else
        echo "⚠️ 未知系统，请手动安装依赖: $PKGS"
        exit 1
    fi
}

check_deps() {
    for CMD in curl wget git speedtest-cli; do
        if ! command -v $CMD >/dev/null 2>&1; then
            echo "未检测到 $CMD，正在安装依赖..."
            install_deps
            break
        fi
    done
}

# -------------------------------
# 测速函数（保留所有BBR变种）
# -------------------------------
run_test() {
    MODE=$1
    RED="\033[1;31m"
    GREEN="\033[1;32m"
    CYAN="\033[1;36m"
    RESET="\033[0m"

    echo -e "${CYAN}>>> 切换到 $MODE 并测速...${RESET}"

    case $MODE in
        "BBR")
            modprobe tcp_bbr 2>/dev/null
            sysctl -w net.core.default_qdisc=fq >/dev/null
            sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1
            ;;
        "BBR Plus")
            modprobe tcp_bbrplus 2>/dev/null
            sysctl -w net.core.default_qdisc=fq >/dev/null
            sysctl -w net.ipv4.tcp_congestion_control=bbrplus >/dev/null 2>&1
            ;;
        "BBRv2")
            modprobe tcp_bbrv2 2>/dev/null
            sysctl -w net.core.default_qdisc=fq >/dev/null
            sysctl -w net.ipv4.tcp_congestion_control=bbrv2 >/dev/null 2>&1
            ;;
        "BBRv3")
            modprobe tcp_bbrv3 2>/dev/null
            sysctl -w net.core.default_qdisc=fq >/dev/null
            sysctl -w net.ipv4.tcp_congestion_control=bbrv3 >/dev/null 2>&1
            ;;
    esac

    # 添加备用测速方法提高成功率
    RAW=$(speedtest-cli --simple 2>/dev/null)
    if [ -z "$RAW" ]; then
        echo -e "${YELLOW}⚠️ speedtest-cli 失败，尝试使用替代方法...${RESET}"
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

    echo "$MODE | Ping: ${PING}ms | Down: ${DOWNLOAD} Mbps | Up: ${UPLOAD} Mbps" | tee -a "$RESULT_FILE"
    echo ""
}

# -------------------------------
# 运行外部BBR切换脚本
# -------------------------------
run_bbr_switch() {
    echo "正在下载并运行 BBR 切换脚本..."
    wget -O tcp.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
    if [ $? -ne 0 ]; then
        echo "❌ 下载或运行脚本失败，请检查网络连接"
        read -n1 -p "按任意键返回菜单..."
    fi
}

# -------------------------------
# 交互菜单
# -------------------------------
show_menu() {
    while true; do
        print_welcome
        echo "请选择操作："
        echo "1) 执行 BBR 测速"
        echo "2) 安装/切换 BBR 内核（运行外部脚本）"
        echo "3) 退出"
        read -p "输入数字选择: " choice
        
        case "$choice" in
            1)
                > "$RESULT_FILE"
                for MODE in "BBR" "BBR Plus" "BBRv2" "BBRv3"; do
                    run_test "$MODE"
                done
                echo "=== 测试完成，结果汇总 ==="
                cat "$RESULT_FILE"
                echo ""
                read -n1 -p "按任意键返回菜单..." key
                echo ""
                ;;
            2)
                run_bbr_switch
                ;;
            3)
                echo "退出脚本"
                exit 0
                ;;
            *)
                echo "无效选项，请输入 1-3"
                sleep 2
                ;;
        esac
    done
}

# -------------------------------
# 主程序
# -------------------------------
check_root
check_deps
show_menu
