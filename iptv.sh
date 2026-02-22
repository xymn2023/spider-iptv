#!/bin/bash

# --- 路径跟踪设置 ---
# 获取脚本执行时的当前绝对路径
SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
PROJECT_DIR="$SCRIPT_DIR/spider-iptv"
# 动态锁定 iptvdata.py 路径
PY_FILE="$PROJECT_DIR/iptvdata.py"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

REPO_URL="https://github.com/xymn2023/spider-iptv.git"

# 修复回车键功能的函数
pause() {
    echo -e "${YELLOW}------------------------------------------${NC}"
    echo -e "${GREEN}任务处理完成，按回车键继续...${NC}"
    read -r temp < /dev/tty
}

show_menu() {
    clear
    echo -e "${YELLOW}=========================================="
    echo -e "      Spider-IPTV Linux 一键管理脚本      "
    echo -e "      当前路径: $SCRIPT_DIR "
    echo -e "==========================================${NC}"
    echo -e "1. 安装/修复系统环境 (含 FFmpeg, OpenCV)"
    echo -e "2. 更新项目依赖 (解决 No module 报错)"
    echo -e "3. ${RED}数据库深度修复 & 密码自动同步${NC}"
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
    pause
}

# 2. 补全 Python 所有依赖
clone_project() {
    if [ ! -d "$PROJECT_DIR" ]; then
        echo -e "${YELLOW}正在克隆项目到: $PROJECT_DIR${NC}"
        git clone "$REPO_URL" "$PROJECT_DIR"
    else
        echo -e "${YELLOW}项目已存在，正在更新源码...${NC}"
        cd "$PROJECT_DIR" && git pull && cd "$SCRIPT_DIR"
    fi

    echo -e "${YELLOW}正在补全所有 Python 依赖库...${NC}"
    pip3 install bs4 m3u8 requests pymysql mysql-connector-python \
    opencv-python timeout-decorator --break-system-packages || \
    pip3 install bs4 m3u8 requests pymysql mysql-connector-python \
    opencv-python timeout-decorator
    echo -e "${GREEN}Python 依赖库更新完毕！${NC}"
    pause
}

# 3. 数据库深度修复 (带状态跟踪与文件同步)
setup_db() {
    echo -e "${YELLOW}正在进行数据库深度自愈...${NC}"
    
    # 强制修正 MariaDB 配置文件
    [ -f /etc/mysql/mariadb.conf.d/50-server.cnf ] && \
    sed -i 's/bind-address.*/bind-address = 127.0.0.1/' /etc/mysql/mariadb.conf.d/50-server.cnf
    
    systemctl daemon-reload
    systemctl restart mariadb
    sleep 2
    
    # 检测启动状态
    STATUS=$(systemctl is-active mariadb)
    if [ "$STATUS" = "active" ]; then
        echo -e "${GREEN}✅ 数据库服务已正常启动！${NC}"
    else
        echo -e "${RED}❌ 数据库启动失败 (状态: $STATUS)${NC}"
        echo -e "${YELLOW}🔍 最近错误日志:${NC}"
        journalctl -u mariadb -n 5 --no-pager
        pause
        return
    fi

    echo -n "请设置新数据库 root 密码: "
    read -s db_pass
    echo ""
    
    # 强制重置 root 权限
    sudo mysql -u root <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '$db_pass';
UPDATE mysql.user SET plugin='mysql_native_password' WHERE User='root' AND Host='localhost';
FLUSH PRIVILEGES;
SQL
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}数据库权限修复成功！${NC}"
        # --- 路径跟踪同步 ---
        if [ -f "$PY_FILE" ]; then
            sed -i "s/host=['\"].*['\"]/host='127.0.0.1'/g" "$PY_FILE"
            sed -i "s/user=['\"].*['\"]/user='root'/g" "$PY_FILE"
            sed -i "s/password=['\"].*['\"]/password='$db_pass'/g" "$PY_FILE"
            echo -e "${GREEN}✅ 密码已成功同步至: $PY_FILE${NC}"
        else
            echo -e "${RED}⚠️ 未在路径 $PY_FILE 找到 Python 文件，跳过同步。${NC}"
        fi
    else
        echo -e "${RED}密码设置失败。${NC}"
    fi
    pause
}

# 4. 同步配置
import_data() {
    if [ ! -d "$PROJECT_DIR" ]; then
        echo -e "${RED}错误：项目目录 $PROJECT_DIR 不存在，请先执行选项 2${NC}"
        pause
        return
    fi

    echo -n "请输入数据库密码: "
    read -s db_pass
    echo ""
    
    systemctl start mariadb

    # 递归修改项目下所有 Python 配置
    find "$PROJECT_DIR" -name "*.py" -exec sed -i "s/host=['\"].*['\"]/host='127.0.0.1'/g" {} +
    find "$PROJECT_DIR" -name "*.py" -exec sed -i "s/user=['\"].*['\"]/user='root'/g" {} +
    find "$PROJECT_DIR" -name "*.py" -exec sed -i "s/password=['\"].*['\"]/password='$db_pass'/g" {} +

    # Token 修改
    echo -n "请输入 API Token (直接回车不修改): "
    read api_token
    if [ ! -z "$api_token" ]; then
        # 寻找 multicast.py 进行精准行修改
        MC_FILE="$PROJECT_DIR/multicast.py"
        if [ -f "$MC_FILE" ]; then
            sed -i "113s/api_token = .*/api_token = \"$api_token\"/" "$MC_FILE"
            echo -e "${GREEN}Token 修改成功。${NC}"
        fi
    fi

    # 导入数据
    mysql -u root -p"$db_pass" -e "CREATE DATABASE IF NOT EXISTS iptv CHARACTER SET utf8mb4;" 2>/dev/null
    SQL_DATA="$PROJECT_DIR/data/iptv_data.sql"
    if [ -f "$SQL_DATA" ]; then
        mysql -u root -p"$db_pass" iptv < "$SQL_DATA"
        echo -e "${GREEN}数据导入完成！${NC}"
    else
        echo -e "${RED}未找到 SQL 文件: $SQL_DATA${NC}"
    fi
    pause
}

while true; do
    show_menu
    read -r choice
    case "$choice" in
        1) install_env ;;
        2) clone_project ;;
        3) setup_db ;;
        4) import_data ;;
        5) 
            if [ -d "$PROJECT_DIR" ]; then
                systemctl start mariadb
                echo -e "${YELLOW}启动主程序...${NC}"
                cd "$PROJECT_DIR" && python3 main.py
                cd "$SCRIPT_DIR"
            else
                echo -e "${RED}目录不存在！${NC}"
            fi
            pause ;;
        6)
            echo -e "${RED}警告：将彻底删除数据！${NC}"
            read -p "输入 YES 确认删除: " confirm
            [ "$confirm" = "YES" ] && mysql -u root -p -e "DROP DATABASE IF EXISTS iptv;"
            pause ;;
        0) exit 0 ;;
    esac
已完成
