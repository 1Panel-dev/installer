#!/bin/bash
#Install Latest Stable 1Panel Release

git_urls=('gitee.com' 'github.com')

if [[ -x "$(command -v python)" ]];then
    py_cmd='python'
elif [[ -x "$(command -v python3)" ]]; then
    py_cmd='python3'
else
    git_urls=('github.com')
fi

for git_url in ${git_urls[*]}
do
	success="true"
	for i in {1..3}
	do
		echo -ne "检测 ${git_url} ... ${i} "
	    curl -m 5 -kIs https://${git_url} >/dev/null
		if [ $? != 0 ];then
			echo "failed"
			success="false"
			break
		else
			echo "ok"
		fi
	done
	if [[ ${success} == "true" ]];then
		server_url=${git_url}
		break
	fi
done

if [[ "x${server_url}" == "x" ]];then
    echo "没有找到稳定的下载服务器，请稍候重试"
    exit 1
fi

echo "使用下载服务器 ${server_url}"

os=`uname -a`
if [[ $os =~ 'x86_64' ]];then
    architecture="amd64"
elif [[ $os =~ 'arm64' ]] || [[ $os =~ 'aarch64' ]];then
    architecture="arm64"
else
  	echo "暂不支持的系统架构，请参阅官方文档，选择受支持的系统。"
  	exit 1
fi

echo "服务器系统架构 ${architecture}"

bin_file_name="1panel-linux-${architecture}"
if [[ "${server_url}" == "gitee.com" ]];then
    owner='wanghe-fit2cloud'
    repo='1Panel'
    gitee_release_content=$(curl -s https://gitee.com/api/v5/repos/${owner}/${repo}/releases/latest)
    VERSION=$($py_cmd -c "import json; obj=json.loads('$gitee_release_content'); print(obj['tag_name']);")
	bin_download_url="https://1panel.oss-cn-hangzhou.aliyuncs.com/releases/${VERSION}/${bin_file_name}"
else
	owner='wanghe-fit2cloud'
	repo='1Panel'
	VERSION=$(curl -s https://api.github.com/repos/${owner}/${repo}/releases/latest | grep -e "\"tag_name\"" | sed -r 's/.*: "(.*)",/\1/')
    bin_download_url="https://${server_url}/${owner}/${repo}/releases/download/${VERSION}/${bin_file_name}"
fi

if [[ "x${VERSION}" == "x" ]];then
    echo "获取最新版本失败，请稍候重试"
    exit 1
fi

echo "开始下载 1Panel ${VERSION} 版本在线安装包"

package_file_name="1panel-online-installer-${VERSION}.tar.gz"
package_download_url="https://${server_url}/${owner}/${repo}/releases/download/${VERSION}/${package_file_name}"

echo "安装包下载地址： ${package_download_url}"

curl -LOk -m 60 -o ${package_file_name} ${package_download_url}
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

echo "二进制文件下载地址： ${bin_download_url}"

cd 1panel-online-installer-${VERSION}
curl -LOk -o ${bin_file_name} ${bin_download_url}
if [ ! -f ${bin_file_name} ];then
	echo "下载二进制文件失败，请稍候重试。"
	rm -f ${bin_file_name}
	exit 1
fi
mv ${bin_file_name} ./1panel/bin/1panel

/bin/bash install.sh
