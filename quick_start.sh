#!/bin/bash

LANG_FILE=".selected_language"
LANG_DIR="./lang"
AVAILABLE_LANGS=("en" "zh" "fa")
declare -A LANG_NAMES
LANG_NAMES=( ["en"]="English" ["zh"]="Chinese  中文(简体)" ["fa"]="Persian" )

LANG_ARCHIVE="lang.tar.gz"
LANG_DOWNLOAD_URL="https://resource.fit2cloud.com/1panel/resource/language/${LANG_ARCHIVE}"
curl -LOk -o ${LANG_ARCHIVE} ${LANG_DOWNLOAD_URL}
tar zxf ${LANG_ARCHIVE}

if [[ -f $LANG_FILE ]]; then
    selected_lang=$(cat "$LANG_FILE")
else
    echo "en" > "$CURRENT_DIR/$LANG_FILE"
    source "$LANG_DIR/en.sh"

    echo "$LANG_PROMPT_MSG"
    for i in "${!AVAILABLE_LANGS[@]}"; do
        lang_code="${AVAILABLE_LANGS[i]}"
        echo "$((i + 1)). ${LANG_NAMES[$lang_code]}"
    done

    read -p "$LANG_CHOICE_MSG" lang_choice

    if [[ $lang_choice -ge 1 && $lang_choice -le ${#AVAILABLE_LANGS[@]} ]]; then
        selected_lang=${AVAILABLE_LANGS[$((lang_choice - 1))]}
        echo "${LANG_SELECTED_CONFIRM_MSG} ${LANG_NAMES[$selected_lang]}"

        echo $selected_lang > $LANG_FILE
    else
        echo "$LANG_INVALID_MSG"
        selected_lang="en"
        echo $selected_lang > $LANG_FILE
    fi
fi

source "$LANG_DIR/$selected_lang.sh"

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
    echo "$SYSTEM_ARCHITECTURE"
    exit 1
fi

if [[ ! ${INSTALL_MODE} ]]; then
    INSTALL_MODE="stable"
else
    if [[ ${INSTALL_MODE} != "dev" && ${INSTALL_MODE} != "stable" ]]; then
        echo "$INSTALLATIO_MODE"
        exit 1
    fi
fi

VERSION=$(curl -s https://resource.fit2cloud.com/1panel/package/${INSTALL_MODE}/latest)
HASH_FILE_URL="https://resource.fit2cloud.com/1panel/package/${INSTALL_MODE}/${VERSION}/release/checksums.txt"

if [[ "x${VERSION}" == "x" ]]; then
    echo "$OBTAIN_VERSION_FAIELD"
    exit 1
fi

PACKAGE_FILE_NAME="1panel-${VERSION}-linux-${architecture}.tar.gz"
PACKAGE_DOWNLOAD_URL="https://resource.fit2cloud.com/1panel/package/${INSTALL_MODE}/${VERSION}/release/${PACKAGE_FILE_NAME}"
EXPECTED_HASH=$(curl -s "$HASH_FILE_URL" | grep "$PACKAGE_FILE_NAME" | awk '{print $1}')

if [[ -f ${PACKAGE_FILE_NAME} ]]; then
    actual_hash=$(sha256sum "$PACKAGE_FILE_NAME" | awk '{print $1}')
    if [[ "$EXPECTED_HASH" == "$actual_hash" ]]; then
        echo "$INSTALLATION_PACKAGE_HASH"
        rm -rf 1panel-${VERSION}-linux-${architecture}
        tar zxf ${PACKAGE_FILE_NAME}
        cp -r $LANG_DIR $LANG_FILE 1panel-${VERSION}-linux-${architecture}
        cd 1panel-${VERSION}-linux-${architecture}
        /bin/bash install.sh
        exit 0
    else
        echo "$INSTALLATION_PACKAGE_ERROR"
        rm -f ${PACKAGE_FILE_NAME}
    fi
fi

echo "$START_DOWNLOADING_PANEL ${VERSION}"
echo "$INSTALLATION_PACKAGE_DOWNLOAD_ADDRESS ${PACKAGE_DOWNLOAD_URL}"

curl -LOk -o ${PACKAGE_FILE_NAME} ${PACKAGE_DOWNLOAD_URL}
curl -sfL https://resource.fit2cloud.com/installation-log.sh | sh -s 1p install ${VERSION}
if [[ ! -f ${PACKAGE_FILE_NAME} ]]; then
    echo "$INSTALLATION_PACKAGE_DOWNLOAD_FAIL"
    exit 1
fi

tar zxf ${PACKAGE_FILE_NAME}
if [[ $? != 0 ]]; then
    echo "$INSTALLATION_PACKAGE_DOWNLOAD_FAIL"
    rm -f ${PACKAGE_FILE_NAME}
    exit 1
fi

cp -r $LANG_DIR $LANG_FILE 1panel-${VERSION}-linux-${architecture}
cd 1panel-${VERSION}-linux-${architecture}

/bin/bash install.sh
