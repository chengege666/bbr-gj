#!/bin/bash
# 增强版VPS工具箱 v2.1.0 (增加 IP质量测试 功能)
# GitHub: https://github.com/chengege666/bbr-gj (原始)
# 此版本由AI根据用户需求合并修改

# -------------------------------
# 脚本定义
# -------------------------------
RESULT_FILE="bbr_result.txt"
SCRIPT_FILE="vps_toolbox.sh"
UNINSTALL_NOTE="vps_toolbox_uninstall_done.txt"
SCRIPT_PATH=$(readlink -f "$0")

# NPM (Nginx Proxy Manager) 相关路径定义
NPM_DIR="/opt/nginx-proxy-manager"
NPM_COMPOSE_FILE="$NPM_DIR/docker-compose.yml"

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
    echo -e "${MAGENTA}              增强版 VPS 工具箱 v2.1.0           ${RESET}"
    echo -e "${CYAN}--------------------------------------------------${RESET}"
    echo -e "${YELLOW}功能: 系统管理, BBR, 安全, Docker, NPM等${RESET}"
    echo -e "${CYAN}==================================================${RESET}"
    echo ""
}

# -------------------------------
# 辅助函数
# -------------------------------
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}❌❌ 错误：请使用 root 权限运行本脚本${RESET}"
        echo "👉 使用方法: sudo bash $0"
        exit 1
    fi
}

# 依赖安装
install_deps() {
    PKGS="curl wget git speedtest-cli net-tools build-essential iptables bc"
    if command -v apt >/dev/null 2>&1; then
        apt update -y
        apt install -y $PKGS
    elif command -v yum >/dev/null 2>&1; then
        yum install -y $PKGS
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y $PKGS
    else
        echo -e "${YELLOW}⚠️ 未知系统，请手动安装依赖: $PKGS${RESET}"
        read -n1 -p "按任意键继续菜单..."
    fi
}

check_deps() {
    for CMD in curl wget git speedtest-cli iptables bc; do
        if ! command -v $CMD >/dev/null 2>&1; then
            echo -e "${YELLOW}未检测到 $CMD，正在尝试安装依赖...${RESET}"
            install_deps
            break
        fi
    done
}

# 获取包管理器
get_pm() {
    if command -v apt >/dev/null 2>&1; then
        echo "apt"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    else
        echo "unknown"
    fi
}

# 获取编辑器
get_editor() {
    echo "${EDITOR:-vi}"
}

# 暂停
pause() {
    echo ""
    read -n1 -p "按任意键返回菜单..."
}

# ====================================================================
# +++ 1-10: 系统工具 +++
# ====================================================================

# 1. 设置脚本启动快捷键
set_alias() {
    echo -e "${CYAN}=== 设置脚本启动快捷键 ===${RESET}"
    local shell_rc=""
    if [ -n "$BASH_VERSION" ]; then
        shell_rc="$HOME/.bashrc"
    elif [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    else
        shell_rc="$HOME/.profile"
    fi

    if grep -q "alias vps=" "$shell_rc"; then
        echo -e "${YELLOW}快捷键 'vps' 已经存在于 $shell_rc 中。${RESET}"
    else
        echo -e "\n# VPS 工具箱快捷键" >> "$shell_rc"
        echo "alias vps='bash $SCRIPT_PATH'" >> "$shell_rc"
        echo -e "${GREEN}✅ 已添加快捷键 'vps' 到 $shell_rc${RESET}"
        echo -e "${YELLOW}请运行 'source $shell_rc' 或重新登录以使其生效。${RESET}"
    fi
    pause
}

# 2. SSH 与 ROOT 管理 (合并 2, 3, 6, 24)
manage_ssh_menu() {
    SSH_CONFIG="/etc/ssh/sshd_config"
    if [ ! -f "$SSH_CONFIG" ]; then
        echo -e "${RED}❌❌ 未找到 SSH 配置文件 ($SSH_CONFIG)。${RESET}"
        pause
        return
    fi

    while true; do
        clear
        echo -e "${CYAN}=== SSH 与 ROOT 管理 ===${RESET}"
        echo "------------------------------------------------"
        echo -e "当前端口: ${YELLOW}$(grep -E '^Port' "$SSH_CONFIG" 2>/dev/null | awk '{print $2}' || echo "22")${RESET}"
        echo -e "ROOT密码登录: ${YELLOW}$(grep -E '^\s*PermitRootLogin' "$SSH_CONFIG" 2>/dev/null | awk '{print $2}' || echo "yes")${RESET}"
        echo -e "密码认证: ${YELLOW}$(grep -E '^\s*PasswordAuthentication' "$SSH_CONFIG" 2>/dev/null | awk '{print $2}' || echo "yes")${RESET}"
        echo "------------------------------------------------"
        echo "1. 修改 SSH 端口"
        echo "2. 修改 ROOT 密码"
        echo "3. 允许 ROOT 密码登录"
        echo "4. 仅允许 ROOT 密钥登录 (禁用密码)"
        echo "5. 禁止 ROOT 登录 (推荐)"
        echo "6. 开启 SSH 密码认证 (全局)"
        echo "7. 关闭 SSH 密码认证 (仅限密钥)"
        echo "0. 返回主菜单"
        echo "------------------------------------------------"
        read -p "请输入你的选择: " choice

        case "$choice" in
            1)
                read -p "输入新的 SSH 端口 (1-65535): " new_port
                if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 1 ] && [ "$new_port" -le 65535 ]; then
                    sed -i "s/^#\?Port\s\+.*$/Port $new_port/" "$SSH_CONFIG"
                    echo -e "${GREEN}✅ SSH 端口已修改为 $new_port${RESET}"
                else
                    echo -e "${RED}❌❌ 端口输入无效。${RESET}"
                fi
                ;;
            2)
                echo -e "${YELLOW}请设置新的 root 密码:${RESET}"
                passwd root
                ;;
            3)
                sed -i "s/^\s*#\?PermitRootLogin\s\+.*/PermitRootLogin yes/" "$SSH_CONFIG"
                echo -e "${GREEN}✅ 已设置为 [允许 ROOT 密码登录]。${RESET}"
                ;;
            4)
                sed -i "s/^\s*#\?PermitRootLogin\s\+.*/PermitRootLogin prohibit-password/" "$SSH_CONFIG"
                echo -e "${GREEN}✅ 已设置为 [仅允许 ROOT 密钥登录]。${RESET}"
                ;;
            5)
                sed -i "s/^\s*#\?PermitRootLogin\s\+.*/PermitRootLogin no/" "$SSH_CONFIG"
                echo -e "${GREEN}✅ 已设置为 [禁止 ROOT 登录]。${RESET}"
                echo -e "${YELLOW}警告：请确保您已有其他可登录的非root用户！${RESET}"
                ;;
            6)
                sed -i "s/^\s*#\?PasswordAuthentication\s\+.*/PasswordAuthentication yes/" "$SSH_CONFIG"
                echo -e "${GREEN}✅ 已开启 [SSH 密码认证]。${RESET}"
                ;;
            7)
                sed -i "s/^\s*#\?PasswordAuthentication\s\+.*/PasswordAuthentication no/" "$SSH_CONFIG"
                echo -e "${GREEN}✅ 已关闭 [SSH 密码认证]。${RESET}"
                echo -e "${YELLOW}警告：请确保您已配置密钥登录，否则将无法登录！${RESET}"
                ;;
            0) break ;;
            *) echo -e "${RED}无效选项${RESET}"; sleep 1 ;;
        esac

        if [[ "$choice" -ne 0 ]]; then
            echo -e "${GREEN}>>> 正在重启 SSH 服务...${RESET}"
            if command -v systemctl >/dev/null 2>&1; then
                systemctl restart sshd
            else
                /etc/init.d/sshd restart
            fi
            echo -e "${YELLOW}配置已应用。如果更改了端口，请使用新端口重连。${RESET}"
            pause
        fi
    done
}

# 3. 优化DNS地址
optimize_dns() {
    echo -e "${CYAN}=== 优化DNS地址 ===${RESET}"
    cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
EOF
    echo -e "${GREEN}✅ DNS 已优化为 Google 和 Cloudflare。${RESET}"
    echo -e "${YELLOW}注意：某些系统（如Ubuntu 18+）使用 systemd-resolved，此更改可能是临时的。${RESET}"
    pause
}

# 4. 禁用ROOT账户创建新账户
create_new_user() {
    echo -e "${CYAN}=== 禁用ROOT并创建新用户 ===${RESET}"
    read -p "请输入新用户名: " username
    if [ -z "$username" ]; then
        echo -e "${RED}用户名不能为空。${RESET}"
        pause
        return
    fi
    
    if id "$username" &>/dev/null; then
        echo -e "${RED}用户 $username 已存在。${RESET}"
        pause
        return
    fi

    useradd -m -s /bin/bash "$username"
    if [ $? -ne 0 ]; then
        echo -e "${RED}创建用户 $username 失败。${RESET}"
        pause
        return
    fi
    
    echo -e "${GREEN}✅ 用户 $username 创建成功。${RESET}"
    echo -e "${YELLOW}请为新用户 $username 设置密码:${RESET}"
    passwd "$username"
    
    read -p "是否将 $username 添加到 sudo 组 (允许执行root命令)? (y/n): " add_sudo
    if [[ "$add_sudo" == "y" || "$add_sudo" == "Y" ]]; then
        if command -v usermod >/dev/null 2>&1; then
             usermod -aG sudo "$username" # Debian/Ubuntu
             usermod -aG wheel "$username" # CentOS/RHEL
             echo -e "${GREEN}✅ 已将 $username 添加到 sudo/wheel 组。${RESET}"
        else
            echo -e "${RED}未找到 usermod 命令，请手动添加sudo权限。${RESET}"
        fi
    fi
    
    read -p "是否现在禁用 ROOT 登录 (PermitRootLogin no)? (y/n): " disable_root
    if [[ "$disable_root" == "y" || "$disable_root" == "Y" ]]; then
        sed -i "s/^\s*#\?PermitRootLogin\s\+.*/PermitRootLogin no/" "/etc/ssh/sshd_config"
        echo -e "${GREEN}✅ 已在 sshd_config 中设置 [禁止 ROOT 登录]。${RESET}"
        echo -e "${YELLOW}正在重启 SSH 服务...${RESET}"
        systemctl restart sshd
        echo -e "${RED}请立即使用新用户 $username 尝试重新登录！${RESET}"
    fi
    pause
}

# 5. 切换优先ipv4/ipv6
toggle_ip_priority() {
    echo -e "${CYAN}=== IPv4/IPv6 优先级切换 ===${RESET}"
    GAI_CONF="/etc/gai.conf"
    
    echo "1. 优先使用 IPv4"
    echo "2. 优先使用 IPv6 (默认)"
    echo "0. 返回"
    read -p "请选择: " ip_choice

    case "$ip_choice" in
        1)
            # 移除已有的 label ::ffff:0:0/96 100
            sed -i "/^label\s*::ffff:0:0\/96\s*100/d" "$GAI_CONF"
            # 添加 precedence ::ffff:0:0/96 100
            if ! grep -q "^precedence\s*::ffff:0:0\/96\s*100" "$GAI_CONF"; then
                echo "precedence ::ffff:0:0/96 100" >> "$GAI_CONF"
            fi
            echo -e "${GREEN}✅ 已设置为 IPv4 优先。${RESET}"
            ;;
        2)
            # 移除 precedence ::ffff:0:0/96 100
            sed -i "/^precedence\s*::ffff:0:0\/96\s*100/d" "$GAI_CONF"
            echo -e "${GREEN}✅ 已恢复为 IPv6 优先 (默认)。${RESET}"
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选择${RESET}"
            ;;
    esac
    pause
}


# 8. 系统重启
reboot_server() {
    echo -e "${CYAN}=== 系统重启 ===${RESET}"
    echo -e "${RED}警告：这将立即重启系统！${RESET}"
    read -p "确定要重启系统吗？(y/N): " confirm_reboot
    if [[ "$confirm_reboot" == "y" || "$confirm_reboot" == "Y" ]]; then
        echo -e "${GREEN}正在重启系统...${RESET}"
        reboot
    else
        echo -e "${GREEN}已取消重启${RESET}"
        pause
    fi
}

# 9. 系统清理 (来自原脚本)
cleanup_system() {
    echo -e "${CYAN}=== 系统清理 ===${RESET}"
    echo -e "${GREEN}>>> 正在清理缓存和旧版依赖包...${RESET}"
    local pm
    pm=$(get_pm)
    if [[ "$pm" == "apt" ]]; then
        apt autoremove -y
        apt clean
        apt autoclean
        echo -e "${GREEN}APT 清理完成${RESET}"
    elif [[ "$pm" == "yum" ]]; then
        yum autoremove -y
        yum clean all
        echo -e "${GREEN}YUM 清理完成${RESET}"
    elif [[ "$pm" == "dnf" ]]; then
        dnf autoremove -y
        dnf clean all
        echo -e "${GREEN}DNF 清理完成${RESET}"
    else
        echo -e "${RED}❌❌ 无法识别包管理器，请手动清理${RESET}"
    fi
    echo -e "${GREEN}系统清理操作完成。${RESET}"
    pause
}

# 10. 查看系统信息 (来自原脚本)
view_system_info() {
    echo -e "${CYAN}=== 系统详细信息 ===${RESET}"
    
    # 操作系统信息
    echo -e "${GREEN}操作系统:${RESET} $(cat /etc/os-release | grep PRETTY_NAME | cut -d "=" -f 2 | tr -d '"' 2>/dev/null || echo '未知')"
    echo -e "${GREEN}系统架构:${RESET} $(uname -m)"
    echo -e "${GREEN}内核版本:${RESET} $(uname -r)"
    echo -e "${GREEN}主机名:${RESET} $(hostname)"
    
    # CPU信息
    echo -e "${GREEN}CPU型号:${RESET} $(grep -m1 'model name' /proc/cpuinfo | awk -F': ' '{print $2}' 2>/dev/null || echo '未知')"
    echo -e "${GREEN}CPU核心数:${RESET} $(grep -c 'processor' /proc/cpuinfo 2>/dev/null || echo '未知')"
    
    # 内存信息
    MEM_TOTAL=$(free -h | grep Mem | awk '{print $2}' 2>/dev/null || echo '未知')
    MEM_USED=$(free -h | grep Mem | awk '{print $3}' 2>/dev/null || echo '未知')
    echo -e "${GREEN}内存总量:${RESET} $MEM_TOTAL | ${GREEN}已用:${RESET} $MEM_USED"
    
    # Swap信息
    SWAP_TOTAL=$(free -h | grep Swap | awk '{print $2}' 2>/dev/null || echo '未知')
    SWAP_USED=$(free -h | grep Swap | awk '{print $3}' 2>/dev/null || echo '未知')
    echo -e "${GREEN}Swap总量:${RESET} $SWAP_TOTAL | ${GREEN}已用:${RESET} $SWAP_USED"
    
    # 磁盘信息
    echo -e "${GREEN}磁盘使用情况:${RESET}"
    df -h | grep -E '^(/dev/|Filesystem)'
    
    # 网络信息
    echo -e "${GREEN}公网IPv4:${RESET} $(curl -s4 ifconfig.me 2>/dev/null || echo '获取失败')"
    echo -e "${GREEN}公网IPv6:${RESET} $(curl -s6 ifconfig.me 2>/dev/null || echo '获取失败')"
    
    # BBR信息
    CURRENT_BBR=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    CURRENT_QDISC=$(sysctl net.core.default_qdisc 2>/dev/null | awk '{print $3}')
    echo -e "${GREEN}当前拥塞控制算法:${RESET} $CURRENT_BBR"
    echo -e "${GREEN}当前队列规则:${RESET} $CURRENT_QDISC"
    
    # GLIBC信息
    GLIBC_VERSION=$(ldd --version 2>/dev/null | head -n1 | awk '{print $NF}')
    if [ -z "$GLIBC_VERSION" ]; then
        GLIBC_VERSION="未知"
    fi
    echo -e "${GREEN}GLIBC版本:${RESET} $GLIBC_VERSION"
    
    # 系统运行状态
    echo -e "${GREEN}系统运行时间:${RESET} $(uptime -p 2>/dev/null || uptime | awk '{print $3,$4,$5}' | sed 's/,//g')"
    echo -e "${GREEN}系统负载:${RESET} $(uptime | awk -F'load average: ' '{print $2}' 2>/dev/null || echo '未知')"
    
    pause
}


# ====================================================================
# +++ 11-20: 系统管理 +++
# ====================================================================

# 11. 查看端口占用状态
manage_ports() {
    echo -e "${CYAN}=== 查看端口占用状态 ===${RESET}"
    if ! command -v ss >/dev/null 2>&1; then
        echo -e "${YELLOW}未找到 'ss' 命令，正在尝试使用 'netstat'...${RESET}"
        if ! command -v netstat >/dev/null 2>&1; then
             echo -e "${RED}未安装 'net-tools' (netstat)，请先安装。${RESET}"
             pause
             return
        fi
        netstat -tulnp
    else
         ss -tulnp
    fi
    pause
}

# 12. 修改虚拟内存大小
manage_swap() {
    echo -e "${CYAN}=== 修改虚拟内存 (Swap) 大小 ===${RESET}"
    echo "当前 Swap 状态:"
    free -h
    echo "------------------------------------------------"
    echo "1. 添加/修改 Swap 文件 (推荐 1-2GB)"
    echo "2. 移除 Swap 文件"
    echo "0. 返回"
    read -p "请选择: " choice
    
    local swap_file="/swapfile"
    
    case "$choice" in
        1)
            read -p "请输入需要Swap的大小 (例如: 512M, 1G, 2G): " swap_size
            if [ -z "$swap_size" ]; then
                echo -e "${RED}输入不能为空。${RESET}"
                pause
                return
            fi
            
            # 检查是否已存在
            if [ -f "$swap_file" ]; then
                echo -e "${YELLOW}检测到已存在的 $swap_file，正在关闭并移除...${RESET}"
                swapoff "$swap_file"
                rm -f "$swap_file"
            fi
            
            echo -e "${CYAN}>>> 正在创建 $swap_size 大小的Swap文件...${RESET}"
            fallocate -l "$swap_size" "$swap_file"
            if [ $? -ne 0 ]; then
                echo -e "${RED}fallocate 失败，尝试使用 dd (速度较慢)...${RESET}"
                # 转换大小为 MB
                local size_mb
                if [[ "$swap_size" == *G ]]; then
                    size_mb=$((${swap_size%G} * 1024))
                elif [[ "$swap_size" == *M ]]; then
                    size_mb=${swap_size%M}
                else
                    echo -e "${RED}无法识别的大小格式，请使用 M 或 G。${RESET}"
                    pause
                    return
                fi
                dd if=/dev/zero of="$swap_file" bs=1M count="$size_mb"
            fi
            
            chmod 600 "$swap_file"
            mkswap "$swap_file"
            swapon "$swap_file"
            
            # 写入 /etc/fstab
            if ! grep -q "$swap_file" /etc/fstab; then
                echo "$swap_file none swap sw 0 0" >> /etc/fstab
            fi
            
            echo -e "${GREEN}✅ $swap_size Swap 创建并挂载成功。${RESET}"
            free -h
            ;;
        2)
            if [ -f "$swap_file" ]; then
                echo -e "${CYAN}>>> 正在关闭并移除 $swap_file...${RESET}"
                swapoff "$swap_file"
                rm -f "$swap_file"
                # 从 fstab 移除
                sed -i "\|$swap_file|d" /etc/fstab
                echo -e "${GREEN}✅ Swap 文件已移除。${RESET}"
                free -h
            else
                echo -e "${YELLOW}未找到 $swap_file，无需移除。${RESET}"
            fi
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选择${RESET}"
            ;;
    esac
    pause
}

# 13. 用户管理
manage_users_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== 用户管理 ===${RESET}"
        echo "当前登录用户:"
        who
        echo "------------------------------------------------"
        echo "1. 创建新用户"
        echo "2. 删除用户"
        echo "3. 修改用户密码"
        echo "4. 查看所有用户 (简略)"
        echo "0. 返回主菜单"
        echo "------------------------------------------------"
        read -p "请输入你的选择: " choice

        case "$choice" in
            1)
                read -p "请输入新用户名: " username
                if [ -z "$username" ]; then echo -e "${RED}用户名不能为空。${RESET}"; sleep 1; continue; fi
                useradd -m -s /bin/bash "$username"
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✅ 用户 $username 创建成功。${RESET}"
                    echo -e "${YELLOW}请为其设置密码:${RESET}"
                    passwd "$username"
                else
                    echo -e "${RED}创建用户失败 (可能已存在)。${RESET}"
                fi
                ;;
            2)
                read -p "请输入要删除的用户名: " username
                if [ -z "$username" ]; then echo -e "${RED}用户名不能为空。${RESET}"; sleep 1; continue; fi
                if [[ "$username" == "root" ]]; then echo -e "${RED}不能删除 root 用户。${RESET}"; sleep 1; continue; fi
                read -p "是否同时删除 $username 的家目录 (/home/$username)? (y/n): " del_home
                if [[ "$del_home" == "y" || "$del_home" == "Y" ]]; then
                    userdel -r "$username"
                else
                    userdel "$username"
                fi
                echo -e "${GREEN}✅ 用户 $username 已删除。${RESET}"
                ;;
            3)
                read -p "请输入要修改密码的用户名: " username
                if [ -z "$username" ]; then echo -e "${RED}用户名不能为空。${RESET}"; sleep 1; continue; fi
                passwd "$username"
                ;;
            4)
                echo -e "${YELLOW}系统用户列表 (UID >= 1000):${RESET}"
                awk -F: '($3 >= 1000) {print $1}' /etc/passwd
                ;;
            0) break ;;
            *) echo -e "${RED}无效选项${RESET}"; sleep 1 ;;
        esac
        pause
    done
}


# 14. 用户/密码生成器
generate_password() {
    echo -e "${CYAN}=== 随机密码生成器 ===${RESET}"
    local len=16
    read -p "请输入密码长度 (默认 16): " input_len
    if [[ "$input_len" =~ ^[0-9]+$ ]] && [ "$input_len" -ge 8 ]; then
        len=$input_len
    fi
    
    # 使用 openssl，如果失败则使用 /dev/urandom
    local pass
    if command -v openssl >/dev/null 2>&1; then
        pass=$(openssl rand -base64 "$len" | head -c "$len")
    else
        pass=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w "$len" | head -n 1)
    fi
    
    echo -e "${GREEN}生成的随机密码:${RESET}"
    echo -e "${YELLOW}$pass${RESET}"
    pause
}

# 15. 系统时区调整 (来自原脚本)
manage_timezone() {
    echo -e "${CYAN}=== 系统时区调整 ===${RESET}"
    echo -e "${YELLOW}当前系统时区:${RESET}"
    timedatectl status | grep "Time zone"
    echo ""
    echo "1) 设置时区为上海 (Asia/Shanghai)"
    echo "2) 设置时区为纽约 (America/New_York)"
    echo "3) 设置时区为UTC"
    echo "4) 手动输入时区"
    echo "0. 返回"
    read -p "请选择: " tz_choice
    
    case "$tz_choice" in
        1)
            timedatectl set-timezone Asia/Shanghai
            echo -e "${GREEN}已设置时区为 Asia/Shanghai${RESET}"
            ;;
        2)
            timedatectl set-timezone America/New_York
            echo -e "${GREEN}已设置时区为 America/New_York${RESET}"
            ;;
        3)
            timedatectl set-timezone UTC
            echo -e "${GREEN}已设置时区为 UTC${RESET}"
            ;;
        4)
            read -p "请输入时区 (如 Asia/Tokyo): " custom_tz
            if timedatectl set-timezone "$custom_tz" 2>/dev/null; then
                echo -e "${GREEN}已设置时区为 $custom_tz${RESET}"
            else
                echo -e "${RED}无效的时区，请检查输入${RESET}"
            fi
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选择${RESET}"
            ;;
    esac
    pause
}

# 16. 设置BBR3加速 (指向原脚本功能)
manage_bbr_kernel() {
    echo -e "${CYAN}正在下载并运行 BBR 切换脚本... (来自 ylx2016/Linux-NetSpeed)${RESET}"
    wget -O tcp.sh "https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌❌ 下载或运行脚本失败，请检查网络连接${RESET}"
    fi
    pause
}

# 17. 更新软件包 (不升内核)
update_software() {
    echo -e "${CYAN}=== 更新软件包 (不升级内核) ===${RESET}"
    echo -e "${GREEN}>>> 正在更新软件包列表并升级已安装软件...${RESET}"
    local pm
    pm=$(get_pm)
    if [[ "$pm" == "apt" ]]; then
        apt update -y
        apt upgrade -y
    elif [[ "$pm" == "yum" ]]; then
        yum update -y --exclude=kernel*
    elif [[ "$pm" == "dnf" ]]; then
        dnf update -y --exclude=kernel*
    else
        echo -e "${RED}❌❌ 无法识别包管理器，请手动更新系统${RESET}"
    fi
    echo -e "${GREEN}系统更新操作完成。${RESET}"
    pause
}

# 18. 修改主机名
manage_hostname() {
    echo -e "${CYAN}=== 修改主机名 ===${RESET}"
    echo -e "${YELLOW}当前主机名: $(hostname)${RESET}"
    read -p "请输入新的主机名: " new_hostname
    if [ -z "$new_hostname" ]; then
        echo -e "${RED}主机名不能为空。${RESET}"
        pause
        return
    fi
    
    hostnamectl set-hostname "$new_hostname"
    
    # 尝试更新 /etc/hosts
    sed -i "s/127.0.1.1.*/127.0.1.1\t$new_hostname/" /etc/hosts
    
    echo -e "${GREEN}✅ 主机名已修改为: $new_hostname${RESET}"
    echo -e "${YELLOW}请重新登录以查看完整的更改。${RESET}"
    pause
}

# 19. 切换系统更新源
change_update_source() {
    echo -e "${CYAN}=== 切换系统更新源 ===${RESET}"
    echo -e "${YELLOW}警告：此功能仅支持 Debian/Ubuntu。${RESET}"
    
    if ! command -v apt >/dev/null 2>&1; then
        echo -e "${RED}非 Debian/Ubuntu 系统，跳过此功能。${RESET}"
        pause
        return
    fi
    
    echo "1. 切换到阿里云镜像 (国内推荐)"
    echo "2. 切换到清华大学镜像 (国内推荐)"
    echo "3. 恢复为官方源"
    echo "0. 返回"
    read -p "请选择: " choice

    local source_list="/etc/apt/sources.list"
    local backup_file="/etc/apt/sources.list.bak"
    
    # 备份
    if [ ! -f "$backup_file" ]; then
        cp "$source_list" "$backup_file"
        echo -e "${GREEN}已备份当前源到 $backup_file${RESET}"
    fi
    
    local os_id
    os_id=$(lsb_release -is 2>/dev/null || echo "Debian")
    local codename
    codename=$(lsb_release -cs 2>/dev/null || echo "bullseye")

    if [[ "$os_id" == "Ubuntu" ]]; then
        case "$choice" in
            1) # 阿里云
                cat > "$source_list" << EOF
deb http://mirrors.aliyun.com/ubuntu/ $codename main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $codename-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $codename-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $codename-backports main restricted universe multiverse
EOF
                echo -e "${GREEN}✅ 已切换到 Ubuntu 阿里云镜像。${RESET}"
                ;;
            2) # 清华
                cat > "$source_list" << EOF
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $codename main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $codename-security main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $codename-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ $codename-backports main restricted universe multiverse
EOF
                echo -e "${GREEN}✅ 已切换到 Ubuntu 清华大学镜像。${RESET}"
                ;;
            3) # 官方
                cp "$backup_file" "$source_list"
                echo -e "${GREEN}✅ 已恢复为官方源。${RESET}"
                ;;
            0) return ;;
            *) echo -e "${RED}无效选择${RESET}"; pause; return ;;
        esac
    elif [[ "$os_id" == "Debian" ]]; then
         case "$choice" in
            1) # 阿里云
                cat > "$source_list" << EOF
deb http://mirrors.aliyun.com/debian/ $codename main contrib non-free
deb http://mirrors.aliyun.com/debian/ $codename-updates main contrib non-free
deb http://mirrors.aliyun.com/debian/ $codename-backports main contrib non-free
deb http://security.debian.org/debian-security $codename-security main contrib non-free
EOF
                echo -e "${GREEN}✅ 已切换到 Debian 阿里云镜像。${RESET}"
                ;;
            2) # 清华
                cat > "$source_list" << EOF
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ $codename main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ $codename-updates main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ $codename-backports main contrib non-free
deb https://security.debian.org/debian-security $codename-security main contrib non-free
EOF
                echo -e "${GREEN}✅ 已切换到 Debian 清华大学镜像。${RESET}"
                ;;
            3) # 官方
                cp "$backup_file" "$source_list"
                echo -e "${GREEN}✅ 已恢复为官方源。${RESET}"
                ;;
            0) return ;;
            *) echo -e "${RED}无效选择${RESET}"; pause; return ;;
        esac
    else
        echo -e "${RED}未知的系统 $os_id，无法自动切换。${RESET}"
        pause
        return
    fi
    
    echo -e "${CYAN}>>> 正在运行 apt update...${RESET}"
    apt update
    pause
}

# 20. 定时任务管理
manage_cron() {
    echo -e "${CYAN}=== 定时任务管理 (Crontab) ===${RESET}"
    echo "1. 查看当前用户的定时任务"
    echo "2. 编辑当前用户的定时任务"
    echo "3. 查看 root 用户的定时任务"
    echo "4. 编辑 root 用户的定时任务"
    echo "0. 返回"
    read -p "请选择: " choice
    
    case "$choice" in
        1)
            crontab -l
            ;;
        2)
            crontab -e
            ;;
        3)
            crontab -u root -l
            ;;
        4)
            crontab -u root -e
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选择${RESET}"
            ;;
    esac
    pause
}


# ====================================================================
# +++ 21-30: 安全与监控 +++
# ====================================================================

# 21. 本机host解析
edit_hosts() {
    echo -e "${CYAN}=== 编辑本机 host 解析 (/etc/hosts) ===${RESET}"
    local editor
    editor=$(get_editor)
    $editor /etc/hosts
    echo -e "${GREEN}✅ /etc/hosts 编辑完成。${RESET}"
    pause
}

# 22. fail2banSSH防御程序
install_fail2ban() {
    echo -e "${CYAN}=== 安装 fail2ban (SSH防御) ===${RESET}"
    local pm
    pm=$(get_pm)
    
    if [[ "$pm" == "apt" ]]; then
        apt install -y fail2ban
    elif [[ "$pm" == "yum" ]]; then
        yum install -y epel-release
        yum install -y fail2ban
    elif [[ "$pm" == "dnf" ]]; then
        dnf install -y fail2ban
    else
        echo -e "${RED}无法识别包管理器，请手动安装 fail2ban。${RESET}"
        pause
        return
    fi
    
    # 创建本地配置文件
    local jail_local="/etc/fail2ban/jail.local"
    if [ -f "$jail_local" ]; then
        echo -e "${YELLOW}检测到 $jail_local 已存在，跳过创建。${RESET}"
    else
        echo -e "${CYAN}>>> 正在创建 $jail_local 配置文件...${RESET}"
        cat > "$jail_local" << EOF
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF
    fi
    
    systemctl enable fail2ban
    systemctl restart fail2ban
    
    echo -e "${GREEN}✅ fail2ban 安装并配置成功！${RESET}"
    echo "当前状态:"
    systemctl status fail2ban --no-pager | head -n 5
    echo "SSH监狱状态:"
    fail2ban-client status sshd
    pause
}

# 23. 自动关机
schedule_shutdown() {
    echo -e "${CYAN}=== 定时自动关机 ===${RESET}"
    echo "1. 设定X分钟后关机"
    echo "2. 设定在指定时间关机 (例如 23:00)"
    echo "3. 取消已设定的关机"
    echo "0. 返回"
    read -p "请选择: " choice
    
    case "$choice" in
        1)
            read -p "请输入多少分钟后关机: " minutes
            if [[ "$minutes" =~ ^[0-9]+$ ]]; then
                shutdown -h +"$minutes"
                echo -e "${GREEN}✅ 系统已设定在 $minutes 分钟后关机。${RESET}"
            else
                echo -e "${RED}输入无效。${RESET}"
            fi
            ;;
        2)
            read -p "请输入关机时间 (HH:MM): " time
            if [[ "$time" =~ ^[0-2][0-9]:[0-5][0-9]$ ]]; then
                shutdown -h "$time"
                echo -e "${GREEN}✅ 系统已设定在 $time 关机。${RESET}"
            else
                echo -e "${RED}时间格式无效 (应为 HH:MM)。${RESET}"
            fi
            ;;
        3)
            shutdown -c
            echo -e "${GREEN}✅ 已取消所有定时关机任务。${RESET}"
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选择${RESET}"
            ;;
    esac
    pause
}

# 25. 防火墙高级管理器 (来自原脚本)
manage_firewall() {
    firewall_menu_advanced # 调用原脚本的函数
}

# 27. Linux内核升级 (来自原脚本)
upgrade_kernel() {
    echo -e "${RED}警告：全面系统升级将升级所有软件包，包括内核，可能需要重启系统！${RESET}"
    read -p "确定要继续全面系统升级吗？(y/N): " confirm_upgrade
    if [[ "$confirm_upgrade" != "y" && "$confirm_upgrade" != "Y" ]]; then
        echo -e "${GREEN}已取消升级操作${RESET}"
        pause
        return
    fi
    
    echo -e "${CYAN}>>> 开始全面系统升级...${RESET}"
    local pm
    pm=$(get_pm)
    
    if [[ "$pm" == "apt" ]]; then
        apt update -y
        apt full-upgrade -y
        apt dist-upgrade -y
    elif [[ "$pm" == "yum" ]]; then
        yum update -y
        yum upgrade -y
    elif [[ "$pm" == "dnf" ]]; then
        dnf update -y
        dnf upgrade -y
    else
        echo -e "${RED}❌❌ 无法识别系统类型，请手动升级${RESET}"
        pause
        return
    fi
    
    echo -e "${GREEN}全面系统升级完成${RESET}"
    echo -e "${YELLOW}建议重启系统以使所有更新生效${RESET}"
    pause
}

# 28. Linux系统内核参数优化
optimize_sysctl() {
    echo -e "${CYAN}=== Linux系统内核参数优化 (sysctl) ===${RESET}"
    local conf_file="/etc/sysctl.conf"
    local bak_file="/etc/sysctl.conf.bak.$(date +%F)"

    read -p "这将修改 $conf_file，是否继续? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${GREEN}操作已取消。${RESET}"
        pause
        return
    fi

    if [ ! -f "$bak_file" ]; then
        cp "$conf_file" "$bak_file"
        echo -e "${GREEN}已备份当前配置到 $bak_file${RESET}"
    fi

    cat >> "$conf_file" << EOF

# --- VPS工具箱优化 ---
# 增加 TCP 最大缓冲区大小
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# 增加最大文件描述符
fs.file-max = 1048576
fs.nr_open = 1048576

# 允许更多的 SYN 队列
net.ipv4.tcp_max_syn_backlog = 8192

# 开启 SYN Cookies (防SYN洪水)
net.ipv4.tcp_syncookies = 1

# 重用 TIME-WAIT sockets
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 0 # 设为0，因为在NAT后可能导致问题

# 减少 TIME-WAIT 连接数
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200

# 禁用 IPv6 (如果不需要)
# net.ipv6.conf.all.disable_ipv6 = 1
# net.ipv6.conf.default.disable_ipv6 = 1
# --- 优化结束 ---
EOF

    echo -e "${CYAN}>>> 正在应用新配置... (sysctl -p)${RESET}"
    sysctl -p
    
    echo -e "${GREEN}✅ 内核参数优化完成。${RESET}"
    pause
}

# 29. 病毒扫描工具
install_virus_scan() {
    echo -e "${CYAN}=== 安装病毒扫描工具 (ClamAV) ===${RESET}"
    local pm
    pm=$(get_pm)
    
    if [[ "$pm" == "apt" ]]; then
        apt install -y clamav clamav-daemon
    elif [[ "$pm" == "yum" ]]; then
        yum install -y epel-release
        yum install -y clamav-server clamav-data clamav-update
    elif [[ "$pm" == "dnf" ]]; then
        dnf install -y clamav
    else
        echo -e "${RED}无法识别包管理器，请手动安装 ClamAV。${RESET}"
        pause
        return
    fi
    
    echo -e "${GREEN}✅ ClamAV 安装成功。${RESET}"
    echo -e "${CYAN}>>> 正在更新病毒库 (freshclam)，可能需要几分钟...${RESET}"
    freshclam
    
    echo -e "${YELLOW}病毒库更新完成。${RESET}"
    read -p "是否现在开始扫描 / (根目录)? (y/n) (可能耗时很久): " scan_now
    if [[ "$scan_now" == "y" || "$scan_now" == "Y" ]]; then
        echo -e "${CYAN}>>> 正在扫描 / (仅报告感染文件，排除 /proc, /sys, /dev)...${RESET}"
        clamscan -r -i --exclude-dir="^/sys" --exclude-dir="^/proc" --exclude-dir="^/dev" /
        echo -e "${GREEN}扫描完成。${RESET}"
    fi
    pause
}

# 30. 文件管理器 (mc)
install_file_manager() {
    echo -e "${CYAN}=== 安装文件管理器 (Midnight Commander) ===${RESET}"
    local pm
    pm=$(get_pm)
    
    if [[ "$pm" == "apt" ]]; then
        apt install -y mc
    elif [[ "$pm" == "yum" ]]; then
        yum install -y mc
    elif [[ "$pm" == "dnf" ]]; then
        dnf install -y mc
    fi
    
    echo -e "${GREEN}✅ mc 安装完成。${RESET}"
    echo -e "${YELLOW}运行 'mc' 启动文件管理器。${RESET}"
    pause
}


# ====================================================================
# +++ 31-40: 个性化与扩展 +++
# ====================================================================

# 31. 切换系统语言
manage_locale() {
    echo -e "${CYAN}=== 切换系统语言 (Locale) ===${RESET}"
    echo -e "${YELLOW}当前语言: $(localectl status | grep 'LANG=' | sed 's/^\s*//')${RESET}"
    echo "1. 设置为 简体中文 (zh_CN.UTF-8)"
    echo "2. 设置为 英文 (en_US.UTF-8)"
    echo "0. 返回"
    read -p "请选择: " choice

    local locale_gen="/etc/locale.gen"
    local pm
    pm=$(get_pm)
    
    case "$choice" in
        1)
            if [ -f "$locale_gen" ]; then # Debian/Ubuntu
                sed -i 's/^#\s*zh_CN.UTF-8/zh_CN.UTF-8/' "$locale_gen"
                locale-gen
            elif [[ "$pm" == "yum" || "$pm" == "dnf" ]]; then
                dnf install -y glibc-langpack-zh
            fi
            localectl set-locale LANG=zh_CN.UTF-8
            echo -e "${GREEN}✅ 语言已设置为 zh_CN.UTF-8${RESET}"
            ;;
        2)
            if [ -f "$locale_gen" ]; then # Debian/Ubuntu
                sed -i 's/^#\s*en_US.UTF-8/en_US.UTF-8/' "$locale_gen"
                locale-gen
            fi
            localectl set-locale LANG=en_US.UTF-8
            echo -e "${GREEN}✅ 语言已设置为 en_US.UTF-8${RESET}"
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选择${RESET}"
            ;;
    esac
    echo -e "${YELLOW}请重新登录以使更改完全生效。${RESET}"
    pause
}

# 32. 命令行美化工具
install_shell_beautify() {
    echo -e "${CYAN}=== 安装命令行美化工具 (Oh My Zsh) ===${RESET}"
    echo -e "${YELLOW}警告：这将安装 Zsh 并将其设置为您的默认 Shell。${RESET}"
    read -p "是否继续? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${GREEN}操作已取消。${RESET}"
        pause
        return
    fi
    
    # 1. 安装 Zsh
    local pm
    pm=$(get_pm)
    if ! command -v zsh >/dev/null 2>&1; then
        echo -e "${CYAN}>>> 正在安装 Zsh...${RESET}"
        if [[ "$pm" == "apt" ]]; then
            apt install -y zsh
        elif [[ "$pm" == "yum" ]]; then
            yum install -y zsh
        elif [[ "$pm" == "dnf" ]]; then
            dnf install -y zsh
        fi
    fi
    
    # 2. 安装 Oh My Zsh
    if [ -d "$HOME/.oh-my-zsh" ]; then
        echo -e "${YELLOW}Oh My Zsh 已经安装。${RESET}"
    else
        echo -e "${CYAN}>>> 正在下载并安装 Oh My Zsh...${RESET}"
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    
    # 3. 设置为默认
    if [ "$SHELL" != "/bin/zsh" ]; then
        chsh -s "$(command -v zsh)"
        echo -e "${GREEN}✅ Zsh 已设置为默认 Shell。${RESET}"
    fi
    
    echo -e "${GREEN}✅ Oh My Zsh 安装完成!${RESET}"
    echo -e "${YELLOW}请重新登录以启动 Zsh。${RESET}"
    pause
}

# 33. 留言板 (MOTD)
edit_motd() {
    echo -e "${CYAN}=== 编辑系统登录欢迎信息 (MOTD) ===${RESET}"
    local motd_file="/etc/motd"
    echo -e "${YELLOW}您正在编辑 $motd_file，此内容将在用户登录时显示。${RESET}"
    pause
    local editor
    editor=$(get_editor)
    $editor "$motd_file"
    echo -e "${GREEN}✅ MOTD 编辑完成。${RESET}"
    pause
}

# ====================================================================
# +++ 41-50: 高级服务 +++
# ====================================================================

# 41. 高级 Docker 管理 (来自原脚本)
manage_docker() {
    docker_menu # 调用原脚本的函数
}

# 42. Nginx Proxy Manager (来自原脚本)
manage_npm() {
    npm_menu # 调用原脚本的函数
}

# ====================================================================
# +++ 51-60: BBR / 调优 +++
# ====================================================================

# 51. BBR 综合测速 (来自原脚本)
bbr_speed_test() {
    bbr_test_menu # 调用原脚本的函数
}

# 52. GLIBC 管理 (来自原脚本)
manage_glibc() {
    glibc_menu # 调用原脚本的函数
}

# 53. 网络延迟IP质量测试 (新功能)
run_nodequality_test() {
    echo -e "${CYAN}=== 正在运行 NodeQuality.com IP质量测试脚本 ===${RESET}"
    echo -e "${YELLOW}这将从 run.NodeQuality.com 下载并执行脚本...${RESET}"
    
    # 确保 curl 已安装 (check_deps 应该已经处理了)
    if ! command -v curl >/dev/null 2>&1; then
        echo -e "${RED}错误：未找到 curl 命令。${RESET}"
        pause
        return
    fi
    
    # 执行脚本
    bash <(curl -sL https://run.NodeQuality.com)
    
    echo -e "${GREEN}✅ IP质量测试脚本执行完毕。${RESET}"
    pause
}

# ====================================================================
# +++ 90+: 脚本管理 +++
# ====================================================================

# 99. 卸载脚本 (来自原脚本)
uninstall_toolbox() {
    read -p "确定要卸载本脚本并清理相关文件吗 (y/n)? ${RED}此操作不可逆!${RESET}: " confirm_uninstall
    if [[ "$confirm_uninstall" == "y" || "$confirm_uninstall" == "Y" ]]; then
        echo -e "${YELLOW}正在清理 ${SCRIPT_FILE}, ${RESULT_FILE} 等文件...${RESET}"
        rm -f "$SCRIPT_FILE" "$RESULT_FILE" tcp.sh
        
        # 移除 alias
        if [ -n "$BASH_VERSION" ]; then
            sed -i "/alias vps='bash $SCRIPT_PATH'/d" "$HOME/.bashrc"
        elif [ -n "$ZSH_VERSION" ]; then
            sed -i "/alias vps='bash $SCRIPT_PATH'/d" "$HOME/.zshrc"
        else
            sed -i "/alias vps='bash $SCRIPT_PATH'/d" "$HOME/.profile"
        fi
        echo -e "${GREEN}已尝试移除 'vps' 快捷键。${RESET}"

        # 记录卸载成功
        echo "Script uninstalled on $(date)" > "$UNINSTALL_NOTE"
        
        echo -e "${GREEN}✅ 脚本卸载完成。${RESET}"
        echo -e "${CYAN}==================================================${RESET}"
        echo -e "${GREEN}卸载完成！感谢使用 VPS 工具箱${RESET}"
        echo -e "${CYAN}==================================================${RESET}"
        exit 0
    fi
}


# ====================================================================
# +++ 原脚本的核心功能函数 (BBR, Docker, Firewall, NPM) +++
# (这些函数被上面的菜单调用，保持不变)
# ====================================================================

# -------------------------------
# 核心功能：BBR 测速
# -------------------------------
run_test() {
    MODE=$1
    echo -e "${CYAN}>>> 切换到 $MODE 并测速...${RESET}" 
    
    # 切换算法
    case $MODE in
        "BBR") 
            modprobe tcp_bbr >/dev/null 2>&1
            sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1
            sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1
            ;;
        "BBR Plus") 
            modprobe tcp_bbrplus >/dev/null 2>&1
            sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1
            sysctl -w net.ipv4.tcp_congestion_control=bbrplus >/dev/null 2>&1
            ;;
        "BBRv2") 
            modprobe tcp_bbrv2 >/dev/null 2>&1
            sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1
            sysctl -w net.ipv4.tcp_congestion_control=bbrv2 >/dev/null 2>&1
            ;;
        "BBRv3") 
            modprobe tcp_bbrv3 >/dev/null 2>&1
            sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1
            sysctl -w net.ipv4.tcp_congestion_control=bbrv3 >/dev/null 2>&1
            ;;
        *) 
            echo -e "${YELLOW}未知 BBR 模式: $MODE${RESET}"
            ;;
    esac
    
    # 执行测速
    RAW=$(speedtest-cli --simple 2>/dev/null)
    if [ -z "$RAW" ]; then
        echo -e "${YELLOW}⚠️ speedtest-cli 失败，尝试替代方法...${RESET}" 
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

    echo -e "${GREEN}$MODE | Ping: ${PING}ms | Down: ${DOWNLOAD} Mbps | Up: ${UPLOAD} Mbps${RESET}" | tee -a "$RESULT_FILE" 
    echo ""
}

bbr_test_menu() {
    echo -e "${CYAN}=== 开始 BBR 综合测速 ===${RESET}"
    > "$RESULT_FILE"
    
    for MODE in "BBR" "BBR Plus" "BBRv2" "BBRv3"; do
        run_test "$MODE"
    done
    
    echo -e "${CYAN}=== 测试完成，结果汇总 (${RESULT_FILE}) ===${RESET}"
    if [ -f "$RESULT_FILE" ] && [ -s "$RESULT_FILE" ]; then
        cat "$RESULT_FILE"
    else
        echo -e "${YELLOW}无测速结果${RESET}"
    fi
    echo ""
    pause
}

# -------------------------------
# GLIBC 管理 (原脚本)
# -------------------------------
glibc_menu() {
    echo -e "${CYAN}=== GLIBC 管理 ===${RESET}"
    echo "1) 查询当前GLIBC版本"
    echo "2) 升级GLIBC (高风险)"
    echo "0. 返回"
    read -p "请选择操作: " glibc_choice
    
    case "$glibc_choice" in
        1)
            echo -e "${GREEN}当前GLIBC版本:${RESET}"
            ldd --version | head -n1
            ;;
        2)
            upgrade_glibc
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选择${RESET}"
            ;;
    esac
    pause
}

upgrade_glibc() {
    echo -e "${RED}警告：升级GLIBC是高风险操作，可能导致系统不稳定！${RESET}"
    read -p "确定要继续升级GLIBC吗？(y/N): " confirm_upgrade
    if [[ "$confirm_upgrade" != "y" && "$confirm_upgrade" != "Y" ]]; then
        echo -e "${GREEN}已取消升级操作${RESET}"
        return
    fi
    
    echo -e "${CYAN}>>> 开始升级GLIBC...${RESET}"
    local pm
    pm=$(get_pm)
    
    if [[ "$pm" == "apt" ]]; then
        echo -e "${GREEN}检测到Debian/Ubuntu系统${RESET}"
        apt update -y
        apt install -y build-essential gawk bison
        apt upgrade -y libc6
    elif [[ "$pm" == "yum" ]]; then
        echo -e "${GREEN}检测到CentOS/RHEL系统${RESET}"
        yum update -y
        yum install -y gcc make bison
        yum update -y glibc
    elif [[ "$pm" == "dnf" ]]; then
        echo -e "${GREEN}检测到Fedora系统${RESET}"
        dnf update -y
        dnf install -y gcc make bison
        dnf update -y glibc
    else 
        echo -e "${RED}❌❌ 无法识别系统类型，请手动升级GLIBC${RESET}"
        return
    fi 

    echo -e "${GREEN}GLIBC升级完成${RESET}"
    echo -e "${YELLOW}建议重启系统以使新GLIBC版本生效${RESET}"
}


# -------------------------------
# Docker 管理 (原脚本)
# -------------------------------
check_jq() {
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}检测到需要使用 jq 工具来处理JSON配置，正在尝试安装...${RESET}"
        local pm
        pm=$(get_pm)
        if [[ "$pm" == "apt" ]]; then
            apt update && apt install -y jq
        elif [[ "$pm" == "yum" ]]; then
            yum install -y jq
        elif [[ "$pm" == "dnf" ]]; then
            dnf install -y jq
        fi
        if ! command -v jq &> /dev/null; then
            echo -e "${RED}jq 安装失败，相关功能可能无法使用。${RESET}"
            return 1
        fi
        echo -e "${GREEN}jq 安装成功。${RESET}"
    fi
    return 0
}
edit_daemon_json() {
    local key=$1
    local value=$2
    DAEMON_FILE="/etc/docker/daemon.json"
    
    check_jq || return 1
    
    if [ ! -f "$DAEMON_FILE" ]; then
        echo "{}" > "$DAEMON_FILE"
    fi
    
    tmp_json=$(jq ".${key} = ${value}" "$DAEMON_FILE")
    echo "$tmp_json" > "$DAEMON_FILE"
    
    echo -e "${GREEN}配置文件 $DAEMON_FILE 已更新。${RESET}"
    echo -e "${YELLOW}正在重启Docker以应用更改...${RESET}"
    systemctl restart docker
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Docker重启成功。${RESET}"
    else
        echo -e "${RED}Docker重启失败，请手动检查: systemctl status docker${RESET}"
    fi
}
install_update_docker() {
    echo -e "${CYAN}正在使用官方脚本安装/更新 Docker...${RESET}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh --mirror Aliyun
    rm get-docker.sh
    systemctl enable docker
    systemctl start docker
    if command -v docker >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Docker 安装/更新并启动成功！${RESET}"
    else
        echo -e "${RED}❌❌ Docker 安装/更新失败，请检查日志。${RESET}"
    fi
}
uninstall_docker() {
    echo -e "${RED}警告：此操作将彻底卸载Docker并删除所有数据（容器、镜像、卷）！${RESET}"
    read -p "确定要继续吗？(y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${GREEN}操作已取消。${RESET}"
        return
    fi
    
    systemctl stop docker
    local pm
    pm=$(get_pm)
    if [[ "$pm" == "apt" ]]; then
        apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        apt-get autoremove -y
    elif [[ "$pm" == "yum" ]]; then
        yum remove -y docker-ce docker-ce-cli containerd.io
    elif [[ "$pm" == "dnf" ]]; then
        dnf remove -y docker-ce docker-ce-cli containerd.io
    fi
    
    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd
    echo -e "${GREEN}Docker 已彻底卸载。${RESET}"
}
container_management_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== Docker 容器管理 ===${RESET}"
        docker ps -a
        echo "------------------------------------------------"
        echo "1. 启动容器    2. 停止容器    3. 重启容器"
        echo "4. 查看日志    5. 进入容器    6. 删除容器"
        echo "0. 返回上级菜单"
        read -p "请选择操作: " choice
        
        if [[ "$choice" == "0" ]]; then
            break
        fi

        if [[ "$choice" =~ ^[1-6]$ ]]; then
            read -p "请输入容器ID或名称 (留空则取消): " container
            if [ -z "$container" ]; then
                continue 
            fi

            case "$choice" in
                1) docker start "$container" ;;
                2) docker stop "$container" ;;
                3) docker restart "$container" ;;
                4) docker logs "$container" ;;
                5) docker exec -it "$container" /bin/sh -c "[ -x /bin/bash ] && /bin/bash || /bin/sh" ;;
                6) docker rm "$container" ;;
            esac
            read -n1 -p "操作完成。按任意键继续..."
        else
            echo -e "${RED}无效选择，请输入 0-6 之间的数字。${RESET}"
            sleep 2
        fi
    done
}
image_management_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== Docker 镜像管理 ===${RESET}"
        docker images
        echo "------------------------------------------------"
        echo "1. 拉取镜像    2. 删除镜像    3. 查看历史"
        echo "0. 返回上级菜单"
        read -p "请选择操作: " choice
        
        case "$choice" in
            1) 
                read -p "请输入要拉取的镜像名称 (例如: ubuntu:latest): " image_name
                [ -n "$image_name" ] && docker pull "$image_name"
                ;;
            2) 
                read -p "请输入要删除的镜像ID或名称: " image_id
                [ -n "$image_id" ] && docker rmi "$image_id"
                ;;
            3)
                read -p "请输入要查看历史的镜像ID或名称: " image_id
                [ -n "$image_id" ] && docker history "$image_id"
                ;;
            0) break ;;
            *) echo -e "${RED}无效选择${RESET}" ;;
        esac
        read -n1 -p "按任意键继续..."
    done
}
docker_menu() {
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}未检测到 Docker 环境！${RESET}"
        read -p "是否现在安装 Docker? (y/n): " install_docker
        if [[ "$install_docker" == "y" || "$install_docker" == "Y" ]]; then
            install_update_docker
        fi
        return
    fi
    
    while true; do
        clear
        echo -e "${CYAN}Docker管理${RESET}"
        if systemctl is-active --quiet docker; then
            containers=$(docker ps -a --format '{{.ID}}' | wc -l)
            images=$(docker images -q | wc -l)
            networks=$(docker network ls -q | wc -l)
            volumes=$(docker volume ls -q | wc -l)
            echo -e "${GREEN}环境已经安装 容器: ${containers} 镜像: ${images} 网络: ${networks} 卷: ${volumes}${RESET}"
        else
            echo -e "${RED}Docker服务未运行！请先启动Docker。${RESET}"
        fi
        echo "------------------------------------------------"
        echo "1.  安装/更新Docker环境"
        echo "2.  查看Docker全局状态 (docker system df)"
        echo "3.  Docker容器管理"
        echo "4.  Docker镜像管理"
        echo "5.  Docker网络管理"
        echo "6.  Docker卷管理"
        echo "7.  清理无用的Docker资源 (prune)"
        echo "8.  更换Docker镜像源"
        echo "9.  编辑daemon.json文件"
        echo "11. 开启Docker-ipv6访问"
        echo "12. 关闭Docker-ipv6访问"
        echo "20. 卸载Docker环境"
        echo "0.  返回主菜单"
        echo "------------------------------------------------"
        read -p "请输入你的选择: " choice

        case "$choice" in
            1) install_update_docker ;;
            2) docker system df ;;
            3) container_management_menu ;;
            4) image_management_menu ;;
            5) docker network ls && echo "网络管理功能待扩展" ;;
            6) docker volume ls && echo "卷管理功能待扩展" ;;
            7) 
                read -p "这将删除所有未使用的容器、网络、镜像，确定吗? (y/N): " confirm
                [[ "$confirm" == "y" || "$confirm" == "Y" ]] && docker system prune -af --volumes
                ;;
            8)
                echo "请选择镜像源:"
                echo "1. 阿里云 (推荐国内)"
                echo "2. 网易"
                echo "3. 中科大"
                echo "4. Docker官方 (国外)"
                read -p "输入选择: " mirror_choice
                mirror_url=""
                case "$mirror_choice" in
                    1) mirror_url='"https://mirror.aliyuncs.com"' ;;
                    2) mirror_url='"http://hub-mirror.c.163.com"' ;;
                    3) mirror_url='"https://docker.mirrors.ustc.edu.cn"' ;;
                    4) mirror_url='""' ;;
                    *) echo "无效选择"; continue ;;
                esac
                edit_daemon_json '"registry-mirrors"' "[$mirror_url]"
                ;;
            9)
                [ -f /etc/docker/daemon.json ] || echo "{}" > /etc/docker/daemon.json
                editor=$(get_editor)
                $editor /etc/docker/daemon.json
                ;;
            11) edit_daemon_json '"ipv6"' "true" ;;
            12) edit_daemon_json '"ipv6"' "false" ;;
            20) uninstall_docker ;;
            0) break ;;
            *) echo -e "${RED}无效选项${RESET}" ;;
        esac
        read -n1 -p "按任意键返回Docker菜单..."
    done
}


# -------------------------------
# 防火墙管理 (原脚本)
# -------------------------------
get_ssh_port() {
    SSH_PORT=$(ss -tnlp | grep 'sshd' | awk '{print $4}' | awk -F ':' '{print $NF}' | head -n 1)
    echo "${SSH_PORT:-22}"
}
allow_current_ssh() {
    local ssh_port
    ssh_port=$(get_ssh_port)
    if ! iptables -C INPUT -p tcp --dport "$ssh_port" -j ACCEPT >/dev/null 2>&1; then
        iptables -I INPUT 1 -p tcp --dport "$ssh_port" -j ACCEPT
        echo -e "${YELLOW}为防止失联，已自动放行当前SSH端口 ($ssh_port)。${RESET}"
    fi
}
save_iptables_rules() {
    echo -e "${CYAN}=== 保存防火墙规则 ===${RESET}"
    local pm
    pm=$(get_pm)
    if [[ "$pm" == "apt" ]]; then
        if ! command -v iptables-save >/dev/null 2>&1; then
            apt-get update
            apt-get install -y iptables-persistent
        fi
        iptables-save > /etc/iptables/rules.v4
        ip6tables-save > /etc/iptables/rules.v6
    elif [[ "$pm" == "yum" || "$pm" == "dnf" ]]; then
        if ! command -v iptables-save >/dev/null 2>&1; then
           yum install -y iptables-services
           systemctl enable iptables
        fi
        service iptables save
    else
        echo -e "${RED}无法确定规则保存方式，请手动执行 'iptables-save'。${RESET}"
        return
    fi
    echo -e "${GREEN}防火墙规则已保存，重启后将自动加载。${RESET}"
}
setup_geoip() {
    if lsmod | grep -q 'xt_geoip'; then
        return 0
    fi
    echo -e "${CYAN}检测到您首次使用国家IP限制功能，需要安装相关模块...${RESET}"
    local pm
    pm=$(get_pm)
    if [[ "$pm" == "apt" ]]; then
        apt update
        apt install -y xtables-addons-common libtext-csv-xs-perl unzip
    elif [[ "$pm" == "yum" || "$pm" == "dnf" ]]; then
        yum install -y epel-release
        yum install -y xtables-addons perl-Text-CSV_XS unzip
    fi

    mkdir -p /usr/share/xt_geoip
    cd /usr/share/xt_geoip || return
    wget -qO- "https://www.ipdeny.com/ipblocks/data/countries/all-zones.tar.gz" | tar -xzf -
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}GeoIP数据库下载并解压成功。${RESET}"
        /usr/lib/xtables-addons/xt_geoip_build -D /usr/share/xt_geoip/ -S /usr/share/xt_geoip/
        echo -e "${GREEN}GeoIP数据库编译完成。${RESET}"
        modprobe xt_geoip
    else
        echo -e "${RED}GeoIP数据库下载失败，请检查网络。${RESET}"
        return 1
    fi
}
firewall_menu_advanced() {
    while true; do
        clear
        echo -e "${CYAN}=== 高级防火墙管理 (iptables) ===${RESET}"
        iptables -L INPUT -n --line-numbers | head -n 20
        echo "------------------------------------------------"
        echo -e "${YELLOW}1. 开放指定端口${RESET}                ${YELLOW}2. 关闭指定端口${RESET}"
        echo -e "${YELLOW}3. 开放所有端口(策略ACCEPT)${RESET}    ${YELLOW}4. 关闭所有端口(策略DROP)${RESET}"
        echo -e "${YELLOW}5. IP白名单 (允许访问)${RESET}           ${YELLOW}6. IP黑名单 (禁止访问)${RESET}"
        echo "------------------------------------------------"
        echo -e "${CYAN}11. 允许 PING${RESET}                    ${CYAN}12. 禁止 PING${RESET}"
        echo -e "${CYAN}13. 启用基础DDoS防御${RESET}           ${CYAN}14. 关闭基础DDoS防御${RESET}"
        echo "------------------------------------------------"
        echo -e "${MAGENTA}15. 阻止指定国家IP${RESET}             ${MAGENTA}16. 仅允许指定国家IP${RESET}"
        echo -e "${MAGENTA}17. 解除所有国家IP限制${RESET}"
        echo "------------------------------------------------"
        echo -e "${GREEN}98. 保存当前规则使其永久生效${RESET}"
        echo -e "${GREEN}99. 清空所有防火墙规则${RESET}"
        echo -e "${GREEN}0. 返回上一级菜单${RESET}"
        echo ""
        read -p "请输入你的选择: " fw_choice

        allow_current_ssh 

        case "$fw_choice" in
            1)
                read -p "请输入要开放的端口: " port
                iptables -I INPUT -p tcp --dport "$port" -j ACCEPT
                iptables -I INPUT -p udp --dport "$port" -j ACCEPT
                echo -e "${GREEN}端口 $port (TCP/UDP) 已开放。${RESET}"
                ;;
            2)
                read -p "请输入要关闭的端口: " port
                iptables -I INPUT -p tcp --dport "$port" -j DROP
                iptables -I INPUT -p udp --dport "$port" -j DROP
                echo -e "${GREEN}端口 $port (TCP/UDP) 的访问已被禁止。${RESET}"
                ;;
            3)
                echo -e "${RED}警告：此操作将允许所有外部访问！${RESET}"
                read -p "确定要将默认策略设为 ACCEPT 吗？(y/N): " confirm
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    iptables -P INPUT ACCEPT
                    echo -e "${GREEN}防火墙默认策略已设为 ACCEPT。${RESET}"
                fi
                ;;
            4)
                echo -e "${RED}警告：此操作将默认拒绝所有访问，仅放行您已设置的允许规则！${RESET}"
                read -p "确定要将默认策略设为 DROP 吗？(y/N): " confirm
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    iptables -P INPUT DROP
                    echo -e "${GREEN}防火墙默认策略已设为 DROP。${RESET}"
                fi
                ;;
            5)
                read -p "请输入要加入白名单的IP地址: " ip
                iptables -I INPUT -s "$ip" -j ACCEPT
                echo -e "${GREEN}IP $ip 已加入白名单。${RESET}"
                ;;
            6)
                read -p "请输入要加入黑名单的IP地址: " ip
                iptables -I INPUT -s "$ip" -j DROP
                echo -e "${GREEN}IP $ip 已加入黑名单。${RESET}"
                ;;
            11)
                iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
                echo -e "${GREEN}已允许 PING 请求。${RESET}"
                ;;
            12)
                iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
                echo -e "${GREEN}已禁止 PING 请求。${RESET}"
                ;;
            13)
                iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
                iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
                iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
                iptables -A INPUT -p tcp -m tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j DROP
                iptables -A INPUT -p tcp -m tcp --tcp-flags FIN,SYN FIN,SYN -j DROP
                iptables -A INPUT -p tcp -m tcp --tcp-flags SYN,RST SYN,RST -j DROP
                iptables -A INPUT -p tcp -m tcp --tcp-flags FIN,RST FIN,RST -j DROP
                iptables -A INPUT -p tcp -m tcp --tcp-flags FIN,ACK FIN -j DROP
                iptables -A INPUT -p tcp -m tcp --tcp-flags ACK,URG URG -j DROP
                iptables -A INPUT -p tcp -m conntrack --ctstate NEW -m limit --limit 60/s --limit-burst 20 -j ACCEPT
                iptables -A INPUT -p tcp -m conntrack --ctstate NEW -j DROP
                echo -e "${GREEN}基础DDoS防御规则已启用。${RESET}"
                ;;
            14)
                iptables -D INPUT -p tcp --tcp-flags ALL NONE -j DROP 2>/dev/null
                iptables -D INPUT -p tcp ! --syn -m state --state NEW -j DROP 2>/dev/null
                iptables -D INPUT -p tcp --tcp-flags ALL ALL -j DROP 2>/dev/null
                iptables -D INPUT -p tcp -m tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j DROP 2>/dev/null
                iptables -D INPUT -p tcp -m tcp --tcp-flags FIN,SYN FIN,SYN -j DROP 2>/dev/null
                iptables -D INPUT -p tcp -m tcp --tcp-flags SYN,RST SYN,RST -j DROP 2>/dev/null
                iptables -D INPUT -p tcp -m tcp --tcp-flags FIN,RST FIN,RST -j DROP 2>/dev/null
                iptables -D INPUT -p tcp -m tcp --tcp-flags FIN,ACK FIN -j DROP 2>/dev/null
                iptables -D INPUT -p tcp -m tcp --tcp-flags ACK,URG URG -j DROP 2>/dev/null
                iptables -D INPUT -p tcp -m conntrack --ctstate NEW -m limit --limit 60/s --limit-burst 20 -j ACCEPT 2>/dev/null
                iptables -D INPUT -p tcp -m conntrack --ctstate NEW -j DROP 2>/dev/null
                echo -e "${GREEN}基础DDoS防御规则已关闭。${RESET}"
                ;;
            15)
                setup_geoip
                if [ $? -ne 0 ]; then read -n1 -p "按任意键返回..."; continue; fi
                read -p "请输入要阻止的国家代码 (例如 CN,US,RU)，多个用逗号隔开: " country_codes
                iptables -I INPUT -m geoip --src-cc "$country_codes" -j DROP
                echo -e "${GREEN}已阻止来自 $country_codes 的IP访问。${RESET}"
                ;;
            16)
                setup_geoip
                if [ $? -ne 0 ]; then read -n1 -p "按任意键返回..."; continue; fi
                echo -e "${RED}警告：此操作将拒绝除指定国家外的所有IP访问，风险极高！${RESET}"
                read -p "请输入仅允许的国家代码 (例如 CN,US,RU)，多个用逗号隔开: " country_codes
                read -p "再次确认执行此高风险操作吗？(y/N): " confirm
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    iptables -A INPUT -m geoip ! --src-cc "$country_codes" -j DROP
                    echo -e "${GREEN}已设置为仅允许来自 $country_codes 的IP访问。${RESET}"
                fi
                ;;
            17)
                for rule_num in $(iptables -L INPUT --line-numbers | grep 'geoip' | awk '{print $1}' | sort -rn); do
                    iptables -D INPUT "$rule_num"
                done
                echo -e "${GREEN}所有国家IP限制规则已解除。${RESET}"
                ;;
            98)
                save_iptables_rules
                ;;
            99)
                echo -e "${RED}警告：此操作将清空所有防火墙规则，使服务器完全暴露！${RESET}"
                read -p "确定要清空所有规则吗？(y/N): " confirm
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    iptables -F
                    iptables -X
                    iptables -P INPUT ACCEPT
                    iptables -P FORWARD ACCEPT
                    iptables -P OUTPUT ACCEPT
                    echo -e "${GREEN}所有防火墙规则已清空。${RESET}"
                fi
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效选项，请输入正确的数字。${RESET}"
                ;;
        esac
        read -n1 -p "按任意键返回防火墙菜单..."
    done
}


# -------------------------------
# Nginx Proxy Manager (原脚本)
# -------------------------------
COMPOSE_CMD=""
check_compose_command() {
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        echo -e "${YELLOW}未检测到 Docker Compose。请先从Docker菜单安装Docker环境。${RESET}"
        return 1
    fi
    return 0
}
install_npm() {
    if [ -f "$NPM_COMPOSE_FILE" ]; then
        echo -e "${YELLOW}Nginx Proxy Manager 似乎已经安装在 $NPM_DIR 中。${RESET}"
        return
    fi
    
    check_compose_command || return
    
    echo -e "${CYAN}>>> 准备安装 Nginx Proxy Manager...${RESET}"
    mkdir -p "$NPM_DIR"
    
    cat > "$NPM_COMPOSE_FILE" << EOF
version: '3.8'
services:
  app:
    image: 'jc21/nginx-proxy-manager:latest'
    restart: unless-stopped
    ports:
      - '80:80'
      - '443:443'
      - '81:81'
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
EOF

    echo -e "${GREEN}docker-compose.yml 文件已创建。${RESET}"
    echo -e "${CYAN}>>> 正在使用 Docker Compose 启动 Nginx Proxy Manager...${RESET}"
    
    (cd "$NPM_DIR" && $COMPOSE_CMD up -d)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Nginx Proxy Manager 安装并启动成功！${RESET}"
        echo -e "${YELLOW}请访问: http://<你的服务器IP>:81${RESET}"
        echo -e "${YELLOW}默认管理员用户:${RESET}"
        echo -e " - ${CYAN}Email:${RESET}    admin@example.com"
        echo -e " - ${CYAN}Password:${RESET} changeme"
    else
        echo -e "${RED}❌❌ Nginx Proxy Manager 安装失败，请检查 Docker 环境和日志。${RESET}"
    fi
}
uninstall_npm() {
    if [ ! -f "$NPM_COMPOSE_FILE" ]; then
        echo -e "${YELLOW}未在 $NPM_DIR 中找到 Nginx Proxy Manager 的安装。${RESET}"
        return
    fi
    
    check_compose_command || return

    echo -e "${RED}警告：此操作将停止并彻底删除 Nginx Proxy Manager 及其所有数据！${RESET}"
    read -p "确定要继续吗？(y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${GREEN}操作已取消。${RESET}"
        return
    fi
    
    echo -e "${CYAN}>>> 正在停止并删除 Nginx Proxy Manager 容器和卷...${RESET}"
    (cd "$NPM_DIR" && $COMPOSE_CMD down --volumes)
    
    echo -e "${CYAN}>>> 正在删除安装目录...${RESET}"
    rm -rf "$NPM_DIR"
    
    echo -e "${GREEN}✅ Nginx Proxy Manager 已成功卸载。${RESET}"
}
manage_npm_service() {
    if [ ! -f "$NPM_COMPOSE_FILE" ]; then
        echo -e "${YELLOW}请先安装 Nginx Proxy Manager。${RESET}"
        return
    fi
    check_compose_command || return
    
    ACTION=$1
    echo -e "${CYAN}>>> 正在执行操作: $ACTION...${RESET}"
    
    case "$ACTION" in
        "start" | "stop" | "restart")
            (cd "$NPM_DIR" && $COMPOSE_CMD $ACTION)
            ;;
        "logs")
            (cd "$NPM_DIR" && $COMPOSE_CMD logs -f --tail=100)
            ;;
        *)
            echo -e "${RED}未知的服务操作: $ACTION${RESET}"
            ;;
    esac
}
update_npm() {
    if [ ! -f "$NPM_COMPOSE_FILE" ]; then
        echo -e "${YELLOW}请先安装 Nginx Proxy Manager。${RESET}"
        return
    fi
    check_compose_command || return
    
    echo -e "${CYAN}>>> G 正在拉取最新的 Nginx Proxy Manager 镜像...${RESET}"
    (cd "$NPM_DIR" && $COMPOSE_CMD pull)
    
    echo -e "${CYAN}>>> 正在使用新镜像重启服务...${RESET}"
    (cd "$NPM_DIR" && $COMPOSE_CMD up -d)
    
    echo -e "${GREEN}✅ Nginx Proxy Manager 更新完成。${RESET}"
}
npm_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== Nginx Proxy Manager 管理 ===${RESET}"
        
        if [ -f "$NPM_COMPOSE_FILE" ]; then
            if docker ps --format '{{.Image}}' | grep -q "jc21/nginx-proxy-manager"; then
                 echo -e "${GREEN}状态: 已安装并正在运行${RESET}"
            else
                 echo -e "${YELLOW}状态: 已安装但未运行${RESET}"
            fi
            echo -e "管理面板: ${CYAN}http://$(curl -s4 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}'):81${RESET}"
        else
            echo -e "${RED}状态: 未安装${RESET}"
        fi
        
        echo "------------------------------------------------"
        echo "1. 安装 Nginx Proxy Manager"
        echo "2. 卸载 Nginx Proxy Manager"
        echo ""
        echo "3. 启动服务"
        echo "4. 停止服务"
        echo "5. 重启服务"
        echo "6. 查看日志"
        echo "7. 更新版本"
        echo "------------------------------------------------"
        echo "0. 返回主菜单"
        echo ""
        read -p "请输入你的选择: " choice

        case "$choice" in
            1) install_npm ;;
            2) uninstall_npm ;;
            3) manage_npm_service "start" ;;
            4) manage_npm_service "stop" ;;
            5) manage_npm_service "restart" ;;
            6) manage_npm_service "logs" ;;
            7) update_npm ;;
            0) break ;;
            *) echo -e "${RED}无效选项${RESET}" ;;
        esac
        read -n1 -p "按任意键返回NPM菜单..."
    done
}


# ====================================================================
# +++ 主菜单 +++
# ====================================================================
show_menu() {
    while true; do
        print_welcome
        echo -e "${CYAN}▶ 系统工具${RESET}"
        echo " 1. 设置脚本启动快捷键 (alias vps)     2. ${MAGENTA}SSH 与 ROOT 管理${RESET} (端口/密码/登录)"
        echo " 3. 优化DNS地址 (Google/CF)           4. 禁用ROOT并创建新用户"
        echo " 5. 切换优先IPv4/IPv6                 8. 重启服务器"
        echo " 9. 系统清理 (autoremove)             10. 查看系统信息"
        echo "---------------------------------------------------------------------"
        echo -e "${CYAN}▶ 系统管理${RESET}"
        echo " 11. 查看端口占用状态 (ss)            12. 修改虚拟内存 (Swap) 大小"
        echo " 13. 用户管理 (增/删/改密)            14. 用户/密码生成器"
        echo " 15. 系统时区调整                     16. ${YELLOW}安装/切换 BBR 内核${RESET} (BBR3等)"
        echo " 17. 更新软件包 (不升内核)            18. 修改主机名"
        echo " 19. 切换系统更新源 (Debian/Ubuntu)   20. 定时任务管理 (Crontab)"
        echo "---------------------------------------------------------------------"
        echo -e "${CYAN}▶ 安全与监控${RESET}"
        echo " 21. 本机host解析 (vi /etc/hosts)     22. ${RED}fail2banSSH防御程序${RESET}"
        echo " 23. 自动关机 (shutdown)              25. ${RED}高级防火墙管理 (iptables)${RESET}"
        echo " 27. 全面系统升级 (含内核)            28. Linux系统内核参数优化 (sysctl)"
        echo " 29. 病毒扫描工具 (ClamAV)            30. 文件管理器 (Midnight Commander)"
        echo "---------------------------------------------------------------------"
        echo -e "${CYAN}▶ 个性化与扩展${RESET}"
        echo " 31. 切换系统语言 (Locale)            32. 命令行美化工具 (Oh My Zsh)"
        echo " 33. 留言板 (MOTD)                    "
        echo "---------------------------------------------------------------------"
        echo -e "${CYAN}▶ 高级服务${RESET}"
        echo " 41. ${GREEN}高级 Docker 管理${RESET}                 42. ${GREEN}Nginx Proxy Manager 管理${RESET}"
        echo "---------------------------------------------------------------------"
        echo -e "${CYAN}▶ BBR / 网络调优${RESET}"
        echo " 51. ${YELLOW}BBR 综合测速${RESET} (BBR/Plus/v2/v3)  52. GLIBC 管理 (查询/升级)"
        echo " 53. 网络延迟/IP质量测试 (NodeQuality)"
        echo "---------------------------------------------------------------------"
        echo " 99. ${RED}卸载本工具箱${RESET}                     0. 退出脚本"
        echo ""
        read -p "请输入你的选择: " choice
        
        case "$choice" in
            1) set_alias ;;
            2) manage_ssh_menu ;;
            3) optimize_dns ;;
            4) create_new_user ;;
            5) toggle_ip_priority ;;
            8) reboot_server ;;
            9) cleanup_system ;;
            10) view_system_info ;;
            
            11) manage_ports ;;
            12) manage_swap ;;
            13) manage_users_menu ;;
            14) generate_password ;;
            15) manage_timezone ;;
            16) manage_bbr_kernel ;;
            17) update_software ;;
            18) manage_hostname ;;
            19) change_update_source ;;
            20) manage_cron ;;
            
            21) edit_hosts ;;
            22) install_fail2ban ;;
            23) schedule_shutdown ;;
            25) manage_firewall ;;
            27) upgrade_kernel ;;
            28) optimize_sysctl ;;
            29) install_virus_scan ;;
            30) install_file_manager ;;

            31) manage_locale ;;
            32) install_shell_beautify ;;
            33) edit_motd ;;
            
            41) manage_docker ;;
            42) manage_npm ;;
            
            51) bbr_speed_test ;;
            52) manage_glibc ;;
            53) run_nodequality_test ;;
            
            99) uninstall_toolbox ;;
            0) echo -e "${CYAN}感谢使用，再见！${RESET}"; exit 0 ;;
            *) echo -e "${RED}无效选项${RESET}"; sleep 2 ;;
        esac
    done
}

# -------------------------------
# 主程序
# -------------------------------
check_root
check_deps
show_menu
