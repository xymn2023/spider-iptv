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
    echo -e "1. 安装系统环境 (FFmpeg, Python, MySQL)"
    echo -e "2. 克隆项目并安装依赖"
    echo -e "3. 初始化数据库 (创建库并导入项目数据)"
    echo -e "4. 配置数据库连接参数 (修改源码)"
    echo -e "5. 启动抓取任务 (main.py)"
    echo -e "6. 查看结果 (iptv.txt)"
    echo -e "0. 退出脚本"
    echo -e "${YELLOW}==========================================${NC}"
    echo -n "请选择操作 [0-6]: "
}

# 1. 环境安装 (修复 Debian 12 兼容性)
install_env() {
    echo -e "${YELLOW}正在尝试安装必要组件...${NC}"
    sudo apt update
    # 尝试安装多个可能的 MySQL 客户端包名
    sudo apt install -y ffmpeg python3 python3-pip git default-mysql-client || sudo apt install -y ffmpeg python3 python3-pip git mariadb-client
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}环境安装尝试完成！${NC}"
    else
        echo -e "${RED}部分组件安装失败，请检查网络或手动安装 default-mysql-client${NC}"
    fi
    echo -e "${YELLOW}按回车键返回菜单...${NC}"
    read
}

# 2. 克隆项目
clone_project() {
    if [ ! -d "$PROJECT_DIR" ]; then
        echo -e "${YELLOW}正在克隆项目...${NC}"
        git clone "$REPO_URL" || echo -e "${RED}克隆失败${NC}"
    else
        echo -e "${YELLOW}更新项目...${NC}"
        cd "$PROJECT_DIR" && git pull && cd ..
    fi
    
    echo -e "${YELLOW}正在安装 Python 依赖...${NC}"
    pip3 install bs4 m3u8 requests pymysql --break-system-packages || pip3 install bs4 m3u8 requests pymysql || echo -e "${RED}依赖安装出错，请检查 pip3${NC}"
    
    echo -e "${GREEN}操作执行完毕。${NC}"
    echo -e "${YELLOW}按回车键返回菜单...${NC}"
    read
}

# 3. 初始化数据库
init_database() {
    if [ ! -d "$PROJECT_DIR" ]; then
        echo -e "${RED}错误：请先克隆项目！${NC}"
    else
        echo -e "${YELLOW}--- 自动初始化 MySQL ---${NC}"
        read -p "MySQL root 用户名 [root]: " db_root_user
        db_root_user=${db_root_user:-"root"}
        read -s -p "MySQL root 密码: " db_root_pass
        echo ""

        SQL_FILE="$PROJECT_DIR/data/iptv_data.sql"
        
        # 尝试执行
        if mysql -h 127.0.0.1 -u"$db_root_user" -p"$db_root_pass" -e "CREATE DATABASE IF NOT EXISTS iptv CHARACTER SET utf8mb4;" 2>/dev/null; then
            mysql -h 127.0.0.1 -u"$db_root_user" -p"$db_root_pass" iptv < "$SQL_FILE"
            echo -e "${GREEN}数据库已初始化完成！${NC}"
        else
            echo -e "${RED}数据库连接失败！请确保 MySQL Server 已安装运行且密码正确。${NC}"
        fi
    fi
    echo -e "${YELLOW}按回车键返回菜单...${NC}"
    read
}

# 4. 修改源码参数
config_source() {
    if [ ! -d "$PROJECT_DIR" ]; then
        echo -e "${RED}项目不存在！${NC}"
    else
        read -p "数据库地址 [127.0.0.1]: " db_host
        db_host=${db_host:-"127.0.0.1"}
        read -p "用户名 [root]: " db_user
        db_user=${db_user:-"root"}
        read -p "密码: " db_pass

        find "$PROJECT_DIR" -name "*.py" -exec sed -i "s/host=['\"].*['\"]/host='$db_host'/g" {} +
        find "$PROJECT_DIR" -name "*.py" -exec sed -i "s/user=['\"].*['\"]/user='$db_user'/g" {} +
        find "$PROJECT_DIR" -name "*.py" -exec sed -i "s/password=['\"].*['\"]/password='$db_pass'/g" {} +
        echo -e "${GREEN}配置已尝试批量更新。${NC}"
    fi
    echo -e "${YELLOW}按回车键返回菜单...${NC}"
    read
}

# 主程序逻辑循环
while true; do
    show_menu
    # 使用 -r 参数防止 read 解释反斜杠，确保在所有 shell 下工作正常
    if ! read -r choice; then
        echo "读取输入失败，正在退出..."
        exit 1
    fi

    case "$choice" in
        1) install_env ;;
        2) clone_project ;;
        3) init_database ;;
        4) config_source ;;
        5) 
            if [ -d "$PROJECT_DIR" ]; then
                cd "$PROJECT_DIR" && python3 main.py
                cd ..
            else
                echo -e "${RED}项目未安装${NC}"
            fi
            echo -e "${YELLOW}按回车键返回菜单...${NC}"
            read
            ;;
        6) 
            if [ -f "$PROJECT_DIR/source/iptv.txt" ]; then
                cat "$PROJECT_DIR/source/iptv.txt"
            else
                echo -e "${RED}未找到结果文件 iptv.txt${NC}"
            fi
            echo -e "${YELLOW}按回车键返回菜单...${NC}"
            read
            ;;
        0) 
            echo -n "确定要退出吗? [y/n]: "
            read -r confirm
            if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                exit 0
            fi
            ;;
        *) 
            echo -e "${RED}无效选项，请重新选择${NC}"
            sleep 1
            ;;
    esac
已完成
