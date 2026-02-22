#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- 路径跟踪设置 ---
# 自动获取脚本所在绝对路径，确保在 /home 运行也能精准定位项目
SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
PROJECT_DIR="spider-iptv"
REPO_URL="https://github.com/maowei1125/spider-iptv"
# 自动跟踪 iptvdata.py 的绝对路径
PY_FILE="$SCRIPT_DIR/$PROJECT_DIR/iptvdata.py"

show_menu() {
    clear
    echo -e "${YELLOW}=========================================="
    echo -e "      Spider-IPTV Linux 一键管理脚本      "
    echo -e "      脚本位置: $SCRIPT_DIR "
    echo -e "==========================================${NC}"
    echo -e "1. 安装/修复系统环境 (含 FFmpeg, OpenCV)"
    echo -e "2. 更新项目依赖 (解决 No module 报错)"
    echo -e "3. ${RED}数据库深度修复 (解决 111 连接错误)${NC}"
    echo -e "4. 同步配置 & 导入数据"
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
    # 修复回车无效
    read -r -p "按回车继续..." temp < /dev/tty
}

# 2. 补全 Python 所有依赖
clone_project() {
    [ ! -d "$PROJECT_DIR" ] && git clone "$REPO_URL" || (cd "$PROJECT_DIR" && git pull && cd ..)
    echo -e "${YELLOW}正在补全所有 Python 依赖库...${NC}"
    pip3 install bs4 m3u8 requests pymysql mysql-connector-python \
    opencv-python timeout-decorator --break-system-packages || \
    pip3 install bs4 m3u8 requests pymysql mysql-connector-python \
    opencv-python timeout-decorator
    echo -e "${GREEN}Python 依赖库更新完毕！${NC}"
    # 修复回车无效
    read -r -p "按回车继续..." temp < /dev/tty
}

# 3. 数据库深度修复
setup_db() {
    echo -e "${YELLOW}正在进行数据库深度自愈...${NC}"
    [ -f /etc/mysql/mariadb.conf.d/50-server.cnf ] && \
    sed -i 's/bind-address.*/bind-address = 127.0.0.1/' /etc/mysql/mariadb.conf.d/50-server.cnf
    
    systemctl restart mariadb
    sleep 2
    
    # 检测启动状态提示
    STATUS=$(systemctl is-active mariadb)
    if [ "$STATUS" = "active" ]; then
        echo -e "${GREEN}数据库已启动！${NC}"
    else
        echo -e "${RED}数据库未启动、数据库启动失败！${NC}"
        journalctl -u mariadb -n 5 --no-pager
    fi

    echo -n "请设置新数据库 root 密码: "
    read -s db_pass
    echo ""
    
    sudo mysql -u root <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '$db_pass';
UPDATE mysql.user SET plugin='mysql_native_password' WHERE User='root' AND Host='localhost';
FLUSH PRIVILEGES;
SQL
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}数据库修复成功！3306 端口已开放。${NC}"
        # 自动同步密码至 iptvdata.py
        if [ -f "$PY_FILE" ]; then
            sed -i "s/host=['\"].*['\"]/host='127.0.0.1'/g" "$PY_FILE"
            sed -i "s/user=['\"].*['\"]/user='root'/g" "$PY_FILE"
            sed -i "s/password=['\"].*['\"]/password='$db_pass'/g" "$PY_FILE"
            echo -e "${GREEN}已自动同步密码至: $PY_FILE${NC}"
        fi
    else
        echo -e "${RED}修复失败，请尝试先执行选项 6 删除旧库。${NC}"
    fi
    # 修复回车无效
    read -r -p "按回车继续..." temp < /dev/tty
}

# 4. 同步配置
import_data() {
    echo -n "请输入刚才设置的数据库密码: "
    read -s db_pass
    echo ""
    
    systemctl start mariadb

    find "$PROJECT_DIR" -name "*.py" -exec sed -i "s/host=['\"].*['\"]/host='127.0.0.1'/g" {} +
    find "$PROJECT_DIR" -name "*.py" -exec sed -i "s/user=['\"].*['\"]/user='root'/g" {} +
    find "$PROJECT_DIR" -name "*.py" -exec sed -i "s/password=['\"].*['\"]/password='$db_pass'/g" {} +

    echo -n "请输入 API Token (直接回车不修改): "
    read api_token
    if [ ! -z "$api_token" ]; then
        sed -i "113s/api_token = .*/api_token = \"$api_token\"/" "$PROJECT_DIR/multicast.py"
    fi

    mysql -u root -p"$db_pass" -e "CREATE DATABASE IF NOT EXISTS iptv CHARACTER SET utf8mb4;" 2>/dev/null
    mysql -u root -p"$db_pass" iptv < "$PROJECT_DIR/data/iptv_data.sql"
    echo -e "${GREEN}配置同步与数据导入完成！${NC}"
    # 修复回车无效
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
            echo -e "${YELLOW}启动中... 请观察是否还有报错${NC}"
            cd "$PROJECT_DIR" && python3 main.py && cd ..
            read -r -p "任务结束，按回车继续..." temp < /dev/tty ;;
        6)
            echo -e "${RED}警告：将彻底删除数据！${NC}"
            read -p "输入 YES 确认删除: " confirm
            [ "$confirm" = "YES" ] && mysql -u root -p -e "DROP DATABASE IF EXISTS iptv;"
            read -r -p "按回车继续..." temp < /dev/tty
            ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选择${NC}"; sleep 1 ;;
    esac
done
