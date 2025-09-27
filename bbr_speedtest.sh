#!/bin/bash
# 一键BBR测速脚本（无需下载）
# GitHub: https://github.com/chengege666/bbr-speedtest

# 创建临时结果文件
RESULT_FILE=$(mktemp)

# -------------------------------
# 欢迎窗口
# -------------------------------
print_welcome() {
    clear
    echo "=================================================="
    echo "                BBR 测速脚本                     "
    echo "--------------------------------------------------"
    echo "支持算法: BBR (其他变种需要自定义内核)"
    echo "测速结果会显示在屏幕上"
    echo "=================================================="
    echo ""
}

# -------------------------------
# root 权限检查
# -------------------------------
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "❌ 错误：请使用 root 权限运行本脚本"
        echo "👉 使用方法: sudo bash <(curl -Ls https://raw.githubusercontent.com/chengege666/bbr-speedtest/main/bbr_speedtest.sh)"
        exit 1
    fi
}

# -------------------------------
# 安装依赖
# -------------------------------
install_deps() {
    PKGS="speedtest-cli"
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
    if ! command -v speedtest-cli >/dev/null 2>&1; then
        echo "未检测到 speedtest-cli，正在安装依赖..."
        install_deps
    fi
}

# -------------------------------
# 测速函数（优化版）
# -------------------------------
run_test() {
    MODE=$1
    echo ">>> 切换到 $MODE 并测速..."
    
    # 设置算法
    case $MODE in
        "BBR")
            sysctl -w net.core.default_qdisc=fq >/dev/null
            sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null
            ;;
        *)
            echo "⚠️ 注意: $MODE 需要自定义内核支持，使用原生BBR替代"
            sysctl -w net.core.default_qdisc=fq >/dev/null
            sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null
            ;;
    esac

    # 使用speedtest-cli测速
    RAW=$(speedtest-cli --simple 2>/dev/null)
    
    # 备用测速方法
    if [ -z "$RAW" ]; then
        echo "⚠️ speedtest-cli 失败，尝试使用替代方法..."
        RAW=$(curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python - --simple 2>/dev/null)
    fi

    if [ -z "$RAW" ]; then
        echo "$MODE 测速失败" | tee -a "$RESULT_FILE"
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
# 自动执行测速
# -------------------------------
auto_run() {
    print_welcome
    check_root
    check_deps
    
    echo "⏳ 正在执行 BBR 测速..."
    echo ""
    
    # 只测试原生BBR
    run_test "BBR"
    
    echo "✅ 测试完成"
    echo "=== 结果汇总 ==="
    cat "$RESULT_FILE"
    
    # 清理临时文件
    rm -f "$RESULT_FILE"
}

# -------------------------------
# 直接执行测速
# -------------------------------
auto_run
