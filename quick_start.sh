#!/bin/bash
#Install Latest Stable 1Panel Release

osCheck=`uname -a`
if [[ $osCheck =~ 'x86_64' ]];then
    architecture="amd64"
elif [[ $osCheck =~ 'arm64' ]] || [[ $osCheck =~ 'aarch64' ]];then
    architecture="arm64"
else
    echo "暂不支持的系统架构，请参阅官方文档，选择受支持的系统。"
    exit 1
fi

VERSION=$(curl -s https://resource.fit2cloud.com/1panel/package/${INSTALL_MODE}/latest)

if [[ "x${VERSION}" == "x" ]];then
    echo "获取最新版本失败，请稍候重试"
    exit 1
fi

echo "开始下载 1Panel ${VERSION} 版本在线安装包"

package_file_name="1panel-${VERSION}-linux-${architecture}.tar.gz"
package_download_url="https://resource.fit2cloud.com/1panel/package/${INSTALL_MODE}/${VERSION}/release/${package_file_name}"

echo "安装包下载地址： ${package_download_url}"

curl -LOk -o ${package_file_name} ${package_download_url}
if [ ! -f ${package_file_name} ];then
	echo "下载安装包失败，请稍候重试。"
	exit 1
fi

tar zxvf ${package_file_name}
if [ $? != 0 ];then
	echo "下载安装包失败，请稍候重试。"
	rm -f ${package_file_name}
	exit 1
fi
cd 1panel-${VERSION}-linux-${architecture}

/bin/bash install.sh

curl -sfL https://resource.fit2cloud.com/installation-log.sh | sh -s 1p install ${VERSION}
