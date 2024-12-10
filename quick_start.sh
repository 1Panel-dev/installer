#!/bin/bash

osCheck=$(uname -a)
if [[ $osCheck =~ 'x86_64' ]]; then
    architecture="amd64"
elif [[ $osCheck =~ 'arm64' ]] || [[ $osCheck =~ 'aarch64' ]]; then
    architecture="arm64"
elif [[ $osCheck =~ 'armv7l' ]]; then
    architecture="armv7"
elif [[ $osCheck =~ 'ppc64le' ]]; then
    architecture="ppc64le"
elif [[ $osCheck =~ 's390x' ]]; then
    architecture="s390x"
else
    echo "The system architecture is not currently supported. Please refer to the official documentation to select a supported system."
    exit 1
fi

if [[ ! ${INSTALL_MODE} ]]; then
    INSTALL_MODE="stable"
else
    if [[ ${INSTALL_MODE} != "dev" && ${INSTALL_MODE} != "stable" ]]; then
        echo "Please enter the correct installation mode (dev or stable)"
        exit 1
    fi
fi

VERSION=$(curl -s https://resource.1panel.hk/${INSTALL_MODE}/latest)
HASH_FILE_URL="https://resource.1panel.hk/${INSTALL_MODE}/${VERSION}/release/checksums.txt"

if [[ "x${VERSION}" == "x" ]]; then
    echo "Failed to obtain the latest version, please try again later"
    exit 1
fi

PACKAGE_FILE_NAME="1panel-${VERSION}-linux-${architecture}.tar.gz"
PACKAGE_DOWNLOAD_URL="https://resource.1panel.hk/${INSTALL_MODE}/${VERSION}/release/${PACKAGE_FILE_NAME}"
EXPECTED_HASH=$(curl -s "$HASH_FILE_URL" | grep "$PACKAGE_FILE_NAME" | awk '{print $1}')

if [[ -f ${PACKAGE_FILE_NAME} ]]; then
    actual_hash=$(sha256sum "$PACKAGE_FILE_NAME" | awk '{print $1}')
    if [[ "$EXPECTED_HASH" == "$actual_hash" ]]; then
        echo "The installation package already exists. Skip downloading."
        rm -rf 1panel-${VERSION}-linux-${architecture}
        tar zxf ${PACKAGE_FILE_NAME}
        cd 1panel-${VERSION}-linux-${architecture}
        /bin/bash install.sh
        exit 0
    else
        echo "The installation package already exists, but the hash value is inconsistent. Start downloading again"
        rm -f ${PACKAGE_FILE_NAME}
    fi
fi

echo "Start downloading 1Panel ${VERSION}"
echo "Installation package download address: ${PACKAGE_DOWNLOAD_URL}"

curl -LOk ${PACKAGE_DOWNLOAD_URL}
curl -sfL https://resource.fit2cloud.com/installation-log.sh | sh -s 1p install ${VERSION}
if [[ ! -f ${PACKAGE_FILE_NAME} ]]; then
    echo "Failed to download the installation package"
    exit 1
fi

tar zxf ${PACKAGE_FILE_NAME}
if [[ $? != 0 ]]; then
    echo "Failed to download the installation package"
    rm -f ${PACKAGE_FILE_NAME}
    exit 1
fi
cd 1panel-${VERSION}-linux-${architecture}

/bin/bash install.sh
