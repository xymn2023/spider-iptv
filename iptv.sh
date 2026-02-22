#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- 路径跟踪设置 ---
SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
PROJECT_DIR="spider-iptv"
REPO_URL="https://github.com/xymn2023/spider-iptv.git"
PY_FILE="$SCRIPT_DIR/$PROJECT_DIR/iptvdata.py"

show_menu() {
    clear
    echo -e "${YELLOW}=========================================="
    echo -e "      Spider-IPTV Linux 一键管理脚本      "
    echo -e "      脚本位置: $SCRIPT_DIR "
    echo -e "==========================================${NC}"
    echo -e "1. 安装/修复系统环境 (含 FFmpeg, OpenCV)"
    echo -e "2. 更新项目依赖 (解决 No module 报错)"
    echo -e "3. ${RED}数据库深度修复 (自动设置并同步密码)${NC}"
    echo -e "4. 同步配置 & 导入数据 (含 Token 修改)"
    echo -e "5. 启动主程序抓取任务 (main.py)"
    echo -e "6. 删除并清空数据库 (删除重装用)"
    echo -e "0. 退出脚本"
    echo -e "${YELLOW}==========================================${NC}"
    echo -n "请选择操作 [0-6]: "
}

# 1. 系统环境修复
install_env() {
    echo -e "${YELLOW}正在修复系统组件...${NC}"
    apt-get update
    apt-get install -y ffmpeg python3 python3-pip git mariadb-server \
    libgl1-mesa-glx libglib2.0-0 libsm6 libxrender1 libxext6
    systemctl enable mariadb
    echo -e "${GREEN}系统组件处理完成。${NC}"
    read -r -p "按回车继续..." temp < /dev/tty
}

# 2. 补全 Python 依赖
clone_project() {
    [ ! -d "$PROJECT_DIR" ] && git clone "$REPO_URL" || (cd "$PROJECT_DIR" && git pull && cd ..)
    echo -e "${YELLOW}正在补全所有 Python 依赖库...${NC}"
    pip3 install bs4 m3u8 requests pymysql mysql-connector-python \
    opencv-python timeout-decorator --break-system-packages || \
    pip3 install bs4 m3u8 requests pymysql mysql-connector-python \
    opencv-python timeout-decorator
    echo -e "${GREEN}Python 依赖库更新完毕！${NC}"
    read -r -p "按回车继续..." temp < /dev/tty
}

# 3. 数据库深度修复 (强制改密并同步)
setup_db() {
    echo -e "${YELLOW}正在强制重置数据库权限并同步用户密码...${NC}"
    systemctl stop mariadb
    [ -f /etc/mysql/mariadb.conf.d/50-server.cnf ] && \
    sed -i 's/bind-address.*/bind-address = 127.0.0.1/' /etc/mysql/mariadb.conf.d/50-server.cnf

    echo -n "请设置你要使用的数据库密码: "
    read -s db_pass
    echo ""

    mysqld_safe --skip-grant-tables --skip-networking &
    sleep 5

    mysql -u root <<SQL
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '$db_pass';
UPDATE mysql.user SET Password=PASSWORD('$db_pass') WHERE User='root' AND Host='localhost';
UPDATE mysql.user SET plugin='mysql_native_password' WHERE User='root' AND Host='localhost';
FLUSH PRIVILEGES;
SQL

    pkill -f mysqld
    sleep 2
    systemctl start mariadb
    
    STATUS=$(systemctl is-active mariadb)
    if [ "$STATUS" = "active" ]; then
        echo -e "${GREEN}✅ 数据库已启动并完成改密！${NC}"
        # 自动同步密码到用户要求的 iptvdata.py
        if [ -f "$PY_FILE" ]; then
            sed -i "s/host=['\"].*['\"]/host='127.0.0.1'/g" "$PY_FILE"
            sed -i "s/user=['\"].*['\"]/user='root'/g" "$PY_FILE"
            sed -i "s/password=['\"].*['\"]/password='$db_pass'/g" "$PY_FILE"
            echo -e "${GREEN}✅ 用户设置的密码已同步保存至: $PY_FILE${NC}"
        fi
    else
        echo -e "${RED}❌ 启动失败，请检查数据库服务！${NC}"
    fi
    read -r -p "按回车继续..." temp < /dev/tty
}

# 4. 同步配置 (修复：找回 Token 修改功能)
import_data() {
    echo -n "请输入刚才设置的数据库密码: "
    read -s db_pass
    echo ""
    
    systemctl start mariadb

    # 递归同步源码配置
    find "$PROJECT_DIR" -name "*.py" -exec sed -i "s/host=['\"].*['\"]/host='127.0.0.1'/g" {} +
    find "$PROJECT_DIR" -name "*.py" -exec sed -i "s/user=['\"].*['\"]/user='root'/g" {} +
    find "$PROJECT_DIR" -name "*.py" -exec sed -i "s/password=['\"].*['\"]/password='$db_pass'/g" {} +

    # --- 找回被去掉的 Token 修改功能 ---
    echo -n "请输入 API Token (修改 multicast.py 113行，直接回车不修改): "
    read api_token
    if [ ! -z "$api_token" ]; then
        MC_FILE="$PROJECT_DIR/multicast.py"
        if [ -f "$MC_FILE" ]; then
            sed -i "113s/api_token = .*/api_token = \"$api_token\"/" "$MC_FILE"
            echo -e "${GREEN}Token 修改成功。${NC}"
        else
            echo -e "${RED}未找到 multicast.py，无法修改 Token。${NC}"
        fi
    fi

    # 导入数据
    mysql -u root -p"$db_pass" -e "CREATE DATABASE IF NOT EXISTS iptv CHARACTER SET utf8mb4;" 2>/dev/null
    mysql -u root -p"$db_pass" iptv < "$PROJECT_DIR/data/iptv_data.sql"
    echo -e "${GREEN}配置同步与数据导入完成！${NC}"
    read -r -p "按回车继续..." temp < /dev/tty
}

# --- 脚本主循环 ---
while true; do
    show_menu
    read choice
    case "$choice" in
        1) install_env ;;
        2) clone_project ;;
        3) setup_db ;;
        4) import_data ;;
        5) 
            systemctl start mariadb
            echo -e "${YELLOW}启动主程序...${NC}"
            cd "$PROJECT_DIR" && python3 main.py && cd ..
            read -r -p "任务结束，按回车继续..." temp < /dev/tty ;;
        6)
            echo -e "${RED}警告：将彻底删除数据！${NC}"
            read -p "输入 YES 确认删除: " confirm
            [ "$confirm" = "YES" ] && mysql -u root -p -e "DROP DATABASE IF EXISTS iptv;"
            read -r -p "按回车继续..." temp < /dev/tty ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选择${NC}"; sleep 1 ;;
    esac
done