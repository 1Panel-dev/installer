#!/bin/bash

PANEL_EDITION="intl"
EDITION_FILE=".selected_edition"

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
elif [[ $osCheck =~ 'riscv64' ]]; then
    architecture="riscv64"
else
    echo "Unsupported system architecture. Please use a supported OS/architecture listed in the official documentation."
    exit 1
fi

if [[ ! ${INSTALL_MODE} ]]; then
    INSTALL_MODE="stable"
else
    if [[ ${INSTALL_MODE} != "dev" && ${INSTALL_MODE} != "stable" ]]; then
        echo "Invalid INSTALL_MODE: ${INSTALL_MODE}. Supported values are: dev, stable."
        exit 1
    fi
fi

VERSION=$(curl -s https://resource.1panel.hk/${INSTALL_MODE}/latest)
HASH_FILE_URL="https://resource.1panel.hk/${INSTALL_MODE}/${VERSION}/release/checksums.txt"

if [[ "x${VERSION}" == "x" ]]; then
    echo "Failed to fetch the latest version (mode: ${INSTALL_MODE}). Please try again later."
    exit 1
fi

PACKAGE_FILE_NAME="1panel-${VERSION}-linux-${architecture}.tar.gz"
PACKAGE_DOWNLOAD_URL="https://resource.1panel.hk/${INSTALL_MODE}/${VERSION}/release/${PACKAGE_FILE_NAME}"
EXPECTED_HASH=$(curl -s "$HASH_FILE_URL" | grep "$PACKAGE_FILE_NAME" | awk '{print $1}')

if [[ -f ${PACKAGE_FILE_NAME} ]]; then
    actual_hash=$(sha256sum "$PACKAGE_FILE_NAME" | awk '{print $1}')
    if [[ "$EXPECTED_HASH" == "$actual_hash" ]]; then
        echo "Local package found and checksum verified. Skipping download."
        rm -rf 1panel-${VERSION}-linux-${architecture}
        tar zxf ${PACKAGE_FILE_NAME}
        cd 1panel-${VERSION}-linux-${architecture}
        echo "$PANEL_EDITION" > "$EDITION_FILE"
        /bin/bash install.sh
        exit 0
    else
        echo "Local package checksum mismatch. Redownloading package."
        rm -f ${PACKAGE_FILE_NAME}
    fi
fi

echo "Preparing to download 1Panel ${VERSION} (${architecture}, mode: ${INSTALL_MODE})."
echo "Download URL: ${PACKAGE_DOWNLOAD_URL}"

curl -LOk ${PACKAGE_DOWNLOAD_URL}
if [[ ! -f ${PACKAGE_FILE_NAME} ]]; then
    echo "Package download failed. Please check network connectivity and retry."
    exit 1
fi

tar zxf ${PACKAGE_FILE_NAME}
if [[ $? != 0 ]]; then
    echo "Package extraction failed. The downloaded file may be incomplete or corrupted."
    rm -f ${PACKAGE_FILE_NAME}
    exit 1
fi
cd 1panel-${VERSION}-linux-${architecture}
echo "$PANEL_EDITION" > "$EDITION_FILE"

/bin/bash install.sh
