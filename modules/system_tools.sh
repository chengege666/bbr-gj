#!/bin/bash
# 系统工具模块

main() {
    echo -e "${CYAN}=== 系统工具 ===${RESET}"
    echo "1) 查看系统日志"
    echo "2) 查看服务状态"
    echo "3) 进程管理"
    echo "4) 返回主菜单"
    
    read -p "请输入选择: " tool_choice
    case "$tool_choice" in
        1)
            echo -e "${CYAN}系统日志 (最后50行):${RESET}"
            tail -50 /var/log/syslog 2>/dev/null || tail -50 /var/log/messages 2>/dev/null || echo "无法查看系统日志"
            ;;
        2)
            echo -e "${CYAN}服务状态:${RESET}"
            systemctl list-units --type=service --state=running | head -20
            ;;
        3)
            echo -e "${CYAN}进程管理:${RESET}"
            if command -v htop >/dev/null 2>&1; then
                htop
            else
                top
            fi
            ;;
        4) return ;;
        *) echo -e "${RED}无效选择${RESET}" ;;
    esac
    read -n1 -p "按任意键继续..."
    echo
}
