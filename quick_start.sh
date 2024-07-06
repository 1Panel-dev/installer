#!/bin/bash
#Install Latest Stable 1Panel Release

osCheck=`uname -a`
if [[ $osCheck =~ 'x86_64' ]];then
    architecture="amd64"
elif [[ $osCheck =~ 'arm64' ]] || [[ $osCheck =~ 'aarch64' ]];then
    architecture="arm64"
elif [[ $osCheck =~ 'armv7l' ]];then
    architecture="armv7"
elif [[ $osCheck =~ 'ppc64le' ]];then
    architecture="ppc64le"
elif [[ $osCheck =~ 's390x' ]];then
    architecture="s390x"
else
    echo "For system architectures that are not currently supported, please refer to the official documentation to select a supported system."
    exit 1
fi

if [[ ! ${INSTALL_MODE} ]];then
	INSTALL_MODE="stable"
else
    if [[ ${INSTALL_MODE} != "dev" && ${INSTALL_MODE} != "stable" ]];then
        echo "Please enter the correct installation mode（dev or stable）"
        exit 1
    fi
fi

VERSION=$(curl -s https://resource.fit2cloud.com/1panel/package/${INSTALL_MODE}/latest)
HASH_FILE_URL="https://resource.fit2cloud.com/1panel/package/${INSTALL_MODE}/${VERSION}/release/checksums.txt"

if [[ "x${VERSION}" == "x" ]];then
    echo "Failed to get the latest version, please try again later."
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
        tar zxvf ${package_file_name}
        cd 1panel-${VERSION}-linux-${architecture}
        /bin/bash install.sh
        exit 0
    else
        echo "The installation package already exists, but the hash values ​​are inconsistent. Redownloading the package."
        rm -f ${package_file_name}
    fi
fi

echo "Downloading the 1Panel ${VERSION} version installation package"
echo "Installation package download address： ${package_download_url}"

curl -LOk -o ${package_file_name} ${package_download_url}
curl -sfL https://resource.fit2cloud.com/installation-log.sh | sh -s 1p install ${VERSION}
if [ ! -f ${package_file_name} ];then
	echo "Failed to download the installation package, please try again later."
	exit 1
fi

tar zxvf ${package_file_name}
if [ $? != 0 ];then
	echo "Failed to download the installation package, please try again later."
	rm -f ${package_file_name}
	exit 1
fi
cd 1panel-${VERSION}-linux-${architecture}

/bin/bash install.sh
