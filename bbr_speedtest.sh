#!/bin/bash

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
    echo -e "${YELLOW}支持算法: Reno / BBR / BBR Plus / BBRv2 / BBRv3${RESET}"
    echo -e "${GREEN}测速结果会保存到文件: ${RESULT_FILE}${RESET}"
    echo -e "${CYAN}==================================================${RESET}"
    echo ""
}

# -------------------------------
# Root 权限检查
# -------------------------------
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "错误：请使用 root 权限运行本脚本"
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
        yum install -y $PKGS
    else
        echo "未知系统，请手动安装依赖: $PKGS"
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
# 动态进度条
# -------------------------------
show_progress() {
    local duration=$1
    local interval=0.1
    local steps=$(awk "BEGIN {print int($duration/$interval)}")
    for ((i=0;i<=steps;i++)); do
        pct=$((i*100/steps))
        bar=$(printf "%-${steps}s" "#" | tr ' ' '#')
        printf "\r[%-50s] %d%%" "${bar:0:i*50/steps}" "$pct"
        sleep $interval
    done
    echo ""
}

# -------------------------------
# 检测可用算法并尝试加载模块
# -------------------------------
detect_algos() {
    local AVAILABLE=$(sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | awk '{print $3}')
    local ALGOS=("reno" "bbr" "bbrplus" "bbrv2" "bbrv3")
    SUPPORTED_ALGOS=()

    for algo in "${ALGOS[@]}"; do
        if echo "$AVAILABLE" | grep -qw "$algo"; then
            SUPPORTED_ALGOS+=("$algo")
        else
            # 尝试加载模块
            case $algo in
                "bbrplus") modprobe tcp_bbrplus 2>/dev/null ;;
                "bbrv2")   modprobe tcp_bbrv2 2>/dev/null ;;
                "bbrv3")   modprobe tcp_bbrv3 2>/dev/null ;;
            esac
            # 再次检测
            AVAILABLE=$(sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | awk '{print $3}')
            if echo "$AVAILABLE" | grep -qw "$algo"; then
                SUPPORTED_ALGOS+=("$algo")
            else
                SUPPORTED_ALGOS+=("$algo (不可用)")
            fi
        fi
    done
}

# -------------------------------
# 测速函数
# -------------------------------
run_test() {
    > "$RESULT_FILE"

    CYAN="\033[1;36m"
    GREEN="\033[1;32m"
    YELLOW="\033[1;33m"
    MAGENTA="\033[1;35m"
    RED="\033[1;31m"
    RESET="\033[0m"

    for MODE in "${SUPPORTED_ALGOS[@]}"; do
        echo -e "\n${CYAN}================== 测试 $MODE ==================${RESET}\n"

        if [[ "$MODE" == *"不可用"* ]]; then
            echo -e "${RED}$MODE 不支持，跳过测速${RESET}" | tee -a "$RESULT_FILE"
            continue
        fi

        echo -e "${CYAN}>>> 切换到 ${MODE} 并测速...${RESET}"

        case $MODE in
            "bbr") sysctl -w net.core.default_qdisc=fq >/dev/null; sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null ;;
            "reno") sysctl -w net.ipv4.tcp_congestion_control=reno >/dev/null ;;
            "bbrplus") sysctl -w net.ipv4.tcp_congestion_control=bbrplus >/dev/null ;;
            "bbrv2") sysctl -w net.ipv4.tcp_congestion_control=bbrv2 >/dev/null ;;
            "bbrv3") sysctl -w net.ipv4.tcp_congestion_control=bbrv3 >/dev/null ;;
        esac

        show_progress 10 &
        PROGRESS_PID=$!
        RAW=$(speedtest-cli --simple 2>/dev/null)
        kill $PROGRESS_PID 2>/dev/null
        wait $PROGRESS_PID 2>/dev/null

        if [ -z "$RAW" ]; then
            echo -e "${RED}$MODE 测速失败${RESET}" | tee -a "$RESULT_FILE"
            continue
        fi

        PING=$(echo "$RAW" | grep "Ping" | awk '{print $2}')
        DOWNLOAD=$(echo "$RAW" | grep "Download" | awk '{print $2}')
        UPLOAD=$(echo "$RAW" | grep "Upload" | awk '{print $2}')

        echo -e "${MAGENTA}+----------------------+------------+------------+------------+${RESET}"
        echo -e "${MAGENTA}| 算法                 | Ping(ms)   | 下载(Mbps) | 上传(Mbps) |${RESET}"
        echo -e "${MAGENTA}+----------------------+------------+------------+------------+${RESET}"
        printf "| %-20s | ${CYAN}%-10s${RESET} | ${GREEN}%-10s${RESET} | ${YELLOW}%-10s${RESET} |\n" "$MODE" "$PING" "$DOWNLOAD" "$UPLOAD" | tee -a "$RESULT_FILE"
        echo -e "${MAGENTA}+----------------------+------------+------------+------------+${RESET}\n"
    done

    echo -e "${GREEN}=== 测试完成，结果汇总 ===${RESET}"
    cat "$RESULT_FILE"
}

# -------------------------------
# 菜单
# -------------------------------
show_menu() {
    while true; do
        print_welcome
        echo "请选择操作："
        echo "1) 执行测速"
        echo "2) 退出"
        read -p "输入数字选择: " choice
        case "$choice" in
            1)
                detect_algos
                run_test
                echo ""
                read -n1 -p "按 k 返回菜单或任意键继续..." key
                echo ""
                ;;
            2)
                echo "退出脚本"
                exit 0
                ;;
            *)
                echo "无效选项，请输入 1 或 2"
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
