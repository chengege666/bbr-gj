#!/bin/bash
# 增强版VPS工具箱 v2.3
# GitHub: https://github.com/chengege666/bbr-gj

RESULT_FILE="bbr_result.txt"
SCRIPT_FILE="vps_toolbox.sh"
UNINSTALL_NOTE="vps_toolbox_uninstall_done.txt"

# -------------------------------
# 颜色定义与欢迎窗口
# -------------------------------
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
MAGENTA="\033[1;35m"
CYAN="\033[1;36m"
BLUE="\033[1;34m"
RESET="\033[0m"

print_welcome() {
    clear
    echo -e "${CYAN}==================================================${RESET}"
    echo -e "${MAGENTA}                VPS 工具箱 v3.0                ${RESET}"
    echo -e "${CYAN}--------------------------------------------------${RESET}"
    echo -e "${YELLOW}功能: BBR测速, 系统管理, GLIBC管理, Docker, SSH配置等${RESET}"
    echo -e "${GREEN}测速结果保存: ${RESULT_FILE}${RESET}"
    echo -e "${CYAN}==================================================${RESET}"
    echo ""
}

# -------------------------------
# Docker 管理菜单 (按照您图片的样式)
# -------------------------------
docker_management_menu() {
    while true; do
        # 获取Docker状态信息
        get_docker_status() {
            if command -v docker >/dev/null 2>&1; then
                CONTAINER_COUNT=$(docker ps -q 2>/dev/null | wc -l)
                IMAGE_COUNT=$(docker images -q 2>/dev/null | wc -l)
                NETWORK_COUNT=$(docker network ls -q 2>/dev/null | wc -l)
                VOLUME_COUNT=$(docker volume ls -q 2>/dev/null | wc -l)
                echo "环境已经安装 容器：$CONTAINER_COUNT 镜像：$IMAGE_COUNT 网络：$NETWORK_COUNT 卷：$VOLUME_COUNT"
            else
                echo "环境未安装 容器：0 镜像：0 网络：0 卷：0"
            fi
        }

        clear
        echo -e "${BLUE}==================================================${RESET}"
        echo -e "${CYAN}                  Docker 管理                  ${RESET}"
        echo -e "${BLUE}--------------------------------------------------${RESET}"
        echo -e "${YELLOW}$(get_docker_status)${RESET}"
        echo -e "${BLUE}--------------------------------------------------${RESET}"
        echo -e "1. 安装更新Docker环境 ✰"
        echo -e "2. 查看Docker全局状态 ✰" 
        echo -e "3. Docker容器管理 ✰"
        echo -e "4. Docker镜像管理"
        echo -e "5. Docker网络管理"
        echo -e "6. Docker卷管理"
        echo -e "7. 清理无用的docker容器和镜像网络数据卷"
        echo -e "8. 更换Docker源"
        echo -e "9. 编辑daemon.json文件"
        echo -e "10. 开启Docker-ipv6访问"
        echo -e "11. 关闭Docker-ipv6访问"
        echo -e "12. 备份/迁移/还原Docker环境"
        echo -e "13. 卸载Docker环境"
        echo -e "0. 返回主菜单"
        echo -e "${BLUE}--------------------------------------------------${RESET}"
        read -p "请输入你的选择: " docker_choice

        case $docker_choice in
            1) docker_install_update ;;
            2) docker_global_status ;;
            3) docker_container_management ;;
            4) docker_image_management ;;
            5) docker_network_management ;;
            6) docker_volume_management ;;
            7) docker_cleanup ;;
            8) change_docker_registry ;;
            9) edit_daemon_json ;;
            10) enable_docker_ipv6 ;;
            11) disable_docker_ipv6 ;;
            12) docker_backup_restore ;;
            13) docker_uninstall ;;
            0) return ;;
            *) echo -e "${RED}无效选择，请重新输入${RESET}"; sleep 2 ;;
        esac
    done
}

# Docker 安装更新
docker_install_update() {
    echo -e "${CYAN}>>> 安装/更新 Docker 环境...${RESET}"
    
    if command -v docker >/dev/null 2>&1; then
        echo -e "${YELLOW}检测到 Docker 已安装，开始更新...${RESET}"
        if command -v apt >/dev/null 2>&1; then
            apt update -y
            apt upgrade -y docker-ce docker-ce-cli containerd.io
        elif command -v yum >/dev/null 2>&1; then
            yum update -y docker-ce docker-ce-cli containerd.io
        fi
    else
        echo -e "${GREEN}开始安装 Docker...${RESET}"
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh --mirror Aliyun
        rm get-docker.sh
    fi
    
    # 启动 Docker 服务
    systemctl enable docker
    systemctl start docker
    
    if systemctl is-active --quiet docker; then
        echo -e "${GREEN}✅ Docker 环境安装/更新成功！${RESET}"
    else
        echo -e "${RED}❌ Docker 服务启动失败${RESET}"
    fi
    read -n1 -p "按任意键继续..."
}

# 查看 Docker 全局状态
docker_global_status() {
    echo -e "${CYAN}>>> Docker 全局状态信息${RESET}"
    
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}Docker 未安装${RESET}"
        return
    fi
    
    echo -e "${GREEN}Docker 版本:${RESET}"
    docker version --format 'Client: {{.Client.Version}}\nServer: {{.Server.Version}}' 2>/dev/null || docker version
    
    echo -e "${GREEN}系统信息:${RESET}"
    docker system info
    
    echo -e "${GREEN}磁盘使用:${RESET}"
    docker system df
    
    read -n1 -p "按任意键继续..."
}

# Docker 容器管理
docker_container_management() {
    while true; do
        clear
        echo -e "${CYAN}>>> Docker 容器管理${RESET}"
        echo -e "${GREEN}运行中的容器:${RESET}"
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null
        
        echo -e "${YELLOW}所有容器:${RESET}"
        docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null
        
        echo ""
        echo "1) 启动容器"
        echo "2) 停止容器"
        echo "3) 重启容器"
        echo "4) 删除容器"
        echo "5) 查看容器日志"
        echo "6) 进入容器终端"
        echo "0) 返回上级菜单"
        read -p "请选择操作: " container_choice

        case $container_choice in
            1) 
                read -p "输入要启动的容器名: " container_name
                docker start "$container_name" 2>/dev/null && echo -e "${GREEN}容器启动成功${RESET}" || echo -e "${RED}启动失败${RESET}"
                ;;
            2) 
                read -p "输入要停止的容器名: " container_name
                docker stop "$container_name" 2>/dev/null && echo -e "${GREEN}容器停止成功${RESET}" || echo -e "${RED}停止失败${RESET}"
                ;;
            3) 
                read -p "输入要重启的容器名: " container_name
                docker restart "$container_name" 2>/dev/null && echo -e "${GREEN}容器重启成功${RESET}" || echo -e "${RED}重启失败${RESET}"
                ;;
            4) 
                read -p "输入要删除的容器名: " container_name
                docker rm "$container_name" 2>/dev/null && echo -e "${GREEN}容器删除成功${RESET}" || echo -e "${RED}删除失败${RESET}"
                ;;
            5) 
                read -p "输入要查看日志的容器名: " container_name
                docker logs "$container_name" 2>/dev/null || echo -e "${RED}查看日志失败${RESET}"
                ;;
            6) 
                read -p "输入要进入的容器名: " container_name
                docker exec -it "$container_name" /bin/bash 2>/dev/null || 
                docker exec -it "$container_name" /bin/sh 2>/dev/null || 
                echo -e "${RED}进入容器失败${RESET}"
                ;;
            0) break ;;
            *) echo -e "${RED}无效选择${RESET}" ;;
        esac
        read -n1 -p "按任意键继续..."
    done
}

# Docker 镜像管理
docker_image_management() {
    while true; do
        clear
        echo -e "${CYAN}>>> Docker 镜像管理${RESET}"
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}" 2>/dev/null
        
        echo ""
        echo "1) 拉取镜像"
        echo "2) 删除镜像"
        echo "3) 导出镜像"
        echo "4) 导入镜像"
        echo "0) 返回上级菜单"
        read -p "请选择操作: " image_choice

        case $image_choice in
            1) 
                read -p "输入镜像名 (如 nginx:latest): " image_name
                docker pull "$image_name" 2>/dev/null && echo -e "${GREEN}镜像拉取成功${RESET}" || echo -e "${RED}拉取失败${RESET}"
                ;;
            2) 
                read -p "输入要删除的镜像名: " image_name
                docker rmi "$image_name" 2>/dev/null && echo -e "${GREEN}镜像删除成功${RESET}" || echo -e "${RED}删除失败${RESET}"
                ;;
            3) 
                read -p "输入要导出的镜像名: " image_name
                read -p "输入导出文件名: " export_file
                docker save -o "$export_file" "$image_name" 2>/dev/null && echo -e "${GREEN}镜像导出成功${RESET}" || echo -e "${RED}导出失败${RESET}"
                ;;
            4) 
                read -p "输入要导入的文件名: " import_file
                docker load -i "$import_file" 2>/dev/null && echo -e "${GREEN}镜像导入成功${RESET}" || echo -e "${RED}导入失败${RESET}"
                ;;
            0) break ;;
            *) echo -e "${RED}无效选择${RESET}" ;;
        esac
        read -n1 -p "按任意键继续..."
    done
}

# Docker 网络管理
docker_network_management() {
    echo -e "${CYAN}>>> Docker 网络管理${RESET}"
    docker network ls
    read -n1 -p "按任意键继续..."
}

# Docker 卷管理
docker_volume_management() {
    echo -e "${CYAN}>>> Docker 卷管理${RESET}"
    docker volume ls
    read -n1 -p "按任意键继续..."
}

# 清理无用的 Docker 资源
docker_cleanup() {
    echo -e "${CYAN}>>> 清理无用的 Docker 资源${RESET}"
    
    echo -e "${YELLOW}正在清理...${RESET}"
    docker system prune -f 2>/dev/null
    docker volume prune -f 2>/dev/null
    docker network prune -f 2>/dev/null
    
    echo -e "${GREEN}✅ 清理完成${RESET}"
    read -n1 -p "按任意键继续..."
}

# 更换 Docker 源
change_docker_registry() {
    echo -e "${CYAN}>>> 更换 Docker 镜像源${RESET}"
    
    DAEMON_JSON="/etc/docker/daemon.json"
    
    echo "选择镜像源:"
    echo "1) 阿里云"
    echo "2) 腾讯云"
    echo "3) 华为云"
    echo "4) 中科大"
    echo "5) 网易"
    echo "6) 自定义"
    read -p "请选择: " registry_choice

    case $registry_choice in
        1) REGISTRY="https://registry.cn-hangzhou.aliyuncs.com" ;;
        2) REGISTRY="https://mirror.ccs.tencentyun.com" ;;
        3) REGISTRY="https://05f073ad3c0010ea0f4bc00b7105ec20.mirror.swr.myhuaweicloud.com" ;;
        4) REGISTRY="https://docker.mirrors.ustc.edu.cn" ;;
        5) REGISTRY="https://hub-mirror.c.163.com" ;;
        6) 
            read -p "输入自定义镜像源: " REGISTRY
            ;;
        *) 
            echo -e "${RED}无效选择${RESET}"
            return
            ;;
    esac

    # 备份原配置
    if [ -f "$DAEMON_JSON" ]; then
        cp "$DAEMON_JSON" "$DAEMON_JSON.bak"
    fi

    # 创建新配置
    cat > "$DAEMON_JSON" << EOF
{
  "registry-mirrors": ["$REGISTRY"]
}
EOF

    echo -e "${GREEN}镜像源已设置为: $REGISTRY${RESET}"
    systemctl restart docker
    echo -e "${GREEN}Docker 服务已重启${RESET}"
    read -n1 -p "按任意键继续..."
}

# 编辑 daemon.json
edit_daemon_json() {
    echo -e "${CYAN}>>> 编辑 daemon.json${RESET}"
    
    DAEMON_JSON="/etc/docker/daemon.json"
    if [ ! -f "$DAEMON_JSON" ]; then
        echo -e "${YELLOW}文件不存在，创建新配置${RESET}"
        echo '{}' > "$DAEMON_JSON"
    fi
    
    # 使用 vi 编辑
    vi "$DAEMON_JSON"
    
    # 重启 Docker 使配置生效
    systemctl restart docker
    echo -e "${GREEN}配置已应用，Docker 服务已重启${RESET}"
    read -n1 -p "按任意键继续..."
}

# 开启 IPv6
enable_docker_ipv6() {
    echo -e "${CYAN}>>> 开启 Docker IPv6 支持${RESET}"
    echo -e "${YELLOW}此功能需要手动配置网络，请谨慎操作${RESET}"
    read -n1 -p "按任意键继续..."
}

# 关闭 IPv6
disable_docker_ipv6() {
    echo -e "${CYAN}>>> 关闭 Docker IPv6 支持${RESET}"
    echo -e "${YELLOW}此功能需要手动配置网络，请谨慎操作${RESET}"
    read -n1 -p "按任意键继续..."
}

# 备份/迁移/还原
docker_backup_restore() {
    echo -e "${CYAN}>>> Docker 环境备份/迁移/还原${RESET}"
    echo -e "${YELLOW}此功能正在开发中...${RESET}"
    read -n1 -p "按任意键继续..."
}

# 卸载 Docker
docker_uninstall() {
    echo -e "${RED}>>> 卸载 Docker 环境${RESET}"
    read -p "确定要卸载 Docker 吗？这将删除所有容器和镜像！(y/N): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        if command -v apt >/dev/null 2>&1; then
            apt remove --purge -y docker-ce docker-ce-cli containerd.io
            apt autoremove -y
        elif command -v yum >/dev/null 2>&1; then
            yum remove -y docker-ce docker-ce-cli containerd.io
        fi
        rm -rf /var/lib/docker
        echo -e "${GREEN}Docker 已卸载${RESET}"
    else
        echo -e "${GREEN}已取消卸载${RESET}"
    fi
    read -n1 -p "按任意键继续..."
}

# -------------------------------
# 修改主菜单，添加 Docker 管理选项
# -------------------------------
show_menu() {
    if [ -z "$IP_VERSION" ]; then
        IP_VERSION="4"
    fi
    
    while true; do
        print_welcome
        echo -e "请选择操作："
        echo -e "${GREEN}--- BBR 测速与切换 ---${RESET}"
        echo "1) BBR 综合测速 (BBR/BBR Plus/BBRv2/BBRv3 对比)"
        echo "2) 安装/切换 BBR 内核"
        echo -e "${GREEN}--- VPS 系统管理 ---${RESET}"
        echo "3) 查看系统信息 (OS/CPU/内存/IP/BBR/GLIBC)"
        echo "4) 更新软件包并升级 (不升级内核)"
        echo "5) 系统清理 (清理旧版依赖包)"
        echo "6) IPv4/IPv6 切换 (当前: IPv$IP_VERSION)"
        echo "7) 系统时区调整"
        echo "8) 系统重启"
        echo "9) GLIBC 管理"
        echo "10) 全面系统升级 (含内核升级)"
        echo -e "${GREEN}--- 服务管理 ---${RESET}"
        echo "11) Docker 容器管理 ✰ (新增完整管理菜单)"
        echo "12) SSH 端口与密码修改"
        echo -e "${GREEN}--- 其他 ---${RESET}"
        echo "13) 卸载脚本及残留文件"
        echo "0) 退出脚本"
        echo ""
        read -p "输入数字选择: " choice
        
        case "$choice" in
            1) bbr_test_menu ;;
            2) run_bbr_switch ;;
            3) show_sys_info ;;
            4) sys_update ;;
            5) sys_cleanup ;;
            6) ip_version_switch ;;
            7) timezone_adjust ;;
            8) system_reboot ;;
            9) glibc_menu ;;
            10) full_system_upgrade ;;
            11) docker_management_menu ;;  # 修改这里，调用新的 Docker 管理菜单
            12) ssh_config_menu ;;
            13) uninstall_script ;;
            0) echo -e "${CYAN}感谢使用，再见！${RESET}"; exit 0 ;;
            *) echo -e "${RED}无效选项，请输入 0-13${RESET}"; sleep 2 ;;
        esac
    done
}

# 保留原有的其他函数不变（bbr_test_menu, run_bbr_switch, show_sys_info 等）
# ... 原有代码保持不变 ...

# -------------------------------
# 主程序
# -------------------------------
check_root
check_deps
show_menu
