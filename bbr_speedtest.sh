#!/bin/bash

# 自动切换 BBR 算法并测速对比（兼容 speedtest-cli）

# GitHub: [https://github.com/你的GitHub用户名/bbr-speedtest](https://github.com/你的GitHub用户名/bbr-speedtest)

RESULT_FILE="bbr_result.txt"

> "$RESULT_FILE"

echo "=== BBR / BBR Plus / BBRv2 / BBRv3 自动测速对比 ==="
echo "结果会保存到 $RESULT_FILE"
echo ""

# 检查 root 权限

if [ "$(id -u)" -ne 0 ]; then
echo "请使用 root 权限运行本脚本"
exit 1
fi

# 检查 speedtest-cli

if ! command -v speedtest-cli >/dev/null 2>&1; then
echo "未检测到 speedtest-cli，正在安装..."
if [ -f /etc/debian_version ]; then
apt update -y && apt install -y speedtest-cli
elif [ -f /etc/redhat-release ]; then
yum install -y speedtest-cli
else
echo "不支持的系统，请手动安装 speedtest-cli"
exit 1
fi
fi

# 定义测速函数

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

# 循环测试

for MODE in "BBR" "BBR Plus" "BBRv2" "BBRv3"; do
run_test "$MODE"
done

echo "=== 测试完成，结果汇总 ==="
cat "$RESULT_FILE"
