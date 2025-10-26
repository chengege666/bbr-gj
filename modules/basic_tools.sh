#!/bin/bash
# 基础工具安装模块

main() {
    echo -e "${CYAN}=== 安装基础工具 ===${RESET}"
    local tools=("htop" "vim" "git" "wget" "curl" "unzip" "tar" "gzip" "net-tools")
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo -e "${YELLOW}安装 $tool...${RESET}"
            if command -v apt >/dev/null 2>&1; then
                apt install -y "$tool"
            elif command -v yum >/dev/null 2>&1; then
                yum install -y "$tool"
            fi
        else
            echo -e "${GREEN}$tool 已安装${RESET}"
        fi
    done
    echo -e "${GREEN}基础工具安装完成${RESET}"
    read -n1 -p "按任意键继续..."
    echo
}
