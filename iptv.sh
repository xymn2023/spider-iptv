cat << 'EOF' > iptv.sh && chmod +x iptv.sh && ./iptv.sh
#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_DIR="spider-iptv"
REPO_URL="https://github.com/xymn2023/spider-iptv.git"

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

install_env() {
    echo -e "${YELLOW}正在更新并安装组件...${NC}"
    apt-get update
    apt-get install -y ffmpeg python3 python3-pip git default-mysql-client mariadb-client || echo "包名安装略有差异，请检查"
    echo -e "${GREEN}安装尝试完成。${NC}"
    echo -e "${YELLOW}按回车键返回菜单...${NC}"
    read temp
}

clone_project() {
    if [ ! -d "$PROJECT_DIR" ]; then
        git clone "$REPO_URL"
    else
        cd "$PROJECT_DIR" && git pull && cd ..
    fi
    pip3 install bs4 m3u8 requests pymysql --break-system-packages || pip3 install bs4 m3u8 requests pymysql
    echo -e "${GREEN}项目处理完成。${NC}"
    echo -e "${YELLOW}按回车键返回菜单...${NC}"
    read temp
}

init_database() {
    if ! command -v mysql &> /dev/null; then
        echo -e "${RED}错误：未发现 mysql 命令。请先运行选项 1。${NC}"
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
            echo -e "${RED}找不到 SQL 文件: $SQL_FILE${NC}"
        else
            mysql -h 127.0.0.1 -u"$db_root_user" -p"$db_root_pass" -e "CREATE DATABASE IF NOT EXISTS iptv CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null
            if mysql -h 127.0.0.1 -u"$db_root_user" -p"$db_root_pass" iptv < "$SQL_FILE"; then
                echo -e "${GREEN}数据库初始化成功！${NC}"
            else
                echo -e "${RED}初始化失败，请检查密码或服务状态。${NC}"
            fi
        fi
    fi
    echo -e "${YELLOW}按回车键返回菜单...${NC}"
    read temp
}

config_source() {
    echo -n "数据库地址 [127.0.0.1]: "
    read db_host
    db_host=${db_host:-"127.0.0.1"}
    echo -n "数据库用户名 [root]: "
    read db_user
    db_user=${db_user:-"root"}
    echo -n "数据库密码: "
    read db_pass
    find "$PROJECT_DIR" -name "*.py" -exec sed -i "s/host=['\"].*['\"]/host='$db_host'/g" {} +
    find "$PROJECT_DIR" -name "*.py" -exec sed -i "s/user=['\"].*['\"]/user='$db_user'/g" {} +
    find "$PROJECT_DIR" -name "*.py" -exec sed -i "s/password=['\"].*['\"]/password='$db_pass'/g" {} +
    echo -e "${GREEN}配置已同步。${NC}"
    echo -e "${YELLOW}按回车键返回菜单...${NC}"
    read temp
}

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
                cd "$PROJECT_DIR" && python3 main.py && cd ..
            else
                echo -e "${RED}请先执行选项 2${NC}"
            fi
            echo -e "${YELLOW}按回车键返回菜单...${NC}"
            read temp
            ;;
        6)
            if [ -f "$PROJECT_DIR/source/iptv.txt" ]; then
                cat "$PROJECT_DIR/source/iptv.txt"
            else
                echo "未找到结果文件"
            fi
            echo -e "${YELLOW}按回车键返回菜单...${NC}"
            read temp
            ;;
        0)
            echo -n "确认退出? [y/n]: "
            read confirm
            [ "$confirm" = "y" ] || [ "$confirm" = "Y" ] && exit 0
            ;;
        *)
            echo "无效选项"
            sleep 1
            ;;
    esac
已完成
EOF
