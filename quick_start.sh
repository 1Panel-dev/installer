#!/bin/bash
# Install Latest Stable 1Panel Release

# Language selection setup
LANG_FILE=".selected_language"
LANG_DIR="./lang"
AVAILABLE_LANGS=("en" "fa" "zh")

# Associative array for language names
declare -A LANG_NAMES
LANG_NAMES=( ["en"]="English" ["fa"]="Persian" ["zh"]="Chinese" )

# Check if the language is already selected and saved
if [[ -f $LANG_FILE ]]; then
    # Load the saved language
    selected_lang=$(cat "$LANG_FILE")
    echo "${LANG_ALREADY_SELECTED_MSG} ${LANG_NAMES[$selected_lang]}"
else
    # Prompt the user to select a language
    echo "$LANG_PROMPT_MSG"
    for i in "${!AVAILABLE_LANGS[@]}"; do
        lang_code="${AVAILABLE_LANGS[i]}"
        echo "$((i + 1)). ${LANG_NAMES[$lang_code]}"
    done

    read -p "$LANG_CHOICE_MSG" lang_choice

    if [[ $lang_choice -ge 1 && $lang_choice -le ${#AVAILABLE_LANGS[@]} ]]; then
        selected_lang=${AVAILABLE_LANGS[$((lang_choice - 1))]}
        echo "${LANG_SELECTED_CONFIRM_MSG} ${LANG_NAMES[$selected_lang]}"

        # Save the selected language to the file
        echo $selected_lang > $LANG_FILE
    else
        echo "$LANG_INVALID_MSG"
        selected_lang="en"
        echo $selected_lang > $LANG_FILE
    fi
fi

# Load the selected language file
source "$LANG_DIR/$selected_lang.sh"

# Existing script logic
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

package_file_name="1panel-${VERSION}-linux-${architecture}.tar.gz"
package_download_url="https://resource.fit2cloud.com/1panel/package/${INSTALL_MODE}/${VERSION}/release/${package_file_name}"
expected_hash=$(curl -s "$HASH_FILE_URL" | grep "$package_file_name" | awk '{print $1}')

if [[ -f ${package_file_name} ]]; then
    actual_hash=$(sha256sum "$package_file_name" | awk '{print $1}')
    if [[ "$expected_hash" == "$actual_hash" ]]; then
        echo "$INSTALLATION_PACKAGE_HASH"
        rm -rf 1panel-${VERSION}-linux-${architecture}
        tar zxvf ${package_file_name}
        cd 1panel-${VERSION}-linux-${architecture}
        /bin/bash install.sh
        exit 0
    else
        echo "$INSTALLATION_PACKAGE_ERROR"
        rm -f ${package_file_name}
    fi
fi

echo "$START_DOWNLOADING_PANEL ${VERSION}"
echo "$INSTALLATION_PACKAGE_DOWNLOAD_ADDRESS ${package_download_url}"

curl -LOk -o ${package_file_name} ${package_download_url}
curl -sfL https://resource.fit2cloud.com/installation-log.sh | sh -s 1p install ${VERSION}
if [[ ! -f ${package_file_name} ]]; then
    echo "$INSTALLATION_PACKAGE_DOWNLOAD_FAIL"
    exit 1
fi

tar zxvf ${package_file_name}
if [[ $? != 0 ]]; then
    echo "$INSTALLATION_PACKAGE_DOWNLOAD_FAIL"
    rm -f ${package_file_name}
    exit 1
fi

cd 1panel-${VERSION}-linux-${architecture}

/bin/bash install.sh
