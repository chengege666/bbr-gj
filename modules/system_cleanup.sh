#!/bin/bash
# 系统清理模块

main() {
    echo -e "${CYAN}=== 系统清理 ===${RESET}"
    if command -v apt >/dev/null 2>&1; then
        apt autoremove -y
        apt clean
        apt autoclean
        echo -e "${GREEN}APT 系统清理完成${RESET}"
    elif command -v yum >/dev/null 2>&1; then
        yum autoremove -y
        yum clean all
        echo -e "${GREEN}YUM 系统清理完成${RESET}"
    elif command -v dnf >/dev/null 2>&1; then
        dnf autoremove -y
        dnf clean all
        echo -e "${GREEN}DNF 系统清理完成${RESET}"
    else
        echo -e "${RED}❌ 无法识别包管理器${RESET}"
    fi
    
    echo -e "${GREEN}系统清理操作完成${RESET}"
    read -n1 -p "按任意键继续..."
    echo
}
