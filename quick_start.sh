#!/bin/bash
#Install Latest Stable 1Panel Release
#新增安装版本选择：官方版本和wrt1panel仓库版本，检测opkg命令是否存在以判断；

WRT_URL="https://github.com/gcsong023/wrt1panel/releases"
BASE_URL="https://resource.fit2cloud.com/1panel/package"

# 使用 uname -m 来直接获取系统架构
function get_architecture() {
    case $(uname -m) in
        x86_64) echo "amd64";;
        aarch64|aarm64) echo "arm64";;
        armv7l) echo "armv7";;
        ppc64le) echo "ppc64le";;
        s390x) echo "s390x";;
        *) echo "暂不支持的系统架构，请参阅官方文档，选择受支持的系统。"; exit 1;;
    esac
}

function check_version() {
    local attempt=0
    local DEFAULT_BRANCH="${1}"
    local INSTALL_MODE="${2}"
    local MINIMUM_WAIT_TIME=5  # 最小尝试间隔时间
    local MAX_ATTEMPTS=5       # 最大尝试次数

    # 尝试获取最新版本
    until [[ "${attempt}" -ge "${MAX_ATTEMPTS}" ]]; do
        ((attempt++))
        if [[ "${attempt}" -gt 1 ]]; then
            # 如果不是第一次尝试，在尝试之间加入等待时间
            sleep "${MINIMUM_WAIT_TIME}"
        fi
        echo "尝试获取最新版本（第${attempt}次）..."
        case $DEFAULT_BRANCH in
            1)
                VERSION=$(curl -s https://api.github.com/repos/gcsong023/wrt1panel/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
                ;;
            2)
                VERSION=$(curl -s "${BASE_URL}/${INSTALL_MODE}/latest")
                ;;
        esac
               # 检查VERSION是否被成功获取
        if [[ "x${VERSION}" == "x" ]];then
            echo "当前尝试获取最新版本失败，${MINIMUM_WAIT_TIME}秒后下一尝试..."
        else
            echo "成功获取最新版本: ${VERSION}"
            break
        fi
    done

    if [[ "x${VERSION}" == "x" ]];then
        echo "无法获取最新版本，请检查网络环境或稍候重试"
        exit 1
    fi
}

function prepare_download_urls() {
    local install_mode="$1"
    local version="$2"
    local architecture="$3"
    # 根据 install_mode 构建正确的 URL
    case $install_mode in
        download)
            hash_file_url="${WRT_URL}/${install_mode}/${version}/checksums.txt"
            package_file_name="1panel-${version}-linux-${architecture}.tar.gz"
            package_download_url="${WRT_URL}/${install_mode}/${version}/${package_file_name}"
            ;;
        stable)
            hash_file_url="${BASE_URL}/${install_mode}/${version}/release/checksums.txt"
            package_file_name="1panel-${version}-linux-${architecture}.tar.gz"
            package_download_url="${BASE_URL}/${install_mode}/${version}/release/${package_file_name}"
            ;;
    esac
}

download_file() {
    local file_url=$1
    local file_name=$2
    echo "正在下载: $file_url"
    curl -sSL --fail --retry 3 --output "$file_name" "$file_url"
    if [ $? -ne 0 ]; then
        echo "下载失败，请检查网络或稍候重试..."
        exit 1
    fi
}

function select_branch() {
    local attempt=0
    local MINIMUM_WAIT_TIME=2  # 最小尝试间隔时间
    local MAX_ATTEMPTS=5       # 最大尝试次数
    DEFAULT_BRANCH="2"
    # local architecture="unknown" 
    # local version="unknown"
    if [ -z "$architecture" ]; then
        architecture=$(get_architecture)
    fi
    # 检查 opkg 命令是否存在
    if command -v opkg &> /dev/null; then
        DEFAULT_BRANCH="1"
    fi
    # 设置8秒超时，用户未输入则使用默认值
    echo "请选择安装分支..."
    echo "1.wrt1panel仓库最新版"
    echo "2.1panel最新版"
    select_timeout=5
    until [[ "${attempt}" -ge "${MAX_ATTEMPTS}" ]]; do
        ((attempt++))
        # 等待用户输入
        read -t "$select_timeout" -p "当前默认选择为${DEFAULT_BRANCH}(确认请回车): " BRANCH
        BRANCH=${BRANCH:-$DEFAULT_BRANCH}
        # 如果用户输入了无效的选项，则重新选择
        if ! [[ "${BRANCH}" =~ ^[12]$ ]]; then
            echo "无效的输入，请重新输入..."
            echo "或按Ctrl+C退出安装..."
            sleep "${MINIMUM_WAIT_TIME}"
        else
            BRANCH=${BRANCH:-$DEFAULT_BRANCH}
            break
        fi
    done
    
    case $BRANCH in
        1)
            install_mode="download"
            check_version "$BRANCH" "$install_mode"
            echo "当前安装版本为wrt1panel仓库最新版：${VERSION}"
            prepare_download_urls "$install_mode" "$VERSION" "$architecture"
            ;;
        2)
            install_mode="stable"
            check_version "$BRANCH" "$install_mode"
            echo "当前安装版本为1panel最新版：${VERSION}"
            prepare_download_urls "$install_mode" "$VERSION" "$architecture"
            ;;
    esac
}

function package_verify() {
    if [ ! -f "$package_file_name" ]; then
        echo "开始下载${VERSION} 安装包..."
        # echo "安装包下载地址： ${package_download_url}"
        download_file "$package_download_url" "$package_file_name"
    else
        # echo "已存在安装包，检查哈希值..."
        actual_hash=$(sha256sum "$package_file_name" | awk '{print $1}')
        expected_hash=$(curl -s "$hash_file_url" | grep "$package_file_name" | awk '{print $1}')
        if [[ "$expected_hash" == "$actual_hash" ]]; then
            echo "安装包已存在且哈希值匹配，跳过下载"
        else
            echo "已存在安装包，但是哈希值不一致，开始重新下载"
            rm -f "$package_file_name"
            download_file "$package_download_url" "$package_file_name"
        fi
    fi
}
function install_panel() {
    tar zxvf "$package_file_name"
    cd "1panel-${VERSION}-linux-${architecture}"
    chmod +x install.sh && chmod +x 1panel && chmod +x 1pctl
    /bin/bash install.sh
    exit 0
}
# 主流程
select_branch
package_verify
install_panel