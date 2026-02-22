#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # 重置颜色

# 检查是否安装了 git
if ! command -v git &> /dev/null; then
    echo -e "${RED}错误: 未检测到 git，请先安装 git。${NC}"
    exit 1
fi

# 项目路径定义
PROJECT_DIR="spider-iptv"
REPO_URL="https://github.com/maowei1125/spider-iptv.git"

show_menu() {
    clear
    echo -e "${YELLOW}=========================================="
    echo -e "      Spider-IPTV Linux 一键管理脚本      "
    echo -e "==========================================${NC}"
    echo -e "1. ${GREEN}安装环境依赖 (FFmpeg, Python, Pip)${NC}"
    echo -e "2. ${GREEN}克隆项目并安装 Python 库${NC}"
    echo -e "3. ${GREEN}配置数据库信息 (交互修改)${NC}"
    echo -e "4. ${YELLOW}一键启动抓取任务 (main.py)${NC}"
    echo -e "5. ${YELLOW}单独启动抓取酒店源 (hotels.py)${NC}"
    echo -e "6. ${YELLOW}单独启动抓取组播源 (multicast.py)${NC}"
    echo -e "7. 查看生成的直播源 (iptv.txt)${NC}"
    echo -e "0. 退出脚本"
    echo -e "${YELLOW}==========================================${NC}"
    echo -n "请选择操作 [0-7]: "
}

install_env() {
    echo -e "${YELLOW}正在更新系统并安装 FFmpeg...${NC}"
    sudo apt update && sudo apt install -y ffmpeg python3 python3-pip
    echo -e "${GREEN}系统环境安装完成！${NC}"
    sleep 2
}

clone_project() {
    if [ ! -d "$PROJECT_DIR" ]; then
        echo -e "${YELLOW}正在克隆项目...${NC}"
        git clone $REPO_URL
    else
        echo -e "${YELLOW}项目已存在，正在尝试更新...${NC}"
        cd $PROJECT_DIR && git pull && cd ..
    fi
    echo -e "${YELLOW}安装 Python 依赖库...${NC}"
    pip3 install bs4 m3u8 requests pymysql --break-system-packages || pip3 install bs4 m3u8 requests pymysql
    echo -e "${GREEN}项目初始化完成！${NC}"
    sleep 2
}

config_db() {
    if [ ! -d "$PROJECT_DIR" ]; then
        echo -e "${RED}请先执行选项 2 克隆项目！${NC}"
        sleep 2
        return
    fi
    echo -e "${YELLOW}请输入您的 MySQL 数据库信息 (默认: root/root/127.0.0.1):${NC}"
    read -p "数据库地址 [127.0.0.1]: " db_host
    db_host=${db_host:-"127.0.0.1"}
    read -p "数据库用户名 [root]: " db_user
    db_user=${db_user:-"root"}
    read -p "数据库密码: " db_pass

    echo -e "${YELLOW}正在批量更新配置文件中的数据库信息...${NC}"
    # 使用 sed 替换 python 文件中的连接字符串（此处为逻辑示例，具体需根据源码字符串匹配）
    find $PROJECT_DIR -name "*.py" -exec sed -i "s/host=['\"].*['\"]/host='$db_host'/g" {} +
    find $PROJECT_DIR -name "*.py" -exec sed -i "s/user=['\"].*['\"]/user='$db_user'/g" {} +
    find $PROJECT_DIR -name "*.py" -exec sed -i "s/password=['\"].*['\"]/password='$db_pass'/g" {} +
    
    echo -e "${GREEN}数据库配置修改尝试完成，请确保已手动创建 iptv 数据库并导入 SQL。${NC}"
    sleep 2
}

run_main() {
    if [ ! -d "$PROJECT_DIR" ]; then echo -e "${RED}请先克隆项目${NC}"; return; fi
    cd $PROJECT_DIR && python3 main.py
    read -p "按回车键返回菜单..."
}

view_result() {
    RESULT_FILE="$PROJECT_DIR/source/iptv.txt"
    if [ -f "$RESULT_FILE" ]; then
        cat "$RESULT_FILE"
    else
        echo -e "${RED}未找到结果文件，请先运行抓取任务。${NC}"
    fi
    read -p "按回车键返回菜单..."
}

# 主循环
while true; do
    show_menu
    read choice
    case $choice in
        1) install_env ;;
        2) clone_project ;;
        3) config_db ;;
        4) run_main ;;
        5) cd $PROJECT_DIR && python3 hotels.py; read -p "回车继续..." ;;
        6) cd $PROJECT_DIR && python3 multicast.py; read -p "回车继续..." ;;
        7) view_result ;;
        0) exit 0 ;;
        *) echo -e "${RED}无效选择${NC}"; sleep 1 ;;
    esac
done