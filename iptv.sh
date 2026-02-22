#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' 

PROJECT_DIR="spider-iptv"
REPO_URL="https://github.com/xymn2023/spider-iptv.git"

show_menu() {
    clear
    echo -e "${YELLOW}=========================================="
    echo -e "      Spider-IPTV Linux 一键管理脚本      "
    echo -e "==========================================${NC}"
    echo -e "1. ${GREEN}安装系统环境 (FFmpeg, Python, MySQL-Client)${NC}"
    echo -e "2. ${GREEN}克隆项目并安装 Python 依赖${NC}"
    echo -e "3. ${RED}初始化数据库 (创建 iptv 库并导入 SQL)${NC}"
    echo -e "4. ${YELLOW}配置数据库连接参数 (修改源码)${NC}"
    echo -e "5. ${YELLOW}一键启动抓取任务 (main.py)${NC}"
    echo -e "6. 查看生成的直播源 (iptv.txt)${NC}"
    echo -e "0. 退出"
    echo -e "${YELLOW}==========================================${NC}"
    echo -n "请选择操作 [0-6]: "
}

install_env() {
    echo -e "${YELLOW}正在安装必要组件...${NC}"
    sudo apt update && sudo apt install -y ffmpeg python3 python3-pip git mysql-client
    echo -e "${GREEN}环境准备就绪！${NC}"
    sleep 2
}

clone_project() {
    if [ ! -d "$PROJECT_DIR" ]; then
        git clone $REPO_URL
    else
        cd $PROJECT_DIR && git pull && cd ..
    fi
    pip3 install bs4 m3u8 requests pymysql --break-system-packages || pip3 install bs4 m3u8 requests pymysql
    echo -e "${GREEN}项目克隆与 Python 依赖安装完成！${NC}"
    sleep 2
}

init_database() {
    if [ ! -d "$PROJECT_DIR" ]; then
        echo -e "${RED}错误：请先克隆项目！${NC}"
        sleep 2
        return
    fi

    echo -e "${YELLOW}--- 自动初始化 MySQL 数据库 ---${NC}"
    read -p "请输入 MySQL root 用户名 [root]: " db_root_user
    db_root_user=${db_root_user:-"root"}
    read -s -p "请输入 MySQL root 密码: " db_root_pass
    echo ""

    SQL_FILE="$PROJECT_DIR/data/iptv_data.sql"

    if [ ! -f "$SQL_FILE" ]; then
        echo -e "${RED}错误：未找到 SQL 初始化文件 $SQL_FILE${NC}"
        sleep 2
        return
    fi

    echo -e "${YELLOW}正在创建数据库并导入表结构...${NC}"
    # 创建数据库并导入 SQL
    mysql -h 127.0.0.1 -u"$db_root_user" -p"$db_root_pass" -e "CREATE DATABASE IF NOT EXISTS iptv CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    if [ $? -eq 0 ]; then
        mysql -h 127.0.0.1 -u"$db_root_user" -p"$db_root_pass" iptv < "$SQL_FILE"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}数据库 iptv 初始化成功！${NC}"
        else
            echo -e "${RED}SQL 导入失败，请检查 SQL 文件内容。${NC}"
        fi
    else
        echo -e "${RED}数据库创建失败，请检查用户名密码。${NC}"
    fi
    sleep 3
}

config_source_code() {
    echo -e "${YELLOW}--- 修改脚本中的数据库连接 ---${NC}"
    read -p "数据库地址 [127.0.0.1]: " db_host
    db_host=${db_host:-"127.0.0.1"}
    read -p "数据库用户名 [root]: " db_user
    db_user=${db_user:-"root"}
    read -p "数据库密码: " db_pass

    echo -e "${YELLOW}正在批量更新项目文件...${NC}"
    # 查找所有 .py 文件并替换 host, user, password 字符串
    find $PROJECT_DIR -name "*.py" -exec sed -i "s/host=['\"].*['\"]/host='$db_host'/g" {} +
    find $PROJECT_DIR -name "*.py" -exec sed -i "s/user=['\"].*['\"]/user='$db_user'/g" {} +
    find $PROJECT_DIR -name "*.py" -exec sed -i "s/password=['\"].*['\"]/password='$db_pass'/g" {} +
    
    echo -e "${GREEN}源码配置已更新。${NC}"
    sleep 2
}

run_main() {
    if [ ! -d "$PROJECT_DIR" ]; then echo -e "${RED}项目未安装${NC}"; return; fi
    cd $PROJECT_DIR
    python3 main.py
    cd ..
    read -p "按回车继续..."
}

# 主循环
while true; do
    show_menu
    read choice
    case $choice in
        1) install_env ;;
        2) clone_project ;;
        3) init_database ;;
        4) config_source_code ;;
        5) run_main ;;
        6) [ -f "$PROJECT_DIR/source/iptv.txt" ] && cat "$PROJECT_DIR/source/iptv.txt" || echo "未找到结果文件"; read -p "按回车继续..." ;;
        0) exit 0 ;;
        *) echo -e "${RED}非法输入${NC}"; sleep 1 ;;
    esac
已完成
