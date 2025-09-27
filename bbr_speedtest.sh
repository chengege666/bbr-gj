#!/bin/bash

# 自动切换 BBR 算法并测速对比（兼容 speedtest-cli）

# GitHub: [https://github.com/chengege666/bbr-speedtest](https://github.com/chengege666/bbr-speedtest)

RESULT_FILE="bbr_result.txt"

> "$RESULT_FILE"

echo "=== BBR / BBR Plus / BBRv2 / BBRv3 自动测速对比 ==="
echo "结果会保存到 $RESULT_FILE"
echo ""

# -------------------------------

# 检查 root 权限

# -------------------------------

if [ "$(id -u)" -ne 0 ]; then
echo "❌ 错误：请使用 root 权限运行本脚本"
echo "👉 使用方法: sudo bash $0"
exit 1
fi

# -------------------------------

# 系统检测 + 自动安装依赖

# -------------------------------

install_deps() {
PKGS="curl wget git speedtest-cli"
if [ -f /etc/debian_version ]; then
apt update -y
apt install -y $PKGS
elif [ -f /etc/redhat-release ]; then
yum install -y $PKGS
else
echo "⚠️ 未知系统，请手动安装以下依赖: $PKGS"
exit 1
fi
}

# 检查依赖是否存在

for CMD in curl wget git speedtest-cli; do
if ! command -v $CMD >/dev/null 2>&1; then
echo "未检测到 $CMD，正在安装依赖..."
install_deps
break
fi
done

# -------------------------------

# 定义测速函数

# -------------------------------

run_test() {
MODE=$1
echo ">>> 切换到 $MODE 并测速..."

```
case $MODE in
    "BBR")
        modprobe tcp_bbr 2>/dev/null
        sysctl -w net.core.default_qdisc=fq >/dev/null
        sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null
        ;;
    "BBR Plus")
        modprobe tcp_bbrplus 2>/dev/null
        sysctl -w net.core.default_qdisc=fq >/dev/null
        sysctl -w net.ipv4.tcp_congestion_control=bbrplus >/dev/null
        ;;
    "BBRv2")
        echo "⚠️ 你的内核可能不支持 BBRv2"
        ;;
    "BBRv3")
        echo "⚠️ 你的内核可能不支持 BBRv3"
        ;;
esac

RAW=$(speedtest-cli --simple 2>/dev/null)
if [ -z "$RAW" ]; then
    echo "$MODE | 测速失败，可能是网络问题或 speedtest-cli 不兼容" | tee -a "$RESULT_FILE"
    echo ""
    return
fi

PING=$(echo "$RAW" | grep "Ping" | awk '{print $2}')
DOWNLOAD_MBPS=$(echo "$RAW" | grep "Download" | awk '{print $2}')
UPLOAD_MBPS=$(echo "$RAW" | grep "Upload" | awk '{print $2}')

echo "$MODE | Ping: ${PING}ms | Down: ${DOWNLOAD_MBPS} Mbps | Up: ${UPLOAD_MBPS} Mbps" | tee -a "$RESULT_FILE"
echo ""
```

}

# -------------------------------

# 循环测试

# -------------------------------

for MODE in "BBR" "BBR Plus" "BBRv2" "BBRv3"; do
run_test "$MODE"
done

echo "=== 测试完成，结果汇总 ==="
cat "$RESULT_FILE"
