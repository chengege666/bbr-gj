#!/bin/bash
# 测试脚本合集模块

main() {
    echo -e "${CYAN}=== 测试脚本合集 ===${RESET}"
    echo "1) 网络速度测试"
    echo "2) 磁盘性能测试"
    echo "3) 回程路由测试"
    echo "4) 返回主菜单"
    
    read -p "请输入选择: " test_choice
    case "$test_choice" in
        1)
            echo -e "${CYAN}开始网络速度测试...${RESET}"
            if command -v speedtest-cli >/dev/null 2>&1; then
                speedtest-cli
            else
                echo -e "${YELLOW}安装 speedtest-cli...${RESET}"
                if command -v apt >/dev/null 2>&1; then
                    apt install -y speedtest-cli
                fi
                speedtest-cli
            fi
            ;;
        2)
            echo -e "${CYAN}开始磁盘性能测试...${RESET}"
            echo -e "${YELLOW}测试写入速度...${RESET}"
            dd if=/dev/zero of=./testfile bs=1M count=1024 oflag=direct
            rm -f ./testfile
            ;;
        3)
            echo -e "${CYAN}回程路由测试...${RESET}"
            echo -e "${YELLOW}测试到 8.8.8.8 的路由...${RESET}"
            traceroute 8.8.8.8
            ;;
        4) return ;;
        *) echo -e "${RED}无效选择${RESET}" ;;
    esac
    read -n1 -p "按任意键继续..."
    echo
}
