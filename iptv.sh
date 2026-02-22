#!/bin/bash

# 确保脚本遇到错误即停止，避免语法空跑
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' 

PROJECT_DIR="spider-iptv"
REPO_URL="https://github.com/xymn2023/spider-iptv.git"

# 菜单函数
show_menu() {
    echo -e "${YELLOW}=========================================="
    echo -e "      Spider-IPTV Linux 一键管理脚本      "
    echo -e "==========================================${NC}"
    echo -e "1. 安装系统环境 (FFmpeg, Python, MySQL)"
    echo -e "2. 克隆项目并安装依赖"
    echo -e "3. 初始化数据库 (创建库并导入项目数据)"
    echo -e "4. 配置数据库连接参数 (修改源码)"
    echo -e "5. 启动抓取任务 (main.py)"
    echo -e "6. 查看结果 (iptv.txt)"
    echo -e "0. 退出"
    echo -e "${YELLOW}==========================================${NC}"
    echo -n "请选择操作 [0-6]: "
}

# 1. 环境安装
install_env() {
    echo -e "${YELLOW}正在安装必要组件...${NC}"
    sudo apt update && sudo apt install -y ffmpeg python3 python3-pip git mysql-client
    echo -e "${GREEN}环境准备就绪！${NC}"
}

# 2. 克隆项目
clone_project() {
    if [ ! -d "$PROJECT_DIR" ]; then
        git clone "$REPO_URL"
    else
        cd "$PROJECT_DIR" && git pull && cd ..
    fi
    # 强制安装依赖
    pip3 install bs4 m3u8 requests pymysql --break-system-packages || pip3 install bs4 m3u8 requests pymysql
    echo -e "${GREEN}项目克隆与依赖安装完成！${NC}"
}

# 3. 初始化数据库
init_database() {
    echo -e "${YELLOW}--- 自动初始化 MySQL ---${NC}"
    read -p "MySQL root 用户名 [root]: " db_root_user
    db_root_user=${db_root_user:-"root"}
    read -s -p "MySQL root 密码: " db_root_pass
    echo ""

    SQL_FILE="$PROJECT_DIR/data/iptv_data.sql"
    
    # 创建库并导入
    mysql -h 127.0.0.1 -u"$db_root_user" -p"$db_root_pass" -e "CREATE DATABASE IF NOT EXISTS iptv CHARACTER SET utf8mb4;"
    mysql -h 127.0.0.1 -u"$db_root_user" -p"$db_root_pass" iptv < "$SQL_FILE"
    echo -e "${GREEN}数据库已成功初始化！${NC}"
}

# 4. 修改源码参数
config_source() {
    read -p "数据库地址 [127.0.0.1]: " db_host
    db_host=${db_host:-"127.0.0.1"}
    read -p "用户名 [root]: " db_user
    db_user=${db_user:-"root"}
    read -p "密码: " db_pass

    # 批量替换
    find "$PROJECT_DIR" -name "*.py" -exec sed -i "s/host=['\"].*['\"]/host='$db_host'/g" {} +
    find "$PROJECT_DIR" -name "*.py" -exec sed -i "s/user=['\"].*['\"]/user='$db_user'/g" {} +
    find "$PROJECT_DIR" -name "*.py" -exec sed -i "s/password=['\"].*['\"]/password='$db_pass'/g" {} +
    echo -e "${GREEN}源码配置已更新。${NC}"
}

# 主程序逻辑
while true; do
    show_menu
    read -r choice
    case "$choice" in
        1) install_env ;;
        2) clone_project ;;
        3) init_database ;;
        4) config_source ;;
        5) cd "$PROJECT_DIR" && python3 main.py && cd .. ;;
        6) [ -f "$PROJECT_DIR/source/iptv.txt" ] && cat "$PROJECT_DIR/source/iptv.txt" || echo "未找到文件" ;;
        0) exit 0 ;;
        *) echo "无效选项" ;;
    esac
done