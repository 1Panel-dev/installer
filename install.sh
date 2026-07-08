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
EDITION_FILE=".selected_edition"
LANG_DIR="$CURRENT_DIR/lang"
AVAILABLE_LANGS=("en" "zh" "fa" "pt-BR" "ru")

function lang_name() {
    case "$1" in
        en)
            echo "English"
            ;;
        zh)
            echo "Chinese  中文(简体)"
            ;;
        fa)
            echo "Persian"
            ;;
        pt-BR)
            echo "Português (Brasil)"
            ;;
        ru)
            echo "Русский"
            ;;
    esac
}

NON_INTERACTIVE=false
CONFIG_LANG="${PANEL_LANG:-}"
CONFIG_INSTALL_DIR="${PANEL_INSTALL_DIR:-}"
CONFIG_PORT="${PANEL_PORT:-}"
CONFIG_ENTRANCE="${PANEL_ENTRANCE:-}"
CONFIG_USERNAME="${PANEL_USERNAME:-}"
CONFIG_PASSWORD="${PANEL_PASSWORD:-}"
CONFIG_INSTALL_DOCKER="${PANEL_INSTALL_DOCKER:-}"
CONFIG_DOCKER_MODE="${PANEL_DOCKER_MODE:-}"
CONFIG_CONFIGURE_ACCELERATOR="${PANEL_CONFIGURE_ACCELERATOR:-}"
CONFIG_REPLACE_DAEMON_JSON="${PANEL_REPLACE_DAEMON_JSON:-}"

function usage() {
    cat << EOF
Usage: bash install.sh [options]

Options:
  --non-interactive, -y             Use defaults for prompts that are not configured.
  --lang <lang>                     Set language: en, zh, fa, pt-BR, ru.
  --install-dir <path>              Set installation directory.
  --port <port>                     Set panel port.
  --entrance <entrance>             Set panel secure entrance.
  --username <username>             Set panel username.
  --password <password>             Set panel password (prefer PANEL_PASSWORD).
  --install-docker <y|n>            Choose whether to install Docker (non-interactive default: n).
  --docker-mode <auto|builtin|online>
                                    Choose built-in Docker when available or online Docker.
  --configure-accelerator <y|n>     Choose whether to configure Docker registry mirrors (non-interactive default: n).
  --replace-daemon-json <y|n>       Choose whether to replace existing Docker daemon.json (non-interactive default: n).
  -h, --help                        Show this help.

Environment variables:
  PANEL_NON_INTERACTIVE          Use defaults for prompts that are not configured.
  PANEL_LANG                     Set language: en, zh, fa, pt-BR, ru.
  PANEL_INSTALL_DIR              Set installation directory.
  PANEL_PORT                     Set panel port.
  PANEL_ENTRANCE                 Set panel secure entrance.
  PANEL_USERNAME                 Set panel username.
  PANEL_PASSWORD                 Set panel password.
  PANEL_INSTALL_DOCKER           Choose whether to install Docker (non-interactive default: n).
  PANEL_DOCKER_MODE              Choose Docker install mode: auto, builtin, online.
  PANEL_CONFIGURE_ACCELERATOR    Choose whether to configure Docker registry mirrors (non-interactive default: n).
  PANEL_REPLACE_DAEMON_JSON      Choose whether to replace existing Docker daemon.json (non-interactive default: n).

Docker install and registry mirror options default to n in non-interactive mode unless explicitly set.
EOF
}

function is_true() {
    case "$1" in
        true|TRUE|True|1|y|Y|yes|YES|Yes)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

function require_arg() {
    if [[ -z "$2" ]]; then
        echo "Option $1 requires a value"
        exit 1
    fi
}

function parse_args() {
    if is_true "${PANEL_NON_INTERACTIVE:-}"; then
        NON_INTERACTIVE=true
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --non-interactive|-y)
                NON_INTERACTIVE=true
                ;;
            --lang)
                require_arg "$1" "$2"
                CONFIG_LANG="$2"
                shift
                ;;
            --lang=*)
                CONFIG_LANG="${1#*=}"
                ;;
            --install-dir)
                require_arg "$1" "$2"
                CONFIG_INSTALL_DIR="$2"
                shift
                ;;
            --install-dir=*)
                CONFIG_INSTALL_DIR="${1#*=}"
                ;;
            --port)
                require_arg "$1" "$2"
                CONFIG_PORT="$2"
                shift
                ;;
            --port=*)
                CONFIG_PORT="${1#*=}"
                ;;
            --entrance)
                require_arg "$1" "$2"
                CONFIG_ENTRANCE="$2"
                shift
                ;;
            --entrance=*)
                CONFIG_ENTRANCE="${1#*=}"
                ;;
            --username)
                require_arg "$1" "$2"
                CONFIG_USERNAME="$2"
                shift
                ;;
            --username=*)
                CONFIG_USERNAME="${1#*=}"
                ;;
            --password)
                require_arg "$1" "$2"
                CONFIG_PASSWORD="$2"
                shift
                ;;
            --password=*)
                CONFIG_PASSWORD="${1#*=}"
                ;;
            --install-docker)
                require_arg "$1" "$2"
                CONFIG_INSTALL_DOCKER="$2"
                shift
                ;;
            --install-docker=*)
                CONFIG_INSTALL_DOCKER="${1#*=}"
                ;;
            --docker-mode)
                require_arg "$1" "$2"
                CONFIG_DOCKER_MODE="$2"
                shift
                ;;
            --docker-mode=*)
                CONFIG_DOCKER_MODE="${1#*=}"
                ;;
            --configure-accelerator)
                require_arg "$1" "$2"
                CONFIG_CONFIGURE_ACCELERATOR="$2"
                shift
                ;;
            --configure-accelerator=*)
                CONFIG_CONFIGURE_ACCELERATOR="${1#*=}"
                ;;
            --replace-daemon-json)
                require_arg "$1" "$2"
                CONFIG_REPLACE_DAEMON_JSON="$2"
                shift
                ;;
            --replace-daemon-json=*)
                CONFIG_REPLACE_DAEMON_JSON="${1#*=}"
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unsupported option: $1"
                usage
                exit 1
                ;;
        esac
        shift
    done
}

function is_supported_lang() {
    local lang="$1"
    local lang_code
    for lang_code in "${AVAILABLE_LANGS[@]}"; do
        if [[ "$lang_code" == "$lang" ]]; then
            return 0
        fi
    done
    return 1
}

function init_language() {
    if [[ -n "$CONFIG_LANG" ]]; then
        if ! is_supported_lang "$CONFIG_LANG"; then
            echo "Unsupported language: $CONFIG_LANG"
            exit 1
        fi
        selected_lang="$CONFIG_LANG"
        echo "$selected_lang" > "$CURRENT_DIR/$LANG_FILE"
        return
    fi

    if [ -f "$CURRENT_DIR/$LANG_FILE" ]; then
        selected_lang=$(cat "$CURRENT_DIR/$LANG_FILE")
        if is_supported_lang "$selected_lang"; then
            return
        fi
    fi

    if [[ "$NON_INTERACTIVE" == true ]]; then
        if [[ "$selected_edition" == "cn" ]]; then
            selected_lang="zh"
        else
            selected_lang="en"
        fi
        echo "$selected_lang" > "$CURRENT_DIR/$LANG_FILE"
        return
    fi

    echo "en" > "$CURRENT_DIR/$LANG_FILE"
    source "$LANG_DIR/en.sh"

    echo "$TXT_LANG_PROMPT_MSG"
    for i in "${!AVAILABLE_LANGS[@]}"; do
        lang_code="${AVAILABLE_LANGS[i]}"
        echo "$((i + 1)). $(lang_name "$lang_code")"
    done

    read -p "$TXT_LANG_CHOICE_MSG" lang_choice

    if [[ $lang_choice -ge 1 && $lang_choice -le ${#AVAILABLE_LANGS[@]} ]]; then
        selected_lang=${AVAILABLE_LANGS[$((lang_choice - 1))]}
        echo "$TXT_LANG_SELECTED_CONFIRM_MSG $(lang_name "$selected_lang")"
        echo "$selected_lang" > "$CURRENT_DIR/$LANG_FILE"
    else
        echo "$TXT_LANG_INVALID_MSG"
        selected_lang="en"
        echo "$selected_lang" > "$CURRENT_DIR/$LANG_FILE"
    fi
}

if [ -f "$CURRENT_DIR/$EDITION_FILE" ]; then
    selected_edition=$(cat "$CURRENT_DIR/$EDITION_FILE")
else
    selected_edition="cn"
fi

parse_args "$@"
init_language

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

function normalize_yn() {
    case "$1" in
        y|Y|yes|YES|Yes|true|TRUE|True|1)
            echo "y"
            return 0
            ;;
        n|N|no|NO|No|false|FALSE|False|0)
            echo "n"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

ASK_YN_RESULT=""
function ask_yn() {
    local prompt="$1"
    local interactive_default="$2"
    local non_interactive_default="$3"
    local provided_choice="$4"
    local choice
    local normalized

    if [[ -n "$provided_choice" ]]; then
        if ! normalized=$(normalize_yn "$provided_choice"); then
            log "$TXT_INVALID_YN_INPUT"
            exit 1
        fi
        ASK_YN_RESULT="$normalized"
        return
    fi

    if [[ "$NON_INTERACTIVE" == true ]]; then
        ASK_YN_RESULT="$non_interactive_default"
        return
    fi

    while true; do
        read -p "$prompt" choice
        if [[ -z "$choice" && -n "$interactive_default" ]]; then
            choice="$interactive_default"
        fi
        if normalized=$(normalize_yn "$choice"); then
            ASK_YN_RESULT="$normalized"
            return
        fi
        log "$TXT_INVALID_YN_INPUT"
    done
}

function escape_sed_replacement() {
    printf '%s' "$1" | sed 's/[\\&#]/\\&/g'
}

function validate_panel_dir() {
    [[ "$1" == /* && "$1" != *$'\n'* ]]
}

function validate_panel_port() {
    [[ "$1" =~ ^[1-9][0-9]{0,4}$ && "$1" -le 65535 ]]
}

function panel_port_occupied() {
    local port="$1"
    if command -v netstat >/dev/null 2>&1; then
        netstat -tlun | grep -q ":$port " >/dev/null 2>&1
    elif command -v ss >/dev/null 2>&1; then
        ss -tlun | grep -q ":$port " >/dev/null 2>&1
    elif command -v lsof >/dev/null 2>&1; then
        lsof -i:"$port" >/dev/null 2>&1
    else
        return 1
    fi
}

function validate_panel_entrance() {
    [[ "$1" =~ ^[a-zA-Z0-9_]{3,30}$ ]]
}

function validate_panel_username() {
    [[ "$1" =~ ^[a-zA-Z0-9_]{3,30}$ ]]
}

function validate_panel_password() {
    [[ "$1" =~ ^[a-zA-Z0-9_!@#$%*,.?]{8,30}$ ]]
}

function normalize_docker_mode() {
    case "$1" in
        ""|auto|AUTO|Auto)
            echo "auto"
            ;;
        builtin|BUILTIN|Builtin|offline|OFFLINE|Offline)
            echo "builtin"
            ;;
        online|ONLINE|Online)
            echo "online"
            ;;
        *)
            return 1
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

USE_EXISTING=false
function Set_Dir(){
    if [[ -n "$CONFIG_INSTALL_DIR" ]]; then
        PANEL_BASE_DIR="$CONFIG_INSTALL_DIR"
        if ! validate_panel_dir "$PANEL_BASE_DIR"; then
            log "$TXT_PROVIDE_FULL_PATH"
            exit 1
        fi
        if [[ ! -d $PANEL_BASE_DIR ]]; then
            mkdir -p "$PANEL_BASE_DIR"
        fi
        log "$TXT_SELECTED_INSTALL_PATH $PANEL_BASE_DIR"
    elif [[ "$NON_INTERACTIVE" == true ]]; then
        PANEL_BASE_DIR=/opt
        log "$TXT_SELECTED_INSTALL_PATH $PANEL_BASE_DIR"
    else
        if read -t 120 -p "$TXT_SET_INSTALL_DIR" PANEL_BASE_DIR; then
            if [[ "$PANEL_BASE_DIR" != "" ]]; then
                if ! validate_panel_dir "$PANEL_BASE_DIR"; then
                    log "$TXT_PROVIDE_FULL_PATH"
                    Set_Dir
                    return
                fi

                if [[ ! -d $PANEL_BASE_DIR ]]; then
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
    fi

    if [[ -f "$PANEL_BASE_DIR/1panel/db/core.db" ]]; then
        USE_EXISTING=true
    fi
}

ACCELERATOR_URLS='    "https://docker.1panel.live",
    "https://hub.1panel.dev",
    "https://docker.1ms.run"'
DAEMON_JSON="/etc/docker/daemon.json"
BACKUP_FILE="/etc/docker/daemon.json.1panel_bak"

function create_daemon_json() {
    log "$TXT_CREATE_NEW_CONFIG ${DAEMON_JSON}..."
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": [
$ACCELERATOR_URLS
  ]
}
EOF
    log "$TXT_ACCELERATION_CONFIG_ADDED"
}

function configure_accelerator() {
    if [[ "$NON_INTERACTIVE" == true && -z "$CONFIG_CONFIGURE_ACCELERATOR" ]]; then
        log "$TXT_ACCELERATION_CONFIG_NOT"
        return
    fi

    while true; do
        ask_yn "$TXT_ACCELERATION_CONFIG_ADD" "y" "n" "$CONFIG_CONFIGURE_ACCELERATOR"
        accelerator_confirm="$ASK_YN_RESULT"
        case "$accelerator_confirm" in
            [yY])
                if ping -c 1 mirror.ccs.tencentyun.com &>/dev/null; then
                    ACCELERATOR_URLS='    "https://mirror.ccs.tencentyun.com"'
                    log "$TXT_USING_TENCENT_MIRROR"
                fi

                docker_needs_restart=false

                if [ -f "$DAEMON_JSON" ]; then
                    log "$TXT_DAEMON_CONFIG_EXISTS"
                    while true; do
                        ask_yn "$TXT_DAEMON_CONFIG_CONFIRM" "" "n" "$CONFIG_REPLACE_DAEMON_JSON"
                        daemon_confirm="$ASK_YN_RESULT"
                        case "$daemon_confirm" in
                            [yY])
                                cp "$DAEMON_JSON" "$BACKUP_FILE"
                                create_daemon_json
                                docker_needs_restart=true
                                break
                                ;;
                            [nN])
                                log "$TXT_ACCELERATION_CONFIG_NOT"
                                break
                                ;;
                            *)
                                log "$TXT_INVALID_YN_INPUT"
                                ;;
                        esac
                    done
                else
                    create_daemon_json
                    docker_needs_restart=true
                fi

                if [ "$docker_needs_restart" = true ]; then
                    log "$TXT_RESTARTING_DOCKER"
                    if command -v systemctl &>/dev/null; then
                        systemctl daemon-reload && systemctl restart docker
                    else
                        service dockerd restart
                        sleep 1
                    fi
                    log "$TXT_DOCKER_RESTARTED"
                fi

                break
                ;;
            [nN])
                log "$TXT_ACCELERATION_CONFIG_NOT"
                break
                ;;
            *)
                log "$TXT_INVALID_YN_INPUT"
                ;;
        esac
    done
}

function Install_Iptables_Offline() {
    command -v iptables >/dev/null 2>&1 && return

    [ -f /etc/os-release ] || return
    . /etc/os-release

    [ "$ID" = "debian" ] || return

    case "${VERSION_ID%%.*}" in
        11|12|13)
            DEBIAN_VERSION_ID="${VERSION_ID%%.*}"
            ;;
        *)
            return
            ;;
    esac

    DEB_DIR="${CURRENT_DIR}/iptables-deb/debian${DEBIAN_VERSION_ID}"

    [ -d "$DEB_DIR" ] || return

    log "$TXT_IPTABLES_INSTALL_OFFLINE Debian ${DEBIAN_VERSION_ID}"

    dpkg -i "$DEB_DIR"/*.deb >/dev/null 2>&1 || true
    apt-get -f install -y >/dev/null 2>&1 || true
}

function Install_Docker_Offline() {
    local docker_dir="${CURRENT_DIR}/docker"

    log "$TXT_DOCKER_INSTALL_OFFLINE"

    if [[ ! -d "${docker_dir}/bin" || ! -f "${docker_dir}/service/docker.service" || ! -f "${docker_dir}/conf/daemon.json" ]]; then
        log "$TXT_DOCKER_INSTALL_FAIL"
        exit 1
    fi

    if ! command -v systemctl &>/dev/null; then
        log "$TXT_DOCKER_INSTALL_FAIL"
        exit 1
    fi

    Install_Iptables_Offline

    chmod +x "${docker_dir}"/bin/*
    cp "${docker_dir}"/bin/* /usr/bin/
    cp "${docker_dir}"/service/docker.service /etc/systemd/system/
    chmod 754 /etc/systemd/system/docker.service
    mkdir -p /etc/docker/
    cp "${docker_dir}"/conf/daemon.json /etc/docker/daemon.json

    systemctl enable docker 2>&1 | tee -a ${LOG_FILE}
    systemctl daemon-reload 2>&1 | tee -a ${LOG_FILE}
    systemctl start docker 2>&1 | tee -a ${LOG_FILE}

    docker version >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        log "$TXT_DOCKER_INSTALL_FAIL"
        exit 1
    else
        log "$TXT_DOCKER_INSTALL_SUCCESS"
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
            if [[ "$NON_INTERACTIVE" == true && -n "$CONFIG_CONFIGURE_ACCELERATOR" ]]; then
                configure_accelerator
            fi
        else
            if [[ $major_version -lt 20 ]]; then
                log "$TXT_LOW_DOCKER_VERSION"
            fi

            if [[ "$NON_INTERACTIVE" == true ]]; then
                if [[ -n "$CONFIG_CONFIGURE_ACCELERATOR" ]]; then
                    configure_accelerator
                fi
            elif [[ $(curl -s ipinfo.io/country) == "CN" ]]; then
                configure_accelerator
            fi
        fi
    else
        local docker_mode="auto"
        local docker_mode_configured=false
        if [[ -n "$CONFIG_DOCKER_MODE" ]]; then
            docker_mode_configured=true
        fi
        if ! docker_mode=$(normalize_docker_mode "$CONFIG_DOCKER_MODE"); then
            log "$TXT_INVALID_YN_INPUT"
            exit 1
        fi
        while true; do
            ask_yn "$TXT_INSTALL_DOCKER_CONFIRM" "y" "n" "$CONFIG_INSTALL_DOCKER"
            install_docker_choice="$ASK_YN_RESULT"
            case "$install_docker_choice" in
                [yY])
                    if [[ -d "${CURRENT_DIR}/docker" ]]; then
                        case "$docker_mode" in
                            builtin)
                                Install_Docker_Offline
                                break
                                ;;
                            online)
                                ;;
                            auto)
                                if [[ "$NON_INTERACTIVE" == true || "$docker_mode_configured" == true ]]; then
                                    Install_Docker_Offline
                                    break
                                fi
                                while true; do
                                    ask_yn "$TXT_USE_BUILTIN_DOCKER_CONFIRM" "y" "y" ""
                                    use_builtin_docker_choice="$ASK_YN_RESULT"
                                    case "$use_builtin_docker_choice" in
                                        [yY])
                                            Install_Docker_Offline
                                            break 2
                                            ;;
                                        [nN])
                                            break
                                            ;;
                                    esac
                                done
                                ;;
                        esac
                    elif [[ "$docker_mode" == "builtin" ]]; then
                        log "$TXT_DOCKER_INSTALL_FAIL"
                        exit 1
                    fi

                    log "$TXT_DOCKER_INSTALL_ONLINE"

                    if  command -v opkg &>/dev/null;then
                        log "$TXT_DOCKER_INSTALL_ONLINE"
                        opkg update
                        opkg install luci-i18n-dockerman-zh-cn
                        opkg install zoneinfo-asia
                        service system restart
                        if [[ $(curl -s ipinfo.io/country) == "CN" ]]; then
                            configure_accelerator
                        fi
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
                            if command -v systemctl &>/dev/null; then
                                systemctl enable docker; systemctl daemon-reload; systemctl start docker 2>&1 | tee -a ${LOG_FILE}
                            else
                                service dockerd start 2>&1 | tee -a ${LOG_FILE}
                                sleep 1
                            fi

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
                            fi
                        fi
                    fi

                    break
                    ;;
                [nN])
                    echo "$TXT_CANCEL_INSTALL_DOCKER"
                    break
                    ;;
                *)
                    log "$TXT_INVALID_YN_INPUT"
                    continue
                    ;;
            esac
        done
    fi
}

function Set_Port(){
    local port_retry_count=0
    DEFAULT_PORT=$(expr $RANDOM % 55535 + 10000)

    while true; do
        if [[ -n "$CONFIG_PORT" ]]; then
            PANEL_PORT="$CONFIG_PORT"
        elif [[ "$NON_INTERACTIVE" == true ]]; then
            PANEL_PORT="$DEFAULT_PORT"
        else
            read -p "$TXT_SET_PANEL_PORT $DEFAULT_PORT): " PANEL_PORT

            if [[ "$PANEL_PORT" == "" ]];then
                PANEL_PORT=$DEFAULT_PORT
            fi
        fi

        if ! validate_panel_port "$PANEL_PORT"; then
            log "$TXT_INPUT_PORT_NUMBER"
            if [[ -n "$CONFIG_PORT" || "$NON_INTERACTIVE" == true ]]; then
                exit 1
            fi
            continue
        fi

        if panel_port_occupied "$PANEL_PORT"; then
            log "$TXT_PORT_OCCUPIED $PANEL_PORT"
            if [[ -n "$CONFIG_PORT" ]]; then
                exit 1
            fi
            if [[ "$NON_INTERACTIVE" == true ]]; then
                port_retry_count=$((port_retry_count + 1))
                if [[ "$port_retry_count" -ge 10 ]]; then
                    exit 1
                fi
                DEFAULT_PORT=$(expr $RANDOM % 55535 + 10000)
                continue
            fi
            continue
        fi

        log "$TXT_THE_PORT_U_SET $PANEL_PORT"
        break
    done
}

function Set_Firewall(){
    if which firewall-cmd >/dev/null 2>&1; then
       if [[ $(if service firewalld status >/dev/null 2>&1; then echo 'active'; else echo 'inactive'; fi) == 'active' ]]; then
            log "$TXT_FIREWALL_OPEN_PORT $PANEL_PORT"
            firewall-cmd --zone=public --add-port="$PANEL_PORT"/tcp --permanent
            firewall-cmd --reload
        elif [[ $(if service firewalld start >/dev/null 2>&1; then echo 'Success'; else echo 'Faild'; fi) == 'Success' ]]; then
            log "$TXT_FIREWALL_OPEN_PORT $PANEL_PORT"
            firewall-cmd --zone=public --add-port="$PANEL_PORT"/tcp --permanent
            firewall-cmd --reload
        else
            log "$TXT_FIREWALL_NOT_ACTIVE_SKIP"
        fi
    fi

    if which ufw >/dev/null 2>&1; then
        if [[ $(if service ufw status >/dev/null 2>&1; then echo 'active'; else echo 'inactive'; fi) == 'active' ]]; then
            log "$TXT_FIREWALL_OPEN_PORT $PANEL_PORT"
            ufw allow "$PANEL_PORT"/tcp
            ufw reload
        elif [[ $(if service ufw start >/dev/null 2>&1; then echo  'Success'; else echo 'Faild'; fi) == 'Success'  ]]; then
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
        if [[ -n "$CONFIG_ENTRANCE" ]]; then
            PANEL_ENTRANCE="$CONFIG_ENTRANCE"
        elif [[ "$NON_INTERACTIVE" == true ]]; then
            PANEL_ENTRANCE="$DEFAULT_ENTRANCE"
        else
            read -p "$TXT_SET_PANEL_ENTRANCE $DEFAULT_ENTRANCE): " PANEL_ENTRANCE
            if [[ "$PANEL_ENTRANCE" == "" ]]; then
                PANEL_ENTRANCE=$DEFAULT_ENTRANCE
            fi
        fi

        if ! validate_panel_entrance "$PANEL_ENTRANCE"; then
            log "$TXT_INPUT_ENTRANCE_RULE"
            if [[ -n "$CONFIG_ENTRANCE" || "$NON_INTERACTIVE" == true ]]; then
                exit 1
            fi
            continue
        fi
    
        log "$TXT_YOUR_PANEL_ENTRANCE $PANEL_ENTRANCE"
        break
    done
}

function Set_Username(){
    DEFAULT_USERNAME=$(cat /dev/urandom | head -n 16 | md5sum | head -c 10)

    while true; do
        if [[ -n "$CONFIG_USERNAME" ]]; then
            PANEL_USERNAME="$CONFIG_USERNAME"
        elif [[ "$NON_INTERACTIVE" == true ]]; then
            PANEL_USERNAME="$DEFAULT_USERNAME"
        else
            read -p "$TXT_SET_PANEL_USER $DEFAULT_USERNAME): " PANEL_USERNAME

            if [[ "$PANEL_USERNAME" == "" ]];then
                PANEL_USERNAME=$DEFAULT_USERNAME
            fi
        fi

        if ! validate_panel_username "$PANEL_USERNAME"; then
            log "$TXT_INPUT_USERNAME_RULE"
            if [[ -n "$CONFIG_USERNAME" || "$NON_INTERACTIVE" == true ]]; then
                exit 1
            fi
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
            if [ -z "$char" ]; then
                break
            fi
            case $char in
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
        if [[ -n "$CONFIG_PASSWORD" ]]; then
            PANEL_PASSWORD="$CONFIG_PASSWORD"
        elif [[ "$NON_INTERACTIVE" == true ]]; then
            PANEL_PASSWORD="$DEFAULT_PASSWORD"
        else
            passwd
            PANEL_PASSWORD=$reply
            if [[ "$PANEL_PASSWORD" == "" ]];then
                PANEL_PASSWORD=$DEFAULT_PASSWORD
            fi
        fi

        if ! validate_panel_password "$PANEL_PASSWORD"; then
            log "$TXT_INPUT_PASSWORD_RULE"
            if [[ -n "$CONFIG_PASSWORD" || "$NON_INTERACTIVE" == true ]]; then
                exit 1
            fi
            continue
        fi

        break
    done
}

init_configure() {
    cp ./1panel-core /usr/local/bin && chmod +x /usr/local/bin/1panel-core
    if [[ -e /usr/bin/1panel ]]; then
        rm -f /usr/bin/1panel
    fi
    ln -s /usr/local/bin/1panel-core /usr/bin/1panel >/dev/null 2>&1
    if [[ ! -f /usr/bin/1panel-core ]]; then
        ln -s /usr/local/bin/1panel-core /usr/bin/1panel-core >/dev/null 2>&1
    fi

    cp ./1panel-agent /usr/local/bin && chmod +x /usr/local/bin/1panel-agent
    if [[ ! -f /usr/bin/1panel-agent ]]; then
        ln -s /usr/local/bin/1panel-agent /usr/bin/1panel-agent >/dev/null 2>&1
    fi

    cp ./1pctl /usr/local/bin && chmod +x /usr/local/bin/1pctl
    ESCAPED_PANEL_BASE_DIR=$(escape_sed_replacement "$PANEL_BASE_DIR")
    ESCAPED_PANEL_PORT=$(escape_sed_replacement "$PANEL_PORT")
    ESCAPED_PANEL_USERNAME=$(escape_sed_replacement "$PANEL_USERNAME")
    ESCAPED_PANEL_PASSWORD=$(escape_sed_replacement "$PANEL_PASSWORD")
    ESCAPED_PANEL_ENTRANCE=$(escape_sed_replacement "$PANEL_ENTRANCE")
    ESCAPED_SELECTED_LANG=$(escape_sed_replacement "$selected_lang")
    ESCAPED_SELECTED_EDITION=$(escape_sed_replacement "$selected_edition")
    sed -i -e "s#BASE_DIR=.*#BASE_DIR=${ESCAPED_PANEL_BASE_DIR}#g" /usr/local/bin/1pctl
    sed -i -e "s#ORIGINAL_PORT=.*#ORIGINAL_PORT=${ESCAPED_PANEL_PORT}#g" /usr/local/bin/1pctl
    sed -i -e "s#ORIGINAL_USERNAME=.*#ORIGINAL_USERNAME=${ESCAPED_PANEL_USERNAME}#g" /usr/local/bin/1pctl
    sed -i -e "s#ORIGINAL_PASSWORD=.*#ORIGINAL_PASSWORD=${ESCAPED_PANEL_PASSWORD}#g" /usr/local/bin/1pctl
    sed -i -e "s#ORIGINAL_ENTRANCE=.*#ORIGINAL_ENTRANCE=${ESCAPED_PANEL_ENTRANCE}#g" /usr/local/bin/1pctl
    sed -i -e "s#LANGUAGE=.*#LANGUAGE=${ESCAPED_SELECTED_LANG}#g" /usr/local/bin/1pctl
    sed -i -e "s#^PANEL_EDITION=.*#PANEL_EDITION=${ESCAPED_SELECTED_EDITION}#g" /usr/local/bin/1pctl
    if [[ "$USE_EXISTING" == true ]]; then
        if grep -q "^CHANGE_USER_INFO=" "/usr/local/bin/1pctl"; then
            sed -i 's/^CHANGE_USER_INFO=.*/CHANGE_USER_INFO=use_existing/' "/usr/local/bin/1pctl"
        else
            sed -i '/^LANGUAGE=.*/a CHANGE_USER_INFO=use_existing' "/usr/local/bin/1pctl"
        fi
    fi
    if [[ ! -f /usr/bin/1pctl ]]; then
        ln -s /usr/local/bin/1pctl /usr/bin/1pctl >/dev/null 2>&1
    fi

    if [ -d "$RUN_BASE_DIR/geo" ]; then
        rm -rf "$RUN_BASE_DIR/geo"
    fi
    mkdir $RUN_BASE_DIR/geo
    cp -r ./GeoIP.mmdb $RUN_BASE_DIR/geo/

    cp -r ./lang /usr/local/bin
}

install_and_configure() {
    if command -v systemctl &>/dev/null; then
        init_configure
        cp ./initscript/1panel-core.service /etc/systemd/system
        cp ./initscript/1panel-agent.service /etc/systemd/system
        systemctl enable 1panel-agent.service; systemctl enable 1panel-core.service; systemctl daemon-reload 2>&1 | tee -a ${LOG_FILE}
        log "$TXT_START_PANEL_SERVICE"
        systemctl start 1panel-core | tee -a ${LOG_FILE}
        systemctl start 1panel-agent | tee -a ${LOG_FILE}
    else
     	mkdir -p /usr/local/bin
	    init_configure
        if [ -f /etc/rc.common ]; then
            cp ./initscript/1panel-core.procd /etc/init.d/1panel-core
            cp ./initscript/1panel-agent.procd /etc/init.d/1panel-agent
            chmod +x /etc/init.d/1panel-core
            chmod +x /etc/init.d/1panel-agent
            /etc/init.d/1panel-core enable | tee -a ${LOG_FILE}
            /etc/init.d/1panel-agent enable | tee -a ${LOG_FILE}
        elif [ -f /sbin/openrc-run ]; then
            cp ./initscript/1panel-core.openrc /etc/init.d/1panel-core
            cp ./initscript/1panel-agent.openrc /etc/init.d/1panel-agent
            chmod +x /etc/init.d/1panel-core
            chmod +x /etc/init.d/1panel-agent
            rc-update add 1panel-core default 2>&1 | tee -a ${LOG_FILE}
            rc-update add 1panel-agent default 2>&1 | tee -a ${LOG_FILE}
        else
            cp ./initscript/1panel-core.init /etc/init.d/1panel-core
            cp ./initscript/1panel-agent.init /etc/init.d/1panel-agent
            chmod +x /etc/init.d/1panel-core
            chmod +x /etc/init.d/1panel-agent
            /etc/init.d/1panel-core enable | tee -a ${LOG_FILE}
            /etc/init.d/1panel-agent enable | tee -a ${LOG_FILE}
        fi
        /etc/init.d/1panel-core start | tee -a ${LOG_FILE}
        /etc/init.d/1panel-agent start | tee -a ${LOG_FILE}
    fi
}

function Init_Panel(){
    log "$TXT_CONFIGURE_PANEL_SERVICE"
    MAX_ATTEMPTS=5
    RUN_BASE_DIR=$PANEL_BASE_DIR/1panel
    mkdir -p "$RUN_BASE_DIR"
    if [[ "$USE_EXISTING" == false ]]; then
        rm -rf $RUN_BASE_DIR/* 2>/dev/null
    fi

    cd "${CURRENT_DIR}" || exit

    install_and_configure

    for attempt in $(seq 1 $MAX_ATTEMPTS); do
        if command -v systemctl >/dev/null 2>&1; then
            core_status=$(systemctl status 1panel-core 2>&1 | grep Active)
            agent_status=$(systemctl status 1panel-agent 2>&1 | grep Active)
            if [[ "$core_status" == *running* && "$agent_status" == *running* ]]; then
                log "$TXT_PANEL_SERVICE_START_SUCCESS"
                break
            fi
        elif command -v opkg >/dev/null 2>&1; then
            core_status=$(/etc/init.d/1panel-core status 2>&1)
            agent_status=$(/etc/init.d/1panel-agent status 2>&1)
            if [[ "$core_status" == *running* && "$agent_status" == *running* ]]; then
                log "$TXT_PANEL_SERVICE_START_SUCCESS"
                break
            fi
        else
            core_status=$(service 1panel-core status >/dev/null 2>&1 && echo active || echo inactive)
            agent_status=$(service 1panel-agent status >/dev/null 2>&1 && echo active || echo inactive)
            if [[ "$core_status" == "active" && "$agent_status" == "active" ]]; then
                log "$TXT_PANEL_SERVICE_START_SUCCESS"
                break
            fi
        fi

        if [ $attempt -eq $MAX_ATTEMPTS ]; then
            log "$TXT_PANEL_SERVICE_START_ERROR"
            exit 1
        else
            log $TXT_SERVICE_RETRY_MSG $((MAX_ATTEMPTS - attempt))
            sleep 2
        fi
    done
    if [[ ! -d "$RUN_BASE_DIR/resource" ]]; then
        mkdir -p "$RUN_BASE_DIR/resource"
    fi
    cp -r ./initscript "$RUN_BASE_DIR/resource/"
}

function Get_Ip(){
    active_interface=$(ip route get 8.8.8.8 | awk 'NR==1 {print $5}')
    PUBLIC_IP=$(curl -s https://api64.ipify.org)
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

function Check_Ready() {
    i=0

    while [ $i -lt 30 ]; do
        if command -v ss >/dev/null 2>&1; then
            ss -tlun | grep -q ":$PANEL_PORT " && break
        elif command -v netstat >/dev/null 2>&1; then
            netstat -tlun | grep -q ":$PANEL_PORT " && break
        else
            break
        fi

        sleep 2
        i=$((i + 1))
    done

    if [ ! -e /etc/1panel/agent.sock ]; then
        /usr/local/bin/1pctl restart >/dev/null 2>&1
    fi

    if [[ "$USE_EXISTING" == false ]]; then
        sed -i -e "s#ORIGINAL_PASSWORD=.*#ORIGINAL_PASSWORD=${PASSWORD_MASK}#g" /usr/local/bin/1pctl
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
}

function main(){
    Check_Root
    Prepare_System
    Set_Dir
    Install_Docker
    Set_Port
    Set_Firewall
    Set_Entrance
    Set_Username
    Set_Password
    Init_Panel
    Get_Ip
    Check_Ready
    Show_Result
}
main
