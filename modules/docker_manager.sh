#!/bin/bash
# Docker管理模块

# 检查Docker环境状态
check_docker_status() {
    if command -v docker >/dev/null 2>&1; then
        echo -e "\033[1;32m环境已经安装\033[0m"
        
        # 获取容器数量
        local container_count=$(docker ps -aq 2>/dev/null | wc -l)
        echo -e "\033[1;32m容器: $container_count\033[0m"
        
        # 获取镜像数量
        local image_count=$(docker images -q 2>/dev/null | wc -l)
        echo -e "\033[1;32m镜像: $image_count\033[0m"
        
        # 获取网络数量
        local network_count=$(docker network ls -q 2>/dev/null | wc -l)
        echo -e "\033[1;32m网络: $network_count\033[0m"
        
        # 获取卷数量
        local volume_count=$(docker volume ls -q 2>/dev/null | wc -l)
        echo -e "\033[1;32m卷: $volume_count\033[0m"
        return 0
    else
        echo -e "\033[1;31m环境未安装\033[0m"
        return 1
    fi
}

# 安装/更新Docker环境
install_update_docker() {
    echo -e "\033[1;36m>>> 安装/更新Docker环境\033[0m"
    
    if command -v docker >/dev/null 2>&1; then
        echo -e "\033[1;33m检测到已安装Docker，开始更新...\033[0m"
    else
        echo -e "\033[1;33m开始安装Docker...\033[0m"
    fi
    
    # 使用官方脚本安装/更新
    if curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun; then
        # 启动Docker服务
        systemctl enable docker
        systemctl start docker
        
        # 添加用户到docker组（如果存在当前用户）
        if [ "$SUDO_USER" ]; then
            usermod -aG docker "$SUDO_USER"
            echo -e "\033[1;33m已添加用户 $SUDO_USER 到docker组\033[0m"
        fi
        
        echo -e "\033[1;32mDocker环境安装/更新完成\033[0m"
    else
        echo -e "\033[1;31mDocker环境安装/更新失败\033[0m"
    fi
}

# 查看Docker全局状态
view_docker_status() {
    echo -e "\033[1;36m>>> Docker全局状态\033[0m"
    echo ""
    
    # Docker服务状态
    systemctl status docker --no-pager -l
    
    echo ""
    echo -e "\033[1;36mDocker信息:\033[0m"
    docker info 2>/dev/null | head -20
    
    echo ""
    echo -e "\033[1;36m运行中的容器:\033[0m"
    docker ps 2>/dev/null
    
    echo ""
    echo -e "\033[1;36m所有镜像:\033[0m"
    docker images 2>/dev/null | head -10
}

# Docker容器管理
docker_container_management() {
    while true; do
        echo -e "\033[1;36m=== Docker容器管理 ===\033[0m"
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
            *) echo -e "\033[1;31m无效选择\033[0m" ;;
        esac
        echo ""
    done
}

# Docker镜像管理
docker_image_management() {
    while true; do
        echo -e "\033[1;36m=== Docker镜像管理 ===\033[0m"
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
            *) echo -e "\033[1;31m无效选择\033[0m" ;;
        esac
        echo ""
    done
}

# Docker网络管理
docker_network_management() {
    while true; do
        echo -e "\033[1;36m=== Docker网络管理 ===\033[0m"
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
            *) echo -e "\033[1;31m无效选择\033[0m" ;;
        esac
        echo ""
    done
}

# Docker卷管理
docker_volume_management() {
    while true; do
        echo -e "\033[1;36m=== Docker卷管理 ===\033[0m"
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
            *) echo -e "\033[1;31m无效选择\033[0m" ;;
        esac
        echo ""
    done
}

# 清理无用的Docker资源
clean_docker_resources() {
    echo -e "\033[1;36m>>> 清理无用的Docker资源\033[0m"
    
    echo -e "\033[1;33m正在清理...\033[0m"
    
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
    
    echo -e "\033[1;32mDocker资源清理完成\033[0m"
}

# 更换Docker源
change_docker_registry() {
    echo -e "\033[1;极速模式 (已停止)
用户提出了问题
根据提供的GitHub仓库链接，我需要修改主脚本的路径配置。以下是修复后的主脚本代码：
