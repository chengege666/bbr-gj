#!/bin/bash
# Docker管理模块

main() {
    echo -e "${CYAN}=== Docker 管理 ===${RESET}"
    
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${YELLOW}Docker 未安装，是否安装？(y/N): ${RESET}"
        read -r install_docker
        if [[ "$install_docker" == "y" || "$install_docker" == "Y" ]]; then
            echo -e "${CYAN}安装 Docker...${RESET}"
            curl -fsSL https://get.docker.com | bash
            systemctl enable docker
            systemctl start docker
            echo -e "${GREEN}Docker 安装完成${RESET}"
        else
            return
        fi
    fi
    
    echo "1) 启动 Docker 服务"
    echo "2) 停止 Docker 服务"
    echo "3) 重启 Docker 服务"
    echo "4) 查看 Docker 状态"
    echo "5) 返回主菜单"
    
    read -p "请输入选择: " docker_choice
    case "$docker_choice" in
        1) systemctl start docker; echo -e "${GREEN}Docker 已启动${RESET}" ;;
        2) systemctl stop docker; echo -e "${GREEN}Docker 已停止${RESET}" ;;
        3) systemctl restart docker; echo -e "${GREEN}Docker 已重启${RESET}" ;;
        4) systemctl status docker ;;
        5) return ;;
        *) echo -e "${RED}无效选择${RESET}" ;;
    esac
    read -n1 -p "按任意键继续..."
    echo
}
