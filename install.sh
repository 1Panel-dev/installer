#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CURRENT_DIR=$(
    cd "$(dirname "$0")" || exit
    pwd
)

LANG_FILE=".selected_language"
LANG_DIR="$CURRENT_DIR/lang"
AVAILABLE_LANGS=("en" "zh" "fa" "pt-BR" "ru")

declare -A LANG_NAMES
LANG_NAMES=( ["en"]="English" ["zh"]="Chinese  中文(简体)" ["fa"]="Persian" ["pt-BR"]="Português (Brasil)" ["ru"]="Русский" )

if [ -f "$CURRENT_DIR/$LANG_FILE" ]; then
    selected_lang=$(cat "$CURRENT_DIR/$LANG_FILE")
else
    echo "en" > "$CURRENT_DIR/$LANG_FILE"
    source "$LANG_DIR/en.sh"

    echo "$TXT_LANG_PROMPT_MSG"
    for i in "${!AVAILABLE_LANGS[@]}"; do
        lang_code="${AVAILABLE_LANGS[i]}"
        echo "$((i + 1)). ${LANG_NAMES[$lang_code]}"
    done

    read -p "$TXT_LANG_CHOICE_MSG" lang_choice

    if [[ $lang_choice -ge 1 && $lang_choice -le ${#AVAILABLE_LANGS[@]} ]]; then
        selected_lang=${AVAILABLE_LANGS[$((lang_choice - 1))]}
        echo "$TXT_LANG_SELECTED_CONFIRM_MSG ${LANG_NAMES[$selected_lang]}"
        echo "$selected_lang" > "$CURRENT_DIR/$LANG_FILE"
    else
        echo "$TXT_LANG_INVALID_MSG"
        selected_lang="en"
        echo "$selected_lang" > "$CURRENT_DIR/$LANG_FILE"
    fi
fi

LANGFILE="$LANG_DIR/$selected_lang.sh"
if [ -f "$LANGFILE" ]; then
    source "$LANGFILE"
else
    echo -e "${RED} $TXT_LANG_NOT_FOUND_MSG $LANGFILE${NC}"
    exit 1
fi
clear

LOG_FILE=${CURRENT_DIR}/install.log
PASSWORD_MASK="**********"

function log() {
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    message="[1Panel ${timestamp} install Log]: $1 "
    case "$1" in
        *"$TXT_RUN_AS_ROOT"*)
            echo -e "${RED}${message}${NC}" 2>&1 | tee -a ${LOG_FILE}
            ;;
        *"$TXT_SUCCESS_MESSAGE"* )
            echo -e "${GREEN}${message}${NC}" 2>&1 | tee -a ${LOG_FILE}
            ;;
        *"$TXT_IGNORE_MESSAGE"*|*"$TXT_SKIP_MESSAGE"* )
            echo -e "${YELLOW}${message}${NC}" 2>&1 | tee -a ${LOG_FILE}
            ;;
        * )
            echo -e "${BLUE}${message}${NC}" 2>&1 | tee -a ${LOG_FILE}
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

log "$TXT_START_INSTALLATION"

function Check_Root() {
    if [[ $EUID -ne 0 ]]; then
        log "$TXT_RUN_AS_ROOT"
        exit 1
    fi
}

function Prepare_System(){
    if which 1panel >/dev/null 2>&1; then
        log "$TXT_PANEL_ALREADY_INSTALLED"
        exit 1
    fi
}

function Set_Dir(){
    if read -t 120 -p "$TXT_SET_INSTALL_DIR" PANEL_BASE_DIR;then
        if [[ "$PANEL_BASE_DIR" != "" ]];then
            if [[ "$PANEL_BASE_DIR" != /* ]];then
                log "$TXT_PROVIDE_FULL_PATH"
                Set_Dir
            fi

            if [[ ! -d $PANEL_BASE_DIR ]];then
                mkdir -p "$PANEL_BASE_DIR"
                log "$TXT_SELECTED_INSTALL_PATH $PANEL_BASE_DIR"
            fi
        else
            PANEL_BASE_DIR=/opt
            log "$TXT_SELECTED_INSTALL_PATH $PANEL_BASE_DIR"
        fi
    else
        PANEL_BASE_DIR=/opt
        log "$TXT_TIMEOUT_USE_DEFAULT_PATH"
    fi
}

ACCELERATOR_URL="https://docker.1panel.live"
DAEMON_JSON="/etc/docker/daemon.json"
BACKUP_FILE="/etc/docker/daemon.json.1panel_bak"

function create_daemon_json() {
    log "$TXT_CREATE_NEW_CONFIG ${DAEMON_JSON}..."
    mkdir -p /etc/docker
    echo '{
        "registry-mirrors": ["'"$ACCELERATOR_URL"'"]
    }' | tee "$DAEMON_JSON" > /dev/null
    log "$TXT_ACCELERATION_CONFIG_ADDED"
}

function configure_accelerator() {
    read -p "$TXT_ACCELERATION_CONFIG_ADD " configure_accelerator
    if [[ "$configure_accelerator" == "y" ]]; then
        if ping -c 1 mirror.ccs.tencentyun.com &>/dev/null; then
            ACCELERATOR_URL="https://mirror.ccs.tencentyun.com"
            log "$TXT_USING_TENCENT_MIRROR"
        fi

        if [ -f "$DAEMON_JSON" ]; then
            log "$TXT_ACCELERATION_CONFIG_EXISTS ${BACKUP_FILE}."
            cp "$DAEMON_JSON" "$BACKUP_FILE"
            create_daemon_json
        else
            create_daemon_json
        fi

        log "$TXT_RESTARTING_DOCKER"
        systemctl daemon-reload
        systemctl restart docker
        log "$TXT_DOCKER_RESTARTED"
    else
        log "$TXT_ACCELERATION_CONFIG_NOT"
    fi
}

function Install_Docker(){
    if which docker >/dev/null 2>&1; then
        docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+' | head -n 1)
        major_version=${docker_version%%.*}
        minor_version=${docker_version##*.}
        local service_cmd="service dockerd start && service dockerd status"
        if command -v systemctl &>/dev/null; then
            service_cmd="systemctl start docker && systemctl status docker"
        fi
        if [[ $($service_cmd 2>&1)  == *running* ]]; then
            log "$TXT_DOCKER_RESTARTED"

        else
            if [[ $major_version -lt 20 ]]; then
                log "$TXT_LOW_DOCKER_VERSION"
            fi

            if [[ $(curl -s ipinfo.io/country) == "CN" ]]; then
                configure_accelerator
            fi
        fi
    else
        log "$TXT_DOCKER_INSTALL_ONLINE"
        if  command -v opkg &>/dev/null;then
            log $TXT_INSTALL_DOCKER_ONLINE
            opkg update
            opkg install luci-i18n-dockerman-zh-cn
            opkg install zoneinfo-asia
            service system restart
        else
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
                log "$TXT_CHOOSE_LOWEST_LATENCY_SOURCE $selected_source，$TXT_CHOOSE_LOWEST_LATENCY_DELAY $min_delay"
                export DOWNLOAD_URL="$selected_source"
                
                for alt_source in "${docker_install_scripts[@]}"; do
                    log "$TXT_TRY_NEXT_LINK $alt_source $TXT_DOWNLOAD_DOCKER_SCRIPT"
                    if curl -fsSL --retry 2 --retry-delay 3 --connect-timeout 5 --max-time 10 "$alt_source" -o get-docker.sh; then
                        log "$TXT_DOWNLOAD_DOCKER_SCRIPT_SUCCESS $alt_source $TXT_SUCCESSFULLY_MESSAGE"
                        break
                    else
                        log "$TXT_DOWNLOAD_FAIELD $alt_source $TXT_TRY_NEXT_LINK"
                    fi
                done
                
                if [ ! -f "get-docker.sh" ]; then
                    log "$TXT_ALL_DOWNLOAD_ATTEMPTS_FAILED"
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
                    log "$TXT_DOCKER_INSTALL_FAIL"
                    exit 1
                else
                    log "$TXT_DOCKER_INSTALL_SUCCESS"
                    systemctl enable docker 2>&1 | tee -a ${LOG_FILE}
                    configure_accelerator
                fi
            else
                log "$TXT_CANNOT_SELECT_SOURCE"
                exit 1
            fi
        else
            log "$TXT_REGIONS_OTHER_THAN_CHINA"
            export DOWNLOAD_URL="https://download.docker.com"
            curl -fsSL "https://get.docker.com" -o get-docker.sh
            sh get-docker.sh 2>&1 | tee -a ${LOG_FILE}

            log "$TXT_DOCKER_START_NOTICE"
            systemctl enable docker; systemctl daemon-reload; systemctl start docker 2>&1 | tee -a ${LOG_FILE}

                docker_config_folder="/etc/docker"
                if [[ ! -d "$docker_config_folder" ]];then
                    mkdir -p "$docker_config_folder"
                fi
            fi
        fi

            docker version >/dev/null 2>&1
            if [[ $? -ne 0 ]]; then
                log "$TXT_DOCKER_INSTALL_FAIL"
                exit 1
            else
                log "$TXT_DOCKER_INSTALL_SUCCESS"
            fi
    fi
}

function Install_Compose(){
    docker-compose version >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        log "$TXT_DOCKER_COMPOSE_INSTALL_ONLINE"
        if which opkg &>/dev/null;then
            opkg update || log $TXT_DOCKER_COMPOSE_DOWNLOAD_FAIL
            opkg install docker-compose
        else
            arch=$(uname -m)
            if [ "$arch" == 'armv7l' ]; then
                arch='armv7'
            fi
            curl -L https://resource.fit2cloud.com/docker/compose/releases/download/v2.26.1/docker-compose-$(uname -s | tr A-Z a-z)-$arch -o /usr/local/bin/docker-compose 2>&1 | tee -a ${LOG_FILE}
            if [[ ! -f /usr/local/bin/docker-compose ]];then
                log $TXT_DOCKER_COMPOSE_DOWNLOAD_FAIL
                exit 1
            fi
            chmod +x /usr/local/bin/docker-compose
            ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
        fi

        docker-compose version >/dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            log "$TXT_DOCKER_COMPOSE_INSTALL_FAIL"
            exit 1
        else
            log "$TXT_DOCKER_COMPOSE_INSTALL_SUCCESS"
        fi
    else
        compose_v=$(docker-compose -v)
        if [[ $compose_v =~ 'docker-compose' ]];then
            read -p "$TXT_LOWER_VERSION_DETECTED " UPGRADE_DOCKER_COMPOSE
            if [[ "$UPGRADE_DOCKER_COMPOSE" == "Y" ]] || [[ "$UPGRADE_DOCKER_COMPOSE" == "y" ]]; then
                rm -rf /usr/local/bin/docker-compose /usr/bin/docker-compose
                Install_Compose
            else
                log "$TXT_DOCKER_COMPOSE_VERSION $compose_v"
            fi
        else
            log "$TXT_DOCKER_COMPOSE_INSTALLED_SKIP"
        fi
    fi
}

function Set_Port(){
    DEFAULT_PORT=$(expr $RANDOM % 55535 + 10000)

    while true; do
        read -p "$TXT_SET_PANEL_PORT $DEFAULT_PORT): " PANEL_PORT

        if [[ "$PANEL_PORT" == "" ]];then
            PANEL_PORT=$DEFAULT_PORT
        fi

        if ! [[ "$PANEL_PORT" =~ ^[1-9][0-9]{0,4}$ && "$PANEL_PORT" -le 65535 ]]; then
            log "$TXT_INPUT_PORT_NUMBER"
            continue
        fi
        if command -v lsof >/dev/null 2>&1; then 
	        if lsof -i:$PANEL_PORT >/dev/null 2>&1; then
                log "$TXT_PORT_OCCUPIED $PANEL_PORT"
                continue
            fi
        elif command -v ss >/dev/null 2>&1; then
            if ss -tlun | grep -q ":$PANEL_PORT " >/dev/null 2>&1; then
                log "$TXT_PORT_OCCUPIED $PANEL_PORT"
                continue
            fi
        elif command -v netstat >/dev/null 2>&1; then
            if netstat -tlun | grep -q ":$PANEL_PORT " >/dev/null 2>&1; then
                log "$TXT_PORT_OCCUPIED $PANEL_PORT"
                continue
            fi
        fi

         log "$TXT_THE_PORT_U_SET $PANEL_PORT"
        break
    done
}

function Set_Firewall(){
    if which firewall-cmd >/dev/null 2>&1; then
        if systemctl status firewalld | grep -q "Active: active" >/dev/null 2>&1;then
            log "$TXT_FIREWALL_OPEN_PORT $PANEL_PORT"
            firewall-cmd --zone=public --add-port="$PANEL_PORT"/tcp --permanent
            firewall-cmd --reload
        else
            log "$TXT_FIREWALL_NOT_ACTIVE_SKIP"
        fi
    fi

    if which ufw >/dev/null 2>&1; then
        if systemctl status ufw | grep -q "Active: active" >/dev/null 2>&1;then
            log "$TXT_FIREWALL_OPEN_PORT $PANEL_PORT"
            ufw allow "$PANEL_PORT"/tcp
            ufw reload
        else
            log "$TXT_FIREWALL_NOT_ACTIVE_IGNORE"
        fi
    fi
}

function Set_Entrance(){
    DEFAULT_ENTRANCE=`cat /dev/urandom | head -n 16 | md5sum | head -c 10`

    while true; do
	    read -p "$TXT_SET_PANEL_ENTRANCE $DEFAULT_ENTRANCE): " PANEL_ENTRANCE
	    if [[ "$PANEL_ENTRANCE" == "" ]]; then
    	    PANEL_ENTRANCE=$DEFAULT_ENTRANCE
    	fi

    	if [[ ! "$PANEL_ENTRANCE" =~ ^[a-zA-Z0-9_]{3,30}$ ]]; then
            log "$TXT_INPUT_ENTRANCE_RULE"
            continue
    	fi
    
        log "$TXT_YOUR_PANEL_ENTRANCE $PANEL_ENTRANCE"
    	break
    done
}

function Set_Username(){
    DEFAULT_USERNAME=$(cat /dev/urandom | head -n 16 | md5sum | head -c 10)

    while true; do
        read -p "$TXT_SET_PANEL_USER $DEFAULT_USERNAME): " PANEL_USERNAME

        if [[ "$PANEL_USERNAME" == "" ]];then
            PANEL_USERNAME=$DEFAULT_USERNAME
        fi

        if [[ ! "$PANEL_USERNAME" =~ ^[a-zA-Z0-9_]{3,30}$ ]]; then
            log "$TXT_INPUT_USERNAME_RULE"
            continue
        fi

        log "$TXT_YOUR_PANEL_USERNAME $PANEL_USERNAME"
        break
    done
}


function passwd() {
    if which stty >/dev/null 2>&1; then
        log "$TXT_SET_PANEL_PASSWORD $DEFAULT_PASSWORD): "
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
    else
        read -s -p "$TXT_SET_PANEL_PASSWORD: $DEFAULT_PASSWORD):" reply
        printf '\n' >&2
    fi
}

function Set_Password(){
    DEFAULT_PASSWORD=$(cat /dev/urandom | head -n 16 | md5sum | head -c 10)

    while true; do
        
        passwd
        PANEL_PASSWORD=$reply
        if [[ "$PANEL_PASSWORD" == "" ]];then
            PANEL_PASSWORD=$DEFAULT_PASSWORD
        fi

        if [[ ! "$PANEL_PASSWORD" =~ ^[a-zA-Z0-9_!@#$%*,.?]{8,30}$ ]]; then
            log "$TXT_INPUT_PASSWORD_RULE"
            continue
        fi

        break
    done
}

init_configure() {
    cp ./1panel /usr/local/bin && chmod +x /usr/local/bin/1panel
    ln -s /usr/local/bin/1panel /usr/bin/1panel >/dev/null 2>&1
    cp ./1pctl /usr/local/bin && chmod +x /usr/local/bin/1pctl
    ln -s /usr/local/bin/1pctl /usr/bin/1pctl >/dev/null 2>&1
    sed -i -e "s#BASE_DIR=.*#BASE_DIR=${PANEL_BASE_DIR}#g" /usr/local/bin/1pctl
    sed -i -e "s#ORIGINAL_PORT=.*#ORIGINAL_PORT=${PANEL_PORT}#g" /usr/local/bin/1pctl
    sed -i -e "s#ORIGINAL_USERNAME=.*#ORIGINAL_USERNAME=${PANEL_USERNAME}#g" /usr/local/bin/1pctl
    ESCAPED_PANEL_PASSWORD=$(echo "$PANEL_PASSWORD" | sed 's/[!@#$%*_,.?]/\\&/g')
    sed -i -e "s#ORIGINAL_PASSWORD=.*#ORIGINAL_PASSWORD=${ESCAPED_PANEL_PASSWORD}#g" /usr/local/bin/1pctl
    sed -i -e "s#ORIGINAL_ENTRANCE=.*#ORIGINAL_ENTRANCE=${PANEL_ENTRANCE}#g" /usr/local/bin/1pctl
    sed -i -e "s#LANGUAGE=.*#LANGUAGE=${selected_lang}#g" /usr/local/bin/1pctl
    if [ -f "./GeoIP.mmdb" ]; then
        mkdir -p $RUN_BASE_DIR/geo/
        cp -r ./GeoIP.mmdb $RUN_BASE_DIR/geo/
        cp -r ./lang /usr/local/bin
    fi
    }
    
install_and_configure() {
    if which opkg &>/dev/null; then
        mkdir -p /usr/local/bin
	init_configure
        echo "#!/bin/sh /etc/rc.common
USE_PROCD=1

START=95
STOP=15
NAME=1panel
start_service() {
    procd_open_instance
    procd_set_param command 1panel
    procd_set_param stdout 0 # 默认设置不输出系统日志，如为1，在系统日志可看到1panel前端响应信息
    procd_set_param stderr 1
    procd_close_instance
    }
" > /etc/init.d/1paneld

        chmod +x /etc/init.d/1paneld
        /etc/init.d/1paneld enable && /etc/init.d/1paneld reload 2>&1 | tee -a ${LOG_FILE}
        /etc/init.d/1paneld start | tee -a ${LOG_FILE}
    else
    	init_configure
        cp ./1panel.service /etc/systemd/system
        systemctl enable 1panel.service; systemctl daemon-reload 2>&1 | tee -a ${LOG_FILE}
        systemctl start 1panel.service | tee -a ${LOG_FILE}
    fi
}

function Init_Panel(){
    log "$TXT_CONFIGURE_PANEL_SERVICE"
    MAX_ATTEMPTS=5
    RUN_BASE_DIR=$PANEL_BASE_DIR/1panel
    mkdir -p $RUN_BASE_DIR
    rm -rf $RUN_BASE_DIR/* 2>/dev/null

    cd ${CURRENT_DIR}

    install_and_configure

    for attempt in $(seq 1 $MAX_ATTEMPTS); do
        if [[ $(command -v opkg) && $(/etc/init.d/1paneld status 2>&1) == *running* ]]; then
            log "$TXT_START_PANEL_SERVICE"
            break
        elif [[ $(command -v systemctl) && $(systemctl status 1panel 2>&1) =~ Active.*running ]]; then
            log "$TXT_START_PANEL_SERVICE"
            break
        else
            if [ $attempt -eq $MAX_ATTEMPTS ]; then
                log "$TXT_PANEL_SERVICE_START_ERROR"
                exit 1
            else
                log $TXT_SERVICE_RETRY_MSG  $((MAX_ATTEMPTS - attempt)) 
                sleep 2
            fi
        fi
    done
}


function Get_Ip(){
    active_interface=$(ip route get 8.8.8.8 | awk 'NR==1 {print $5}')
    PUBLIC_IP=`curl -s https://api64.ipify.org`
    if [[ -z $active_interface ]]; then
        LOCAL_IP="127.0.0.1"
    elif [[ $active_interface =~ pppoe ]]; then
        PUBLIC_IP=$(ip -4 addr show dev "$active_interface" |  grep -oE 'inet[[:space:]]+([0-9]{1,3}\.){3}[0-9]{1,3}' | awk '{print $2}')
        LOCAL_IP=$(ip -4 addr show | grep -E 'br-lan.*' | grep -oE 'inet[[:space:]]+([0-9]{1,3}\.){3}[0-9]{1,3}' | awk '{print $2}')
    else
        if which opkg &>/dev/null;then
            LOCAL_IP=$(ip -4 addr show | grep -E 'br-lan.*' | grep -oE 'inet[[:space:]]+([0-9]{1,3}\.){3}[0-9]{1,3}' | awk '{print $2}' | awk -F '/' '{print $1}')
        else
            LOCAL_IP=`ip -4 addr show dev "$active_interface" |  grep -oE 'inet[[:space:]]+([0-9]{1,3}\.){3}[0-9]{1,3}' | awk '{print $2}'`
        fi
    fi

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
    log "$TXT_THANK_YOU_WAITING"
    log ""
    log "$TXT_BROWSER_ACCESS_PANEL"
    log "$TXT_EXTERNAL_ADDRESS http://$PUBLIC_IP:$PANEL_PORT/$PANEL_ENTRANCE"
    log "$TXT_INTERNAL_ADDRESS http://$LOCAL_IP:$PANEL_PORT/$PANEL_ENTRANCE"
    log "$TXT_PANEL_USER $PANEL_USERNAME"
    log "$TXT_PANEL_PASSWORD $PANEL_PASSWORD"
    log ""
    log "$TXT_PROJECT_OFFICIAL_WEBSITE"
    log "$TXT_PROJECT_DOCUMENTATION"
    log "$TXT_PROJECT_REPOSITORY"
    log "$TXT_COMMUNITY"
    log ""
    log "$TXT_OPEN_PORT_SECURITY_GROUP $PANEL_PORT"
    log ""
    log "$TXT_REMEMBER_YOUR_PASSWORD"
    log ""
    log "================================================================"
    sed -i -e "s/${TXT_PANEL_PASSWORD}.*/${TXT_PANEL_PASSWORD} ${PASSWORD_MASK}/g" "${LOG_FILE}"
    sed -i -e "s#ORIGINAL_PASSWORD=.*#ORIGINAL_PASSWORD=${PASSWORD_MASK}#g" /usr/local/bin/1pctl
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
