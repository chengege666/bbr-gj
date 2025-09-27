#!/bin/bash

RESULT_FILE="bbr_result.txt"
> "$RESULT_FILE"

# -------------------------------
# 美化欢迎窗口
# -------------------------------
print_welcome() {
    clear
    RED="\033[1;31m"
    GREEN="\033[1;32m"
    YELLOW="\033[1;33m"
    BLUE="\033[1;34m"
    MAGENTA="\033[1;35m"
    CYAN="\033[1;36m"
    RESET="\033[0m"

    echo -e "${CYAN}==================================================${RESET}"
    echo -e "${MAGENTA}                BBR 测速脚本                     ${RESET}"
    echo -e "${CYAN}--------------------------------------------------${RESET}"
    echo -e "${YELLOW}支持算法: reno / bbr${RESET}"
    echo -e "${GREEN}测速结果会保存到文件: ${RESULT_FILE}${RESET}"
    echo -e "${CYAN}==================================================${RESET}"
    echo ""
}

print_welcome

# -------------------------------
# root 权限检查
# -------------------------------
if [ "$(id -u)" -ne 0 ]; then
    echo "错误：请使用 root 权限运行本脚本"
    exit 1
fi

# -------------------------------
# 安装依赖（可选）
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

for CMD in curl wget git speedtest-cli; do
    if ! command -v $CMD >/dev/null 2>&1; then
        echo "未检测到 $CMD，正在安装依赖..."
        install_deps
        break
    fi
done

# -------------------------------
# 模拟动态进度条
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
# 测速函数
# -------------------------------
run_test() {
    MODE=$1
    CYAN="\033[1;36m"
    GREEN="\033[1;32m"
    YELLOW="\033[1;33m"
    MAGENTA="\033[1;35m"
    RESET="\033[0m"

    echo -e "${CYAN}>>> 切换到 ${MODE} 并测速...${RESET}"

    case $MODE in
        "bbr")
            modprobe tcp_bbr 2>/dev/null
            sysctl -w net.core.default_qdisc=fq >/dev/null
            sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null
            ;;
        "reno")
            sysctl -w net.ipv4.tcp_congestion_control=reno >/dev/null
            ;;
    esac

    # 启动测速并显示进度条（模拟 10 秒）
    show_progress 10 &  
    PROGRESS_PID=$!
    RAW=$(speedtest-cli --simple 2>/dev/null)
    kill $PROGRESS_PID 2>/dev/null
    wait $PROGRESS_PID 2>/dev/null

    if [ -z "$RAW" ]; then
        echo -e "${RED}$MODE 测速失败${RESET}" | tee -a "$RESULT_FILE"
        echo ""
        return
    fi

    PING=$(echo "$RAW" | grep "Ping" | awk '{print $2}')
    DOWNLOAD=$(echo "$RAW" | grep "Download" | awk '{print $2}')
    UPLOAD=$(echo "$RAW" | grep "Upload" | awk '{print $2}')

    echo -e "${MAGENTA}+----------------------+------------+------------+------------+${RESET}"
    echo -e "${MAGENTA}| 算法                 | Ping(ms)   | 下载(Mbps) | 上传(Mbps) |${RESET}"
    echo -e "${MAGENTA}+----------------------+------------+------------+------------+${RESET}"
    printf "| %-20s | ${CYAN}%-10s${RESET} | ${GREEN}%-10s${RESET} | ${YELLOW}%-10s${RESET} |\n" "$MODE" "$PING" "$DOWNLOAD" "$UPLOAD" | tee -a "$RESULT_FILE"
    echo -e "${MAGENTA}+----------------------+------------+------------+------------+${RESET}"
    echo ""
}

# -------------------------------
# 循环测试
# -------------------------------
for MODE in "reno" "bbr"; do
    run_test "$MODE"
done

echo -e "${GREEN}=== 测试完成，结果汇总 ===${RESET}"
cat "$RESULT_FILE"
