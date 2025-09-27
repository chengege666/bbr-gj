#!/bin/bash
# 自动切换 BBR 算法并测速对比
# GitHub: https://github.com/chengege666/bbr-speedtest

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
    echo -e "${YELLOW}支持算法: BBR (其他变种需要自定义内核)${RESET}"
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
# 测速函数（改进版）
# -------------------------------
run_test() {
    MODE=$1
    RED="\033[1;31m"
    GREEN="\033[1;32m"
    CYAN="\033[1;36m"
    RESET="\033[0m"

    echo -e "${CYAN}>>> 切换到 $MODE 并测速...${RESET}"

    # 设置算法
    case $MODE in
        "BBR")
            sysctl -w net.core.default_qdisc=fq >/dev/null
            sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null
            ;;
        "BBR Plus"|"BBRv2"|"BBRv3")
            echo -e "${YELLOW}⚠️ 注意: $MODE 需要自定义内核支持${RESET}"
            echo -e "${YELLOW}⚠️ 当前系统可能不支持，使用原生BBR替代${RESET}"
            sysctl -w net.core.default_qdisc=fq >/dev/null
            sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null
            ;;
    esac

    # 使用两种测速方法提高成功率
    RAW=$(speedtest-cli --simple 2>/dev/null)
    if [ -z "$RAW" ]; then
        # 备用测速方法
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
# 交互菜单
# -------------------------------
show_menu() {
    while true; do
        print_welcome
        echo "请选择操作："
        echo "1) 执行 BBR 测速"
        echo "2) 退出"
        read -p "输入数字选择: " choice
        
        case "$choice" in
            1)
                > "$RESULT_FILE"
                # 只测试原生BBR，其他变种需要自定义内核
                run_test "BBR"
                
                # 提供选项测试其他变种（但会提示需要自定义内核）
                read -p "是否测试BBR变种？(y/n) [默认n]: " test_variants
                if [[ "$test_variants" =~ [yY] ]]; then
                    run_test "BBR Plus"
                    run_test "BBRv2"
                    run_test "BBRv3"
                fi
                
                echo "=== 测试完成，结果汇总 ==="
                cat "$RESULT_FILE"
                echo ""
                read -n1 -p "按 k 返回菜单或任意键继续..." key
                echo ""
                if [ "$key" = "k" ] || [ "$key" = "K" ]; then
                    continue
                fi
                ;;
            2)
                echo "退出脚本"
                exit 0
                ;;
            *)
                echo "无效选项，请输入 1 或 2"
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
