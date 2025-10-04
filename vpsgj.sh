#!/bin/bash
# 文件名: vpsgj.sh
# 自动切换 BBR 算法并测速对比，并集成系统管理和Docker功能。
# 增加本地下载 BBR 切换脚本和卸载功能。

RESULT_FILE="bbr_result.txt"
SCRIPT_NAME="vpsgj.sh" # 脚本名称

# -------------------------------
# 颜色定义
# -------------------------------
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
MAGENTA="\033[1;35m"
CYAN="\033[1;36m"
RESET="\033[0m"

# -------------------------------
# 欢迎窗口
# -------------------------------
print_welcome() {
    clear
    echo -e "${CYAN}==================================================${RESET}"
    echo -e "${MAGENTA}              服务器管理与 BBR 测速脚本           ${RESET}"
    echo -e "${CYAN}--------------------------------------------------${RESET}"
    echo -e "${YELLOW}支持功能: BBR 测速/切换, 系统管理, Docker管理${RESET}"
    echo -e "${GREEN}测速结果会保存到文件: ${RESULT_FILE}${RESET}"
    echo -e "${CYAN}==================================================${RESET}"
    echo ""
}

# -------------------------------
# root 权限检查
# -------------------------------
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}❌ 错误：请使用 root 权限运行本脚本${RESET}"
        echo "👉 使用方法: sudo bash $SCRIPT_NAME"
        exit 1
    fi
}

# -------------------------------
# 安装依赖
# -------------------------------
install_deps() {
    PKGS="curl wget git speedtest-cli"
    if [ -f /etc/debian_version ]; then
        echo -e "${GREEN}>>> 正在更新 APT 包列表...${RESET}"
        apt update -y
        echo -e "${GREEN}>>> 正在安装依赖: $PKGS ...${RESET}"
        apt install -y $PKGS
    elif [ -f /etc/redhat-release ]; then
        echo -e "${GREEN}>>> 正在更新 YUM/DNF 包列表...${RESET}"
        yum update -y 2>/dev/null || dnf update -y 
        echo -e "${GREEN}>>> 正在安装依赖: $PKGS ...${RESET}"
        yum install -y $PKGS 2>/dev/null || dnf install -y $PKGS
    else
        echo -e "${YELLOW}⚠️ 未知系统，请手动安装依赖: $PKGS${RESET}"
    fi
}

check_deps() {
    for CMD in curl wget git speedtest-cli; do
        if ! command -v $CMD >/dev/null 2>&1; then
            echo -e "${YELLOW}未检测到 $CMD，正在安装依赖...${RESET}"
            install_deps
            break
        fi
    done
}

# -------------------------------
# 测速函数
# -------------------------------
run_test() {
    MODE=$1
    echo -e "${CYAN}>>> 切换到 $MODE 并测速...${RESET}"

    # BBR 切换逻辑
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

    # 测速逻辑
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
# 运行外部BBR切换脚本 (修改为先下载)
# -------------------------------
download_bbr_switch() {
    clear
    echo -e "${CYAN}==================================================${RESET}"
    echo -e "${MAGENTA}              BBR 内核切换脚本下载                ${RESET}"
    echo -e "${CYAN}==================================================${RESET}"
    
    BBR_SCRIPT="tcp.sh"
    BBR_URL="https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcp.sh"

    echo -e "${GREEN}>>> 正在下载 BBR 切换脚本到本地: ${BBR_SCRIPT}${RESET}"
    wget -O "$BBR_SCRIPT" "$BBR_URL"
    
    if [ $? -eq 0 ]; then
        chmod +x "$BBR_SCRIPT"
        echo -e "${GREEN}✅ BBR 切换脚本 ($BBR_SCRIPT) 已成功下载到当前目录。${RESET}"
        echo -e "${YELLOW}👉 请手动运行以下命令来安装或切换内核：${RESET}"
        echo -e "${YELLOW}   bash ${BBR_SCRIPT}${RESET}"
        echo -e "${YELLOW}   脚本执行完毕后可能需要重启服务器。${RESET}"
    else
        echo -e "${RED}❌ 下载脚本失败，请检查网络连接或 $BBR_URL 是否可用。${RESET}"
    fi

    read -n1 -p "按任意键返回菜单..."
}

# -------------------------------
# 系统信息函数
# -------------------------------
show_system_info() {
    clear
    echo -e "${CYAN}==================================================${RESET}"
    echo -e "${MAGENTA}              当前系统信息概览                  ${RESET}"
    echo -e "${CYAN}==================================================${RESET}"
    echo -e "${YELLOW}--- 基本信息 ---${RESET}"
    hostnamectl | grep -E 'Operating System|Kernel|Architecture'
    echo ""
    echo -e "${YELLOW}--- CPU 信息 ---${RESET}"
    lscpu | grep -E 'Model name|CPU\(s\)|Thread\(s\) per core|Core\(s\) per socket'
    echo ""
    echo -e "${YELLOW}--- 内存信息 ---${RESET}"
    free -h | grep -E 'Mem:|Swap:'
    echo ""
    echo -e "${YELLOW}--- 硬盘信息 ---${RESET}"
    df -h | grep -E 'Filesystem|/dev/|Size'
    echo ""
    echo -e "${YELLOW}--- 网络信息 ---${RESET}"
    ip a | grep -E 'global'
    echo ""
    echo -e "${YELLOW}--- 当前 TCP 拥塞控制算法 ---${RESET}"
    sysctl net.ipv4.tcp_congestion_control | awk '{print $3}'
    echo ""
    read -n1 -p "按任意键返回菜单..."
}

# -------------------------------
# 系统更新函数
# -------------------------------
run_system_update() {
    clear
    echo -e "${CYAN}==================================================${RESET}"
    echo -e "${MAGENTA}              开始系统更新与升级                  ${RESET}"
    echo -e "${CYAN}==================================================${RESET}"
    
    if [ -f /etc/debian_version ]; then
        echo -e "${GREEN}>>> 正在运行 apt update && apt upgrade -y ...${RESET}"
        apt update -y && apt upgrade -y
    elif [ -f /etc/redhat-release ]; then
        echo -e "${GREEN}>>> 正在运行 yum update -y / dnf update -y ...${RESET}"
        yum update -y || dnf update -y
    else
        echo -e "${RED}❌ 未知系统，无法执行自动更新。请手动更新！${RESET}"
    fi
    
    echo -e "${GREEN}✅ 系统更新完成！${RESET}"
    read -n1 -p "按任意键返回菜单..."
}

# -------------------------------
# 系统清理函数
# -------------------------------
run_system_clean() {
    clear
    echo -e "${CYAN}==================================================${RESET}"
    echo -e "${MAGENTA}              开始系统清理                      ${RESET}"
    echo -e "${CYAN}==================================================${RESET}"

    if [ -f /etc/debian_version ]; then
        echo -e "${GREEN}>>> 正在清理 APT 缓存和不再需要的软件包...${RESET}"
        apt autoremove -y && apt clean
    elif [ -f /etc/redhat-release ]; then
        echo -e "${GREEN}>>> 正在清理 YUM/DNF 缓存...${RESET}"
        yum clean all || dnf clean all
    else
        echo -e "${RED}❌ 未知系统，无法执行自动清理。${RESET}"
    fi

    echo -e "${GREEN}✅ 系统清理完成！${RESET}"
    read -n1 -p "按任意键返回菜单..."
}

# -------------------------------
# Docker 管理/安装函数 (已修正语法)
# -------------------------------
docker_menu() {
    clear
    echo -e "${CYAN}==================================================${RESET}"
    echo -e "${MAGENTA}                 Docker 管理                      ${RESET}"
    echo -e "${CYAN}==================================================${RESET}"

    # 检查 Docker 是否安装
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}⚠️ Docker 未安装！${RESET}"
        echo -e "1) ${GREEN}安装 Docker${RESET}"
        echo "2) 返回主菜单"
        read -p "输入数字选择: " docker_choice
        case "$docker_choice" in
            1)
                install_docker
                ;;
            2)
                return
                ;;
            *)
                echo -e "${RED}无效选项，返回主菜单。${RESET}"
                sleep 2
                return
                ;;
        esac
    else
        # Docker 已安装的菜单
        echo -e "${GREEN}✅ Docker 已安装。${RESET}"
        echo "1) 查看运行中的容器"
        echo "2) 查看所有容器"
        echo "3) 清理 Docker 悬空数据 (docker system prune)"
        echo "4) 返回主菜单"
        read -p "输入数字选择: " docker_choice
        case "$docker_choice" in
            1)
                echo -e "${YELLOW}运行中的容器:${RESET}"
                docker ps
                read -n1 -p "按任意键继续..."
                docker_menu
                ;;
            2)
                echo -e "${YELLOW}所有容器:${RESET}"
                docker ps -a
                read -n1 -p "按任意键继续..."
                docker_menu
                ;;
            3)
                echo -e "${YELLOW}正在执行 docker system prune -a -f...${RESET}"
                docker system prune -a -f
                echo -e "${GREEN}✅ Docker 清理完成。${RESET}"
                read -n1 -p "按任意键继续..."
                docker_menu
                ;;
            4)
                return
                ;;
            *)
                echo -e "${RED}无效选项，返回主菜单。${RESET}"
                sleep 2
                return
                ;;
        esac
    fi
}

install_docker() {
    clear
    echo -e "${CYAN}==================================================${RESET}"
    echo -e "${MAGENTA}                 正在安装 Docker                  ${RESET}"
    echo -e "${CYAN}==================================================${RESET}"
    
    if curl -fsSL https://get.docker.com -o get-docker.sh; then
        sh get-docker.sh
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Docker 安装成功！${RESET}"
            systemctl start docker
            systemctl enable docker
            echo -e "${YELLOW}Docker 服务已启动并设置开机自启。${RESET}"
        else
            echo -e "${RED}❌ Docker 安装脚本执行失败。${RESET}"
        fi
    else
        echo -e "${RED}❌ 无法下载 Docker 安装脚本。请检查网络。${RESET}"
    fi

    rm -f get-docker.sh
    read -n1 -p "按任意键返回 Docker 管理菜单..."
    docker_menu
}

# -------------------------------
# 卸载脚本功能
# -------------------------------
uninstall_script() {
    clear
    echo -e "${CYAN}==================================================${RESET}"
    echo -e "${MAGENTA}               卸载 ${SCRIPT_NAME} 脚本             ${RESET}"
    echo -e "${CYAN}==================================================${RESET}"
    
    read -r -p "⚠️ 警告：这将删除当前目录下的 ${SCRIPT_NAME} 和 ${RESULT_FILE} 文件。是否继续? (y/N) " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -f "$SCRIPT_NAME" "$RESULT_FILE"
        echo -e "${GREEN}✅ ${SCRIPT_NAME} 和 ${RESULT_FILE} 已成功删除。${RESET}"
        echo -e "${YELLOW}您可能需要手动删除 BBR 切换脚本 (tcp.sh) 或 Docker 安装脚本 (get-docker.sh)（如果存在）。${RESET}"
        echo "退出脚本..."
        exit 0
    else
        echo -e "${YELLOW}操作取消，返回主菜单。${RESET}"
        sleep 2
    fi
}

# -------------------------------
# 交互菜单
# -------------------------------
show_menu() {
    while true; do
        print_welcome
        echo "请选择操作："
        echo "--- BBR 测速/切换 ---"
        echo "1) 执行 BBR 测速"
        echo "2) 安装/切换 BBR 内核 (下载外部脚本)"
        echo "--- 系统管理 ---"
        echo "3) 查看系统信息"
        echo "4) 系统更新 (Update & Upgrade)"
        echo "5) 系统清理 (Cache & Autoremove)"
        echo "6) Docker 管理/安装"
        echo "--- 退出 ---"
        echo "7) 退出脚本"
        echo "8) 卸载此脚本"
        
        read -p "输入数字选择: " choice
        
        case "$choice" in
            1)
                > "$RESULT_FILE"
                for MODE in "BBR" "BBR Plus" "BBRv2" "BBRv3"; do
                    run_test "$MODE"
                done
                echo -e "${CYAN}=== 测试完成，结果汇总 ===${RESET}"
                cat "$RESULT_FILE"
                echo ""
                read -n1 -p "按任意键返回菜单..."
                echo ""
                ;;
            2)
                download_bbr_switch
                ;;
            3)
                show_system_info
                ;;
            4)
                run_system_update
                ;;
            5)
                run_system_clean
                ;;
            6)
                docker_menu
                ;;
            7)
                echo "退出脚本"
                exit 0
                ;;
            8)
                uninstall_script
                ;;
            *)
                echo -e "${RED}无效选项，请输入 1-8${RESET}"
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
