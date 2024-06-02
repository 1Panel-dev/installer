#!/bin/bash
#Install Latest Stable 1Panel Release

# 使用 uname -m 来直接获取系统架构
case $(uname -m ) in
    x86_64) architecture="amd64";;
    aarch64) architecture="arm64";;
    aarm64) architecture="arm64";;
    armv7l) architecture="armv7";;
    ppc64le) architecture="ppc64le";;
    s390x) architecture="s390x";;
    *) echo "暂不支持的系统架构，请参阅官方文档，选择受支持的系统。"; exit 1;;
esac

if [[ ! ${INSTALL_MODE} ]];then
	INSTALL_MODE="stable"
else
    if [[ ${INSTALL_MODE} != "dev" && ${INSTALL_MODE} != "stable" ]];then
        echo "请输入正确的安装模式（dev or stable）"
        exit 1
    fi
fi
download_file() {
    local file_url=$1
    local file_name=$2
    echo "正在下载: $file_url"
    curl -sSL --fail --retry 3 --output $file_name $file_url
    if [ $? -ne 0 ]; then
        echo "下载失败，请稍候重试。"
        exit 1
    fi
}

1panel_installer() {
    tar zxvf ${package_file_name}
    cd 1panel-${VERSION}-linux-${architecture}
    if which opkg &>/dev/null;then
        download_file https://raw.githubusercontent.com/gcsong023/wrt_installer/wrt_1panel/install.sh install.sh
        download_file https://raw.githubusercontent.com/gcsong023/wrt_installer/wrt_1panel/1pctl 1pctl
        sed -i "s/ORIGINAL_VERSION=v1.0.0/ORIGINAL_VERSION=${VERSION}/g" 1pctl
        chmod +x install.sh 1pctl 
        /bin/bash install.sh
    else
        /bin/bash install.sh
    fi
}

VERSION=$(curl -s https://resource.fit2cloud.com/1panel/package/${INSTALL_MODE}/latest)
HASH_FILE_URL="https://resource.fit2cloud.com/1panel/package/${INSTALL_MODE}/${VERSION}/release/checksums.txt"

if [[ "x${VERSION}" == "x" ]];then
    echo "获取最新版本失败，请稍候重试"
    exit 1
fi

package_file_name="1panel-${VERSION}-linux-${architecture}.tar.gz"
package_download_url="https://resource.fit2cloud.com/1panel/package/${INSTALL_MODE}/${VERSION}/release/${package_file_name}"
expected_hash=$(curl -s "$HASH_FILE_URL" | grep "$package_file_name" | awk '{print $1}')

if [ -f ${package_file_name} ];then
    actual_hash=$(sha256sum "$package_file_name" | awk '{print $1}')
    if [[ "$expected_hash" == "$actual_hash" ]];then
        echo "安装包已存在，跳过下载"
        rm -rf 1panel-${VERSION}-linux-${architecture}
        1panel_installer
        exit 0
    else
        echo "已存在安装包，但是哈希值不一致，开始重新下载"
        rm -f ${package_file_name}
        echo "开始下载 1Panel ${VERSION} 版本在线安装包"
        echo "安装包下载地址： ${package_download_url}"
        download_file ${package_download_url} ${package_file_name}
        1panel_installer
        exit 0
    fi
else
    echo "开始下载 1Panel ${VERSION} 版本在线安装包"
    echo "安装包下载地址： ${package_download_url}"
    download_file ${package_download_url} ${package_file_name}
    1panel_installer    
fi
