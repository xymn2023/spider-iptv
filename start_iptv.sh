#!/bin/bash

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- 脚本信息 ---
IPTVSCRIPT_NAME="iptv.sh"
IPTVSCRIPT_PATH="/home/${IPTVSCRIPT_NAME}" # 明确脚本在 /home 目录
REPO_URL="https://raw.githubusercontent.com/xymn2023/spider-iptv/main/iptv.sh"
BACKUP_SUFFIX=".bak"

echo -e "${YELLOW}=====================================================${NC}"
echo -e "${YELLOW}           Spider-IPTV 自修复启动器 v1.0             ${NC}"
echo -e "${YELLOW}=====================================================${NC}"

# 函数：检查 iptv.sh 脚本的完整性
# 特别检查 `esac` 后面的 `done` 关键字，这是常见的不完整问题
check_script_integrity() {
    if ! [ -f "$IPTVSCRIPT_PATH" ]; then
        echo -e "${RED}错误：${IPTVSCRIPT_NAME} 文件不存在。${NC}"
        return 1
    fi

    # 获取最后一行包含 'esac' 的行号
    LAST_ESAC_LINE=$(grep -n "esac" "$IPTVSCRIPT_PATH" | tail -1 | cut -d: -f1)

    if [ -z "$LAST_ESAC_LINE" ]; then
        # 如果连 'esac' 都找不到，说明文件可能严重损坏
        echo -e "${RED}警告：${IPTVSCRIPT_NAME} 中未找到 'esac' 关键字。文件可能严重损坏。${NC}"
        return 1
    fi

    # 检查 'esac' 后面紧跟的一行是否包含 'done'
    # 使用 tail -n +X 获取从 X 行开始的内容，然后 head -n 1 取第一行
    if tail -n +"$((LAST_ESAC_LINE + 1))" "$IPTVSCRIPT_PATH" | head -n 1 | grep -qE "^\s*done\s*$" ; then
        echo -e "${GREEN}${IPTVSCRIPT_NAME} 完整性检查通过。${NC}"
        return 0
    else
        echo -e "${RED}警告：${IPTVSCRIPT_NAME} 完整性检查失败。缺少 'done' 关键字。${NC}"
        return 1
    fi
}

# 函数：下载或更新 iptv.sh 脚本
download_or_update_script() {
    local force_download=$1 # true if we are forcing a redownload

    if [ -f "$IPTVSCRIPT_PATH" ] && [ -z "$force_download" ]; then
        echo -e "${YELLOW}本地已存在 ${IPTVSCRIPT_NAME}，跳过下载。${NC}"
        return 0
    fi

    echo -e "${YELLOW}正在下载或更新 ${IPTVSCRIPT_NAME}...${NC}"
    # 尝试备份旧文件
    if [ -f "$IPTVSCRIPT_PATH" ]; then
        echo -e "${YELLOW}备份现有 ${IPTVSCRIPT_NAME} 到 ${IPTVSCRIPT_PATH}${BACKUP_SUFFIX}${NC}"
        mv "$IPTVSCRIPT_PATH" "${IPTVSCRIPT_PATH}${BACKUP_SUFFIX}" || { echo -e "${RED}备份失败！${NC}"; return 1; }
    fi

    # 使用 curl 下载，-f 参数表示 HTTP 错误时不输出页面内容，直接报错
    curl -f -o "$IPTVSCRIPT_PATH" "$REPO_URL"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}${IPTVSCRIPT_NAME} 下载成功。${NC}"
        # 赋予执行权限
        chmod +x "$IPTVSCRIPT_PATH"
        echo -e "${GREEN}${IPTVSCRIPT_NAME} 已赋予执行权限。${NC}"
        return 0
    else
        echo -e "${RED}下载 ${IPTVSCRIPT_NAME} 失败，请检查网络连接或源文件地址。${NC}"
        return 1
    fi
}

# --- 主逻辑 ---

# 1. 检查 iptv.sh 是否存在，如果不存在则下载
if ! [ -f "$IPTVSCRIPT_PATH" ]; then
    echo -e "${YELLOW}未发现 ${IPTVSCRIPT_NAME}，准备首次下载...${NC}"
    download_or_update_script || { echo -e "${RED}首次下载失败，退出。${NC}"; exit 1; }
fi

# 2. 检查 iptv.sh 的完整性
if check_script_integrity; then
    echo -e "${YELLOW}环境检查完毕，正在启动 ${IPTVSCRIPT_NAME}...${NC}"
else
    # 完整性检查失败，尝试修复
    echo -e "${RED}-----------------------------------------------------${NC}"
    echo -e "${RED}脚本完整性有问题，尝试自动修复...${NC}"
    echo -e "${RED}-----------------------------------------------------${NC}"
    download_or_update_script true || { echo -e "${RED}自动修复失败，请手动检查。${NC}"; exit 1; }

    # 修复后再次检查
    if check_script_integrity; then
        echo -e "${GREEN}自动修复成功！正在启动 ${IPTVSCRIPT_NAME}...${NC}"
    else
        echo -e "${RED}-----------------------------------------------------${NC}"
        echo -e "${RED}自动修复后仍存在问题。请手动检查文件完整性或网络环境。${NC}"
        echo -e "${RED}-----------------------------------------------------${NC}"
        exit 1
    fi
fi

# 3. 启动 iptv.sh 脚本
exec "$IPTVSCRIPT_PATH"