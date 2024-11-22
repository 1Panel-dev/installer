#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

#!/bin/bash

CURRENT_DIR=$(
    cd "$(dirname "$0")" || exit
    pwd
)

LANG_FILE=".selected_language"
LANG_DIR="$CURRENT_DIR/lang"
AVAILABLE_LANGS=("en" "fa" "zh")

# Define associative array for language display names
declare -A LANG_NAMES
LANG_NAMES=( ["en"]="English" ["fa"]="Persian" ["zh"]="Chinese  汉语" )

# Check if the language is already selected and saved
if [ -f "$CURRENT_DIR/$LANG_FILE" ]; then
    # Load the saved language
    selected_lang=$(cat "$CURRENT_DIR/$LANG_FILE")
    echo "$LANG_SELECTED_MSG ${LANG_NAMES[$selected_lang]}"
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
        echo "$LANG_SELECTED_CONFIRM_MSG ${LANG_NAMES[$selected_lang]}"

        # Save the selected language to the file
        echo "$selected_lang" > "$CURRENT_DIR/$LANG_FILE"
    else
        echo "$LANG_INVALID_MSG"
        selected_lang="en"
        echo "$selected_lang" > "$CURRENT_DIR/$LANG_FILE"
    fi
fi

# Load the selected language file
LANGFILE="$LANG_DIR/$selected_lang.sh"
if [ -f "$LANGFILE" ]; then
    source "$LANGFILE"
else
    echo -e "${RED} $LANG_NOT_FOUND_MSG $LANGFILE${NC}"
    exit 1
fi
clear

function log() {
    message="[1Panel Log]: $1 "
    case "$1" in
        *"$RUN_AS_ROOT"*)
            echo -e "${RED}${message}${NC}" 2>&1 | tee -a "${CURRENT_DIR}"/install.log
            ;;
        *"$SUCCESS"*)
            echo -e "${GREEN}${message}${NC}" 2>&1 | tee -a "${CURRENT_DIR}"/install.log
            ;;
        *"$IGNORE_MESSAGE"*|*"$SKIP_MESSAGE"*)
            echo -e "${YELLOW}${message}${NC}" 2>&1 | tee -a "${CURRENT_DIR}"/install.log
            ;;
        *)
            echo -e "${BLUE}${message}${NC}" 2>&1 | tee -a "${CURRENT_DIR}"/install.log
            ;;
    esac
}
cat << EOF
 ██╗    ██████╗  █████╗ ███╗   ██╗███████╗██╗     
███║    ██╔══██╗██╔══██╗████╗  ██║██╔════╝██║     
╚██║    ██████╔╝███████║██╔██╗ ██║█████╗  ██║     
 ██║    ██╔═══╝ ██╔══██║██║╚██╗██║██╔══╝  ██║     
 ██║    ██║     ██║  ██║██║ ╚████║███████╗███████╗
 ╚═╝    ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝
EOF

log "$START_INSTALLATION"

function Check_Root() {
    if [[ $EUID -ne 0 ]]; then
        log "$RUN_AS_ROOT"
        exit 1
    fi
}

function Prepare_System(){
    if which 1panel >/dev/null 2>&1; then
        log "$PANEL_ALREADY_INSTALLED"
        exit 1
    fi
}

function Set_Dir(){
    if read -t 120 -p "$SET_INSTALL_DIR：" PANEL_BASE_DIR;then
        if [[ "$PANEL_BASE_DIR" != "" ]];then
            if [[ "$PANEL_BASE_DIR" != /* ]];then
                log "$PROVIDE_FULL_PATH"
                Set_Dir
            fi

            if [[ ! -d $PANEL_BASE_DIR ]];then
                mkdir -p "$PANEL_BASE_DIR"
                log "$SELECTED_INSTALL_PATH $PANEL_BASE_DIR"
            fi
        else
            PANEL_BASE_DIR=/opt
            log "$SELECTED_INSTALL_PATH $PANEL_BASE_DIR"
        fi
    else
        PANEL_BASE_DIR=/opt
        log "$TIMEOUT_USE_DEFAULT_PATH"
    fi
}

ACCELERATOR_URL="https://docker.1panelproxy.com"
DAEMON_JSON="/etc/docker/daemon.json"
BACKUP_FILE="/etc/docker/daemon.json.1panel_bak"

function create_daemon_json() {
    log "$CREATE_NEW_CONFIG ${DAEMON_JSON}..."
    mkdir -p /etc/docker
    echo '{
        "registry-mirrors": ["'"$ACCELERATOR_URL"'"]
    }' | tee "$DAEMON_JSON" > /dev/null
    log "$ACCELERATION_CONFIG_ADDED"
}

function configure_accelerator() {
    read -p "$ACCELERATION_CONFIG_ADD " configure_accelerator
    if [[ "$configure_accelerator" == "y" ]]; then
        if [ -f "$DAEMON_JSON" ]; then
            log "$ACCELERATION_CONFIG_EXISTS ${BACKUP_FILE}."
            cp "$DAEMON_JSON" "$BACKUP_FILE"
            create_daemon_json
        else
            create_daemon_json
        fi

        log "$RESTARTING_DOCKER"
        systemctl daemon-reload
        systemctl restart docker
        log "$DOCKER_RESTARTED"
    else
        log "$ACCELERATION_CONFIG_NOT"
    fi
}

function Install_Docker(){
    if which docker >/dev/null 2>&1; then
        docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+' | head -n 1)
        major_version=${docker_version%%.*}
        minor_version=${docker_version##*.}
        if [[ $major_version -lt 20 ]]; then
            # TODO log "$DOCKER_ALREADY_INSTALLED"
            log "检测到 Docker 版本为 $docker_version，低于 20.x，可能影响部分功能的正常使用，建议手动升级至更高版本。"
        fi
        configure_accelerator
    else
        log "$DOCKER_INSTALL_ONLINE"

        if [[ $(curl -s ipinfo.io/country) == "CN" ]]; then
            sources=(
                "https://mirrors.aliyun.com/docker-ce"
                "https://mirrors.tencent.com/docker-ce"
                "https://mirrors.163.com/docker-ce"
                "https://mirrors.cernet.edu.cn/docker-ce"
            )

            docker_install_scripts=(
                "https://get.docker.com"
                "https://testingcf.jsdelivr.net/gh/docker/docker-install@master/install.sh"
                "https://cdn.jsdelivr.net/gh/docker/docker-install@master/install.sh"
                "https://fastly.jsdelivr.net/gh/docker/docker-install@master/install.sh"
                "https://gcore.jsdelivr.net/gh/docker/docker-install@master/install.sh"
                "https://raw.githubusercontent.com/docker/docker-install/master/install.sh"
            )

            get_average_delay() {
                local source=$1
                local total_delay=0
                local iterations=2
                local timeout=2
    
                for ((i = 0; i < iterations; i++)); do
                    delay=$(curl -o /dev/null -s -m $timeout -w "%{time_total}\n" "$source")
                    if [ $? -ne 0 ]; then
                        delay=$timeout
                    fi
                    total_delay=$(awk "BEGIN {print $total_delay + $delay}")
                done
    
                average_delay=$(awk "BEGIN {print $total_delay / $iterations}")
                echo "$average_delay"
            }
    
            min_delay=99999999
            selected_source=""
    
            for source in "${sources[@]}"; do
                average_delay=$(get_average_delay "$source" &)
    
                if (( $(awk 'BEGIN { print '"$average_delay"' < '"$min_delay"' }') )); then
                    min_delay=$average_delay
                    selected_source=$source
                fi
            done
            wait

            if [ -n "$selected_source" ]; then
                log "$CHOOSE_LOWEST_LATENCY_SOURCE $selected_source，$CHOOSE_LOWEST_LATENCY_DELAY $min_delay"
                export DOWNLOAD_URL="$selected_source"
                
                for alt_source in "${docker_install_scripts[@]}"; do
                    log "$TRY_NEXT_LINK $alt_source $DOWNLOAD_DOCKER_SCRIPT"
                    if curl -fsSL --retry 2 --retry-delay 3 --connect-timeout 5 --max-time 10 "$alt_source" -o get-docker.sh; then
                        log "$DOWNLOAD_DOCKER_SCRIPT_SUCCESS $alt_source $SUCCESSFULLY_MESSAGE"
                        break
                    else
                        log "$DOWNLOAD_FAIELD $alt_source $TRY_NEXT_LINK"
                    fi
                done
                
                if [ ! -f "get-docker.sh" ]; then
                    log "$ALL_DOWNLOAD_ATTEMPTS_FAILED"
                    log "bash <(curl -sSL https://linuxmirrors.cn/docker.sh)"
                    exit 1
                fi

                sh get-docker.sh 2>&1 | tee -a ${CURRENT_DIR}/install.log

                docker_config_folder="/etc/docker"
                if [[ ! -d "$docker_config_folder" ]];then
                    mkdir -p "$docker_config_folder"
                fi
                
                docker version >/dev/null 2>&1
                if [[ $? -ne 0 ]]; then
                    log "$DOCKER_INSTALL_FAIL"
                    exit 1
                else
                    log "$DOCKER_INSTALL_SUCCESS"
                    systemctl enable docker 2>&1 | tee -a "${CURRENT_DIR}"/install.log
                    configure_accelerator
                fi
            else
                log "$CANNOT_SELECT_SOURCE"
                exit 1
            fi
        else
            log "$REGIONS_OTHER_THAN_CHINA"
            export DOWNLOAD_URL="https://download.docker.com"
            curl -fsSL "https://get.docker.com" -o get-docker.sh
            sh get-docker.sh 2>&1 | tee -a "${CURRENT_DIR}"/install.log

            log "$DOCKER_START_NOTICE"
            systemctl enable docker; systemctl daemon-reload; systemctl start docker 2>&1 | tee -a "${CURRENT_DIR}"/install.log

            docker_config_folder="/etc/docker"
            if [[ ! -d "$docker_config_folder" ]];then
                mkdir -p "$docker_config_folder"
            fi

            docker version >/dev/null 2>&1
            if [[ $? -ne 0 ]]; then
                log "$DOCKER_INSTALL_FAIL"
                exit 1
            else
                log "$DOCKER_INSTALL_SUCCESS"
            fi
        fi
    fi
}

function Install_Compose(){
    docker-compose version >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        log "$DOCKER_COMPOSE_INSTALL_ONLINE"
        
        arch=$(uname -m)
		if [ "$arch" == 'armv7l' ]; then
			arch='armv7'
		fi
		curl -L https://resource.fit2cloud.com/docker/compose/releases/download/v2.26.1/docker-compose-$(uname -s | tr A-Z a-z)-"$arch" -o /usr/local/bin/docker-compose 2>&1 | tee -a "${CURRENT_DIR}"/install.log
        if [[ ! -f /usr/local/bin/docker-compose ]];then
            log "$DOCKER_COMPOSE_DOWNLOAD_FAIL"
            exit 1
        fi
        chmod +x /usr/local/bin/docker-compose
        ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

        docker-compose version >/dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            log "docker-compose 安装失败"
            exit 1
        else
            log "$DOCKER_COMPOSE_INSTALL_SUCCESS"
        fi
    else
        compose_v=$(docker-compose -v)
        if [[ $compose_v =~ 'docker-compose' ]];then
            read -p "$LOWER_VERSION_DETECTED " UPGRADE_DOCKER_COMPOSE
            if [[ "$UPGRADE_DOCKER_COMPOSE" == "Y" ]] || [[ "$UPGRADE_DOCKER_COMPOSE" == "y" ]]; then
                rm -rf /usr/local/bin/docker-compose /usr/bin/docker-compose
                Install_Compose
            else
                log "$DOCKER_COMPOSE_VERSION $compose_v"
            fi
        else
            log "$DOCKER_COMPOSE_INSTALLED_SKIP"
        fi
    fi
}

function Set_Port(){
    DEFAULT_PORT=$(expr $RANDOM % 55535 + 10000)

    while true; do
        read -p "$SET_PANEL_PORT $DEFAULT_PORT ）：" PANEL_PORT

        if [[ "$PANEL_PORT" == "" ]];then
            PANEL_PORT=$DEFAULT_PORT
        fi

        if ! [[ "$PANEL_PORT" =~ ^[1-9][0-9]{0,4}$ && "$PANEL_PORT" -le 65535 ]]; then
            log "$INPUT_PORT_NUMBER"
            continue
        fi

        if command -v ss >/dev/null 2>&1; then
            if ss -tlun | grep -q ":$PANEL_PORT " >/dev/null 2>&1; then
                log "$PORT_OCCUPIED $PANEL_PORT"
                continue
            fi
        elif command -v netstat >/dev/null 2>&1; then
            if netstat -tlun | grep -q ":$PANEL_PORT " >/dev/null 2>&1; then
                log "$PORT_OCCUPIED $PANEL_PORT"
                continue
            fi
        fi

         log "$THE_PORT_U_SET $PANEL_PORT"
        break
    done
}

function Set_Firewall(){
    if which firewall-cmd >/dev/null 2>&1; then
        if systemctl status firewalld | grep -q "Active: active" >/dev/null 2>&1;then
            log "$FIREWALL_OPEN_PORT $PANEL_PORT"
            firewall-cmd --zone=public --add-port="$PANEL_PORT"/tcp --permanent
            firewall-cmd --reload
        else
            log "$FIREWALL_NOT_ACTIVE_SKIP"
        fi
    fi

    if which ufw >/dev/null 2>&1; then
        if systemctl status ufw | grep -q "Active: active" >/dev/null 2>&1;then
            log "FIREWALL_OPEN_PORT $PANEL_PORT"
            ufw allow "$PANEL_PORT"/tcp
            ufw reload
        else
            log "$FIREWALL_NOT_ACTIVE_IGNORE"
        fi
    fi
}

function Set_Entrance(){
    DEFAULT_ENTRANCE=`cat /dev/urandom | head -n 16 | md5sum | head -c 10`

    while true; do
	    read -p "设置 1Panel 安全入口（默认为$DEFAULT_ENTRANCE）：" PANEL_ENTRANCE
	    if [[ "$PANEL_ENTRANCE" == "" ]]; then
    	    PANEL_ENTRANCE=$DEFAULT_ENTRANCE
    	fi

    	if [[ ! "$PANEL_ENTRANCE" =~ ^[a-zA-Z0-9_]{3,30}$ ]]; then
            log "$INPUT_ENTRANCE_RULE"
            continue
    	fi
    
        log "$SET_PANEL_ENTRANCE $PANEL_ENTRANCE"
    	break
    done
}

function Set_Username(){
    DEFAULT_USERNAME=$(cat /dev/urandom | head -n 16 | md5sum | head -c 10)

    while true; do
        read -p "$SET_PANEL_USER $DEFAULT_USERNAME）：" PANEL_USERNAME

        if [[ "$PANEL_USERNAME" == "" ]];then
            PANEL_USERNAME=$DEFAULT_USERNAME
        fi

        if [[ ! "$PANEL_USERNAME" =~ ^[a-zA-Z0-9_]{3,30}$ ]]; then
            log "$INPUT_USERNAME_RULE"
            continue
        fi

        log "$YOUR_PANEL_USERNAME $PANEL_USERNAME"
        break
    done
}


function passwd() {
    charcount='0'
    reply=''
    while :; do
        char=$(
            stty cbreak -echo
            dd if=/dev/tty bs=1 count=1 2>/dev/null
            stty -cbreak echo
        )
        case $char in
        "$(printenv '\000')")
            break
            ;;
        "$(printf '\177')" | "$(printf '\b')")
            if [ $charcount -gt 0 ]; then
                printf '\b \b'
                reply="${reply%?}"
                charcount=$((charcount - 1))
            else
                printf ''
            fi
            ;;
        "$(printf '\033')") ;;
        *)
            printf '*'
            reply="${reply}${char}"
            charcount=$((charcount + 1))
            ;;
        esac
    done
    printf '\n' >&2
}

function Set_Password(){
    DEFAULT_PASSWORD=$(cat /dev/urandom | head -n 16 | md5sum | head -c 10)

    while true; do
        log "$SET_PANEL_PASSWORD $DEFAULT_PASSWORD）："
        passwd
        PANEL_PASSWORD=$reply
        if [[ "$PANEL_PASSWORD" == "" ]];then
            PANEL_PASSWORD=$DEFAULT_PASSWORD
        fi

        if [[ ! "$PANEL_PASSWORD" =~ ^[a-zA-Z0-9_!@#$%*,.?]{8,30}$ ]]; then
            log "$INPUT_PASSWORD_RULE"
            continue
        fi

        break
    done
}

function Init_Panel(){
    log "$CONFIGURE_PANEL_SERVICE"

    RUN_BASE_DIR=$PANEL_BASE_DIR/1panel
    mkdir -p "$RUN_BASE_DIR"
    rm -rf "$RUN_BASE_DIR:?/*"

    cd "${CURRENT_DIR}" || exit

    cp ./1panel /usr/local/bin && chmod +x /usr/local/bin/1panel
    if [[ ! -f /usr/bin/1panel ]]; then
        ln -s /usr/local/bin/1panel /usr/bin/1panel >/dev/null 2>&1
    fi

    cp ./1pctl /usr/local/bin && chmod +x /usr/local/bin/1pctl
    sed -i -e "s#BASE_DIR=.*#BASE_DIR=${PANEL_BASE_DIR}#g" /usr/local/bin/1pctl
    sed -i -e "s#ORIGINAL_PORT=.*#ORIGINAL_PORT=${PANEL_PORT}#g" /usr/local/bin/1pctl
    sed -i -e "s#ORIGINAL_USERNAME=.*#ORIGINAL_USERNAME=${PANEL_USERNAME}#g" /usr/local/bin/1pctl
    ESCAPED_PANEL_PASSWORD=$(echo "$PANEL_PASSWORD" | sed 's/[!@#$%*_,.?]/\\&/g')
    sed -i -e "s#ORIGINAL_PASSWORD=.*#ORIGINAL_PASSWORD=${ESCAPED_PANEL_PASSWORD}#g" /usr/local/bin/1pctl
    sed -i -e "s#ORIGINAL_ENTRANCE=.*#ORIGINAL_ENTRANCE=${PANEL_ENTRANCE}#g" /usr/local/bin/1pctl
    if [[ ! -f /usr/bin/1pctl ]]; then
        ln -s /usr/local/bin/1pctl /usr/bin/1pctl >/dev/null 2>&1
    fi

    cp ./1panel.service /etc/systemd/system

    systemctl enable 1panel; systemctl daemon-reload 2>&1 | tee -a "${CURRENT_DIR}"/install.log

    log "$START_PANEL_SERVICE"
    systemctl start 1panel | tee -a "${CURRENT_DIR}"/install.log

    for b in {1..30}
    do
        sleep 3
        service_status=$(systemctl status 1panel 2>&1 | grep Active)
        if [[ $service_status == *running* ]];then
            log "$PANEL_SERVICE_START_SUCCESS"
            break;
        else
            log "$PANEL_SERVICE_START_ERROR"
            exit 1
        fi
    done
    sed -i -e "s#ORIGINAL_PASSWORD=.*#ORIGINAL_PASSWORD=\*\*\*\*\*\*\*\*\*\*#g" /usr/local/bin/1pctl
}

function Get_Ip(){
    active_interface=$(ip route get 8.8.8.8 | awk 'NR==1 {print $5}')
    if [[ -z $active_interface ]]; then
        LOCAL_IP="127.0.0.1"
    else
        LOCAL_IP=$(ip -4 addr show dev "$active_interface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    fi

    PUBLIC_IP=$(curl -s https://api64.ipify.org)
    if [[ -z "$PUBLIC_IP" ]]; then
        PUBLIC_IP="N/A"
    fi
    if echo "$PUBLIC_IP" | grep -q ":"; then
        PUBLIC_IP=[${PUBLIC_IP}]
        1pctl listen-ip ipv6
    fi
}

function Show_Result(){
    log ""
    log "$THANK_YOU_WAITING"
    log ""
    log "$BROWSER_ACCESS_PANEL:"
    log "$EXTERNAL_ADDRESS http://$PUBLIC_IP:$PANEL_PORT/$PANEL_ENTRANCE"
    log "$INTERNAL_ADDRESS: http://$LOCAL_IP:$PANEL_PORT/$PANEL_ENTRANCE"
    log "$PANEL_USER $PANEL_USERNAME"
    log "$PANEL_PASSWORD $PANEL_PASSWORD"
    log ""
    log "$PROJECT_OFFICIAL_WEBSITE https://1panel.cn"
    log "$PROJECT_DOCUMENTATION https://1panel.cn/docs"
    log "$PROJECT_REPOSITORY https://github.com/1Panel-dev/1Panel"
    log ""
    log "$OPEN_PORT_SECURITY_GROUP $PANEL_PORT"
    log ""
    log "$REMEMBER_YOUR_PASSWORD"
    log ""
    log "================================================================"
}

function main(){
    Check_Root
    Prepare_System
    Set_Dir
    Install_Docker
    Install_Compose
    Set_Port
    Set_Firewall
    Set_Entrance
    Set_Username
    Set_Password
    Init_Panel
    Get_Ip
    Show_Result
}
main