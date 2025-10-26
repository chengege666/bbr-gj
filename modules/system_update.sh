#!/bin/bash
# 系统更新模块

main() {
    echo -e "${CYAN}=== 系统更新 ===${RESET}"
    if command -v apt >/dev/null 2>&1; then
        apt update -y && apt upgrade -y
        echo -e "${GREEN}APT 系统更新完成${RESET}"
    elif command -v yum >/dev/null 2>&1; then
        yum update -y
        echo -e "${GREEN}YUM 系统更新完成${RESET}"
    elif command -v dnf >/dev/null 2>&1; then
        dnf update -y
        echo -e "${GREEN}DNF 系统更新完成${RESET}"
    else
        echo -e "${RED}❌ 无法识别包管理器${RESET}"
    fi
    read -n1 -p "按任意键继续..."
    echo
}
