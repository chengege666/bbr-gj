#!/bin/bash
# Docker管理模块

# 检查Docker环境状态
check_docker_status() {
    if command -v docker >/dev/null 2>&1; then
        echo -e "${GREEN}环境已经安装${RESET}"
        
        # 获取容器数量
        local container_count=$(docker ps -aq 2>/dev/null | wc -l)
        echo -e "${GREEN}容器: $container_count${RESET}"
        
        # 获取镜像数量
        local image_count=$(docker images -q 2>/dev/null | wc -l)
        echo -e "${GREEN}镜像: $image_count${RESET}"
        
        # 获取网络数量
        local network_count=$(docker network ls -q 2>/dev/null | wc -l)
        echo -e "${GREEN}网络: $network_count${RESET}"
        
        # 获取卷数量
        local volume_count=$(docker volume ls -q 2>/dev/null | wc -l)
        echo -e "${GREEN}卷: $volume_count${RESET}"
        return 0
    else
        echo -e "${RED}环境未安装${RESET}"
        return 1
    fi
}

# 安装/更新Docker环境
install_update_docker() {
    echo -e "${CYAN}>>> 安装/更新Docker环境${RESET}"
    
    if command -v docker >/dev/null 2>&1; then
        echo -e "${YELLOW}检测到已安装Docker，开始更新...${RESET}"
    else
        echo -e "${YELLOW}开始安装Docker...${RESET}"
    fi
    
    # 使用官方脚本安装/更新
    curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
    
    # 启动Docker服务
    systemctl enable docker
    systemctl start docker
    
    # 添加用户到docker组（如果存在当前用户）
    if [ "$SUDO_USER" ]; then
        usermod -aG docker "$SUDO_USER"
        echo -e "${YELLOW}已添加用户 $SUDO_USER 到docker组${RESET}"
    fi
    
    echo -e "${GREEN}Docker环境安装/更新完成${RESET}"
}

# 查看Docker全局状态
view_docker_status() {
    echo -e "${CYAN}>>> Docker全局状态${RESET}"
    echo ""
    
    # Docker服务状态
    systemctl status docker --no-pager -l
    
    echo ""
    echo -e "${CYAN}Docker信息:${RESET}"
    docker info 2>/dev/null | head -20
    
    echo ""
    echo -e "${CYAN}运行中的容器:${RESET}"
    docker ps 2>/dev/null
    
    echo ""
    echo -e "${CYAN}所有镜像:${RESET}"
    docker images 2>/dev/null | head -10
}

# Docker容器管理
docker_container_management() {
    while true; do
        echo -e "${CYAN}=== Docker容器管理 ===${RESET}"
        echo "1) 查看所有容器"
        echo "2) 查看运行中容器"
        echo "3) 启动容器"
        echo "4) 停止容器"
        echo "5) 重启容器"
        echo "6) 删除容器"
        echo "7) 查看容器日志"
        echo "8) 进入容器终端"
        echo "0) 返回上级菜单"
        
        read -p "请输入选择: " choice
        
        case "$choice" in
            1) docker ps -a ;;
            2) docker ps ;;
            3)
                read -p "请输入容器名或ID: " container
                docker start "$container"
                ;;
            4)
                read -p "请输入容器名或ID: " container
                docker stop "$container"
                ;;
            5)
                read -p "请输入容器名或ID: " container
                docker restart "$container"
                ;;
            6)
                read -p "请输入容器名或ID: " container
                docker rm "$container"
                ;;
            7)
                read -p "请输入容器名或ID: " container
                docker logs "$container"
                ;;
            8)
                read -p "请输入容器名或ID: " container
                docker exec -it "$container" /bin/bash || docker exec -it "$container" /bin/sh
                ;;
            0) break ;;
            *) echo -e "${RED}无效选择${RESET}" ;;
        esac
        echo ""
    done
}

# Docker镜像管理
docker_image_management() {
    while true; do
        echo -e "${CYAN}=== Docker镜像管理 ===${RESET}"
        echo "1) 查看所有镜像"
        echo "2) 拉取镜像"
        echo "3) 删除镜像"
        echo "4) 构建镜像"
        echo "0) 返回上级菜单"
        
        read -p "请输入选择: " choice
        
        case "$choice" in
            1) docker images ;;
            2)
                read -p "请输入镜像名: " image
                docker pull "$image"
                ;;
            3)
                read -p "请输入镜像名或ID: " image
                docker rmi "$image"
                ;;
            4)
                read -p "请输入Dockerfile路径: " path
                read -p "请输入镜像标签: " tag
                docker build -t "$tag" "$path"
                ;;
            0) break ;;
            *) echo -e "${RED}无效选择${RESET}" ;;
        esac
        echo ""
    done
}

# Docker网络管理
docker_network_management() {
    while true; do
        echo -e "${CYAN}=== Docker网络管理 ===${RESET}"
        echo "1) 查看所有网络"
        echo "2) 创建网络"
        echo "3) 删除网络"
        echo "4) 连接容器到网络"
        echo "0) 返回上级菜单"
        
        read -p "请输入选择: " choice
        
        case "$choice" in
            1) docker network ls ;;
            2)
                read -p "请输入网络名: " network
                read -p "请输入驱动类型: " driver
                docker network create --driver "$driver" "$network"
                ;;
            3)
                read -p "请输入网络名或ID: " network
                docker network rm "$network"
                ;;
            4)
                read -p "请输入容器名: " container
                read -p "请输入网络名: " network
                docker network connect "$network" "$container"
                ;;
            0) break ;;
            *) echo -e "${RED}无效选择${RESET}" ;;
        esac
        echo ""
    done
}

# Docker卷管理
docker_volume_management() {
    while true; do
        echo -e "${CYAN}=== Docker卷管理 ===${RESET}"
        echo "1) 查看所有卷"
        echo "2) 创建卷"
        echo "3) 删除卷"
        echo "0) 返回上级菜单"
        
        read -p "请输入选择: " choice
        
        case "$choice" in
            1) docker volume ls ;;
            2)
                read -p "请输入卷名: " volume
                docker volume create "$volume"
                ;;
            3)
                read -p "请输入卷名: " volume
                docker volume rm "$volume"
                ;;
            0) break ;;
            *) echo -e "${RED}无效选择${RESET}" ;;
        esac
        echo ""
    done
}

# 清理无用的Docker资源
clean_docker_resources() {
    echo -e "${CYAN}>>> 清理无用的Docker资源${RESET}"
    
    echo -e "${YELLOW}正在清理...${RESET}"
    
    # 清理停止的容器
    docker container prune -f
    
    # 清理悬空镜像
    docker image prune -f
    
    # 清理未使用的网络
    docker network prune -f
    
    # 清理未使用的卷
    docker volume prune -f
    
    # 清理构建缓存
    docker builder prune -f
    
    echo -e "${GREEN}Docker资源清理完成${RESET}"
}

# 更换Docker源
change_docker_registry() {
    echo -e "${CYAN}>>> 更换Docker源${RESET}"
    
    echo "请选择镜像源:"
    echo "1) Docker Hub官方源"
    echo "2) 阿里云镜像源"
    echo "3) 中科大镜像源"
    echo "4) 网易镜像源"
    echo "5) 腾讯云镜像源"
    
    read -p "请输入选择: " registry_choice
    
    case "$registry_choice" in
        1) REGISTRY="https://registry.docker-cn.com" ;;
        2) REGISTRY="https://registry.cn-hangzhou.aliyuncs.com" ;;
        3) REGISTRY="https://docker.mirrors.ustc.edu.cn" ;;
        4) REGISTRY="https://hub-mirror.c.163.com" ;;
        5) REGISTRY="https://mirror.ccs.tencentyun.com" ;;
        *) echo -e "${RED}无效选择，使用默认源${RESET}"; return ;;
    esac
    
    # 创建或修改daemon.json
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << EOF
{
    "registry-mirrors": ["$REGISTRY"]
}
EOF
    
    # 重启Docker服务
    systemctl restart docker
    echo -e "${GREEN}Docker源已更换为: $REGISTRY${RESET}"
}

# 编辑daemon.json文件
edit_daemon_json() {
    echo -e "${CYAN}>>> 编辑daemon.json文件${RESET}"
    
    if [ ! -f /etc/docker/daemon.json ]; then
        echo -e "${YELLOW}daemon.json文件不存在，创建新文件${RESET}"
        mkdir -p /etc/docker
        echo '{}' > /etc/docker/daemon.json
    fi
    
    # 使用vim或nano编辑
    if command -v vim >/dev/null 2>&1; then
        vim /etc/docker/daemon.json
    elif command -v nano >/dev/null 2>&1; then
        nano /etc/docker/daemon.json
    else
        echo -e "${YELLOW}请手动编辑 /etc/docker/daemon.json 文件${RESET}"
        return
    fi
    
    # 重启Docker服务使配置生效
    systemctl restart docker
    echo -e "${GREEN}daemon.json配置已生效${RESET}"
}

# 开启Docker IPv6访问
enable_docker_ipv6() {
    echo -e "${CYAN}>>> 开启Docker IPv6访问${RESET}"
    
    # 修改daemon.json启用IPv6
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << EOF
{
    "ipv6": true,
    "fixed-cidr-v6": "2001:db8:1::/64"
}
EOF
    
    systemctl restart docker
    echo -e "${GREEN}Docker IPv6访问已开启${RESET}"
}

# 关闭Docker IPv6访问
disable_docker_ipv6() {
    echo -e "${CYAN}>>> 关闭Docker IPv6访问${RESET}"
    
    if [ -f /etc/docker/daemon.json ]; then
        # 移除IPv6配置
        jq 'del(.ipv6?) | del(."fixed-cidr-v6"?)' /etc/docker/daemon.json > /tmp/daemon.json && mv /tmp/daemon.json /etc/docker/daemon.json
    fi
    
    systemctl restart docker
    echo -e "${GREEN}Docker IPv6访问已关闭${RESET}"
}

# 卸载Docker环境
uninstall_docker() {
    echo -e "${CYAN}>>> 卸载Docker环境${RESET}"
    
    read -p "确定要卸载Docker吗？这将删除所有容器和镜像！(y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}取消卸载${RESET}"
        return
    fi
    
    # 停止Docker服务
    systemctl stop docker
    systemctl disable docker
    
    # 卸载Docker包
    if command -v apt >/dev/null 2>&1; then
        apt remove -y docker docker-engine docker.io containerd runc
        apt purge -y docker-ce docker-ce-cli containerd.io
    elif command -v yum >/dev/null 2>&1; then
        yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
    fi
    
    # 删除Docker相关文件和目录
    rm -rf /var/lib/docker
    rm -rf /etc/docker
    rm -rf /var/run/docker.sock
    
    echo -e "${GREEN}Docker环境已卸载${RESET}"
}

# 主函数
main() {
    while true; do
        clear
        echo -e "${CYAN}==================================================${RESET}"
        echo -e "${MAGENTA}                  Docker管理                  ${RESET}"
        echo -e "${CYAN}==================================================${RESET}"
        echo ""
        
        # 显示Docker环境状态
        check_docker_status
        echo ""
        
        # 显示菜单选项（与图片完全一致）
        echo -e "${WHITE}安装更新Docker环境${RESET}"
        echo -e "1."
        echo -e "${WHITE}查看Docker全局状态${RESET}"
        echo -e "2."
        echo -e "${WHITE}Docker容器管理${RESET}"
        echo -e "4."
        echo -e "${WHITE}Docker镜像管理${RESET}"
        echo -e "5."
        echo -e "${WHITE}Docker网络管理${RESET}"
        echo -e "6."
        echo -e "${WHITE}Docker卷管理${RESET}"
        echo -e "7."
        echo -e "${WHITE}清理无用的docker容器和镜像网络数据卷${RESET}"
        echo -e "8."
        echo -e "${WHITE}更换Docker源${RESET}"
        echo -e "9."
        echo -e "${WHITE}编辑daemon.json文件${RESET}"
        echo -e "11."
        echo -e "${WHITE}开启Docker-ipv6访问${RESET}"
        echo -e "12."
        echo -e "${WHITE}关闭Docker-ipv6访问${RESET}"
        echo -e "20."
        echo -e "${WHITE}卸载Docker环境${RESET}"
        echo -e "0."
        echo -e "${WHITE}返回主菜单${RESET}"
        echo ""
        
        read -p "请输入你的选择: " choice
        
        case "$choice" in
            1) install_update_docker ;;
            2) view_docker_status ;;
            4) docker_container_management ;;
            5) docker_image_management ;;
            6) docker_network_management ;;
            7) docker_volume_management ;;
            8) clean_docker_resources ;;
            9) change_docker_registry ;;
            11) edit_daemon_json ;;
            12) enable_docker_ipv6 ;;
            13) disable_docker_ipv6 ;;
            20) uninstall_docker ;;
            0) break ;;
            *) echo -e "${RED}无效选择${RESET}"; sleep 2 ;;
        esac
        
        if [ "$choice" != "0" ]; then
            echo ""
            read -n1 -p "按任意键继续..."
        fi
    done
}

# 模块初始化
echo -e "${GREEN}✅ Docker管理模块加载完成${RESET}"
