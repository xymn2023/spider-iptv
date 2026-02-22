#!/bin/bash

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
    echo -e "1. 安装系统环境 (FFmpeg, Python, MySQL客户端)"
    echo -e "2. 克隆项目并安装依赖"
    echo -e "3. 初始化数据库 (导入 iptv_data.sql)"
    echo -e "4. 配置数据库连接参数 (修改源码)"
    echo -e "5. 启动全自动抓取任务 (main.py)"
    echo -e "6. 查看抓取结果 (iptv.txt)"
    echo -e "0. 退出脚本"
    echo -e "${YELLOW}==========================================${NC}"
    echo -n "请选择操作 [0-6]: "
}

# 1. 环境安装
install_env() {
    echo -e "${YELLOW}正在更新源并安装组件...${NC}"
    sudo apt-get update
    # 针对 Debian 12 适配包名
    sudo apt-get install -y ffmpeg python3 python3-pip git default-mysql-client mariadb-client || echo "尝试备选安装..."
    echo -e "${GREEN}环境安装尝试完成。${NC}"
    echo -e "${YELLOW}按回车键返回菜单...${NC}"
    read temp
}

# 2. 克隆项目
clone_project() {
    if [ ! -d "$PROJECT_DIR" ]; then
        echo -e "${YELLOW}正在克隆项目...${NC}"
        git clone "$REPO_URL"
    else
        echo -e "${YELLOW}检测到项目已存在，正在拉取最新代码...${NC}"
        cd "$PROJECT_DIR" && git pull && cd ..
    fi
    echo -e "${YELLOW}正在安装 Python 依赖 (bs4, m3u8, requests, pymysql)...${NC}"
    pip3 install bs4 m3u8 requests pymysql --break-system-packages || pip3 install bs4 m3u8 requests pymysql
    echo -e "${GREEN}项目处理完成。${NC}"
    echo -e "${YELLOW}按回车键返回菜单...${NC}"
    read temp
}

# 3. 初始化数据库
init_database() {
    if ! command -v mysql &> /dev/null; then
        echo -e "${RED}错误：未发现 mysql 命令。请先运行选项 1 安装环境。${NC}"
    elif [ ! -d "$PROJECT_DIR" ]; then
        echo -e "${RED}错误：请先运行选项 2 克隆项目。${NC}"
    else
        echo -e "${YELLOW}--- 数据库初始化 ---${NC}"
        echo -n "MySQL root 用户名 [root]: "
        read db_root_user
        db_root_user=${db_root_user:-"root"}
        echo -n "MySQL root 密码: "
        read -s db_root_pass
        echo ""

        SQL_FILE="$PROJECT_DIR/data/iptv_data.sql"
        if [ ! -f "$SQL_FILE" ]; then
            echo -e "${RED}错误：找不到 SQL 文件 $SQL_FILE${NC}"
        else
            echo -e "${YELLOW}正在连接数据库并执行导入...${NC}"
            # 创建数据库
            mysql -h 127.0.0.1 -u"$db_root_user" -p"$db_root_pass" -e "CREATE DATABASE IF NOT EXISTS iptv CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null
            
            # 导入 SQL 内容
            if mysql -h 127.0.0.1 -u"$db_root_user" -p"$db_root_pass" iptv < "$SQL_FILE"; then
                echo -e "${GREEN}数据库 iptv 初始化成功，数据表及初始频道已导入！${NC}"
            else
                echo -e "${RED}失败！请检查：1. 数据库服务是否开启；2. 用户名密码是否正确。${NC}"
            fi
        fi
    fi
    echo -e "${YELLOW}按回车键返回菜单...${NC}"
    read temp
}

# 4. 修改配置
config_source() {
    if [ ! -d "$PROJECT_DIR" ]; then
        echo -e "${RED}错误：项目文件夹不存在。${NC}"
    else
        echo -n "数据库地址 [127.0.0.1]: "
        read db_host
        db_host=${db_host:-"127.0.0.1"}
        echo -n "数据库用户名 [root]: "
        read db_user
        db_user=${db_user:-"root"}
        echo -n "数据库密码: "
        read db_pass

        echo -e "${YELLOW}正在同步修改所有 Python 源码配置...${NC}"
        find "$PROJECT_DIR" -name "*.py" -exec sed -i "s/host=['\"].*['\"]/host='$db_host'/g" {} +
        find "$PROJECT_DIR" -name "*.py" -exec sed -i "s/user=['\"].*['\"]/user='$db_user'/g" {} +
        find "$PROJECT_DIR" -name "*.py" -exec sed -i "s/password=['\"].*['\"]/password='$db_pass'/g" {} +
        echo -e "${GREEN}配置同步完成。${NC}"
    fi
    echo -e "${YELLOW}按回车键返回菜单...${NC}"
    read temp
}

# 主程序逻辑
while true; do
    show_menu
    read choice
    case "$choice" in
        1) install_env ;;
        2) clone_project ;;
        3) init_database ;;
        4) config_source ;;
        5)
            if [ -d "$PROJECT_DIR" ]; then
                echo -e "${YELLOW}启动抓取任务，请耐心等待程序运行结束...${NC}"
                cd "$PROJECT_DIR" && python3 main.py
                cd ..
            else
                echo -e "${RED}错误：请先执行选项 2。${NC}"
            fi
            echo -e "${YELLOW}按回车键返回菜单...${NC}"
            read temp
            ;;
        6)
            FILE="$PROJECT_DIR/source/iptv.txt"
            if [ -f "$FILE" ]; then
                echo -e "${GREEN}--- 抓取结果内容 ---${NC}"
                cat "$FILE"
            else
                echo -e "${RED}尚未生成结果文件，请先执行选项 5。${NC}"
            fi
            echo -e "${YELLOW}按回车键返回菜单...${NC}"
            read temp
            ;;
        0)
            echo -n "确定退出脚本? [y/n]: "
            read confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                exit 0
            fi
            ;;
        *)
            echo -e "${RED}无效选项。${NC}"
            sleep 1
            ;;
    esac
已完成
