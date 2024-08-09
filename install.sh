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

function log() {
    message="[1Panel Log]: $1 "
    case "$1" in
        *"失败"*|*"错误"*|*"请使用 root 或 sudo 权限运行此脚本"*)
            echo -e "${RED}${message}${NC}" 2>&1 | tee -a "${CURRENT_DIR}"/install.log
            ;;
        *"成功"*)
            echo -e "${GREEN}${message}${NC}" 2>&1 | tee -a "${CURRENT_DIR}"/install.log
            ;;
        *"忽略"*|*"跳过"*)
            echo -e "${YELLOW}${message}${NC}" 2>&1 | tee -a "${CURRENT_DIR}"/install.log
            ;;
        *)
            echo -e "${BLUE}${message}${NC}" 2>&1 | tee -a "${CURRENT_DIR}"/install.log
            ;;
    esac
}
echo
cat << EOF
 ██╗    ██████╗  █████╗ ███╗   ██╗███████╗██╗     
███║    ██╔══██╗██╔══██╗████╗  ██║██╔════╝██║     
╚██║    ██████╔╝███████║██╔██╗ ██║█████╗  ██║     
 ██║    ██╔═══╝ ██╔══██║██║╚██╗██║██╔══╝  ██║     
 ██║    ██║     ██║  ██║██║ ╚████║███████╗███████╗
 ╚═╝    ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝
EOF

log "======================= 开始安装 ======================="

function Check_Root() {
    if [[ $EUID -ne 0 ]]; then
        log "请使用 root 或 sudo 权限运行此脚本"
        exit 1
    fi
}

function Prepare_System(){
    if which 1panel >/dev/null 2>&1; then
        log "1Panel Linux 服务器运维管理面板已安装，请勿重复安装"
        exit 1
    fi
}

function Set_Dir(){
    if read -t 120 -p "设置 1Panel 安装目录（默认为/opt）：" PANEL_BASE_DIR;then
        if [[ "$PANEL_BASE_DIR" != "" ]];then
            if [[ "$PANEL_BASE_DIR" != /* ]];then
                log "请输入目录的完整路径"
                Set_Dir
            fi

            if [[ ! -d $PANEL_BASE_DIR ]];then
                mkdir -p "$PANEL_BASE_DIR"
                log "您选择的安装路径为 $PANEL_BASE_DIR"
            fi
        else
            PANEL_BASE_DIR=/opt
            log "您选择的安装路径为 $PANEL_BASE_DIR"
        fi
    else
        PANEL_BASE_DIR=/opt
        log "(设置超时，使用默认安装路径 /opt)"
    fi
}

ACCELERATOR_URL="https://docker.1panel.live"
DAEMON_JSON="/etc/docker/daemon.json"
BACKUP_FILE="/etc/docker/daemon.json.1panel_bak"

function create_daemon_json() {
    log "创建新的配置文件 ${DAEMON_JSON}..."
    mkdir -p /etc/docker
    echo '{
        "registry-mirrors": ["'"$ACCELERATOR_URL"'"]
    }' | tee "$DAEMON_JSON" > /dev/null
    log "镜像加速配置已添加。"
}

function configure_accelerator() {
    read -p "是否配置镜像加速？(y/n): " configure_accelerator
    if [[ "$configure_accelerator" == "y" ]]; then
        if [ -f "$DAEMON_JSON" ]; then
            log "配置文件已存在，我们将备份现有配置文件为 ${BACKUP_FILE} 并创建新的配置文件。"
            cp "$DAEMON_JSON" "$BACKUP_FILE"
            create_daemon_json
        else
            create_daemon_json
        fi

        log "正在重启 Docker 服务..."
        systemctl daemon-reload
        systemctl restart docker
        log "Docker 服务已成功重启。"
    else
        log "未配置镜像加速。"
    fi
}

function Install_Docker(){
    if which docker >/dev/null 2>&1; then
        log "检测到 Docker 已安装，跳过安装步骤"
        configure_accelerator
    else
        log "... 在线安装 docker"

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
                log "选择延迟最低的源 $selected_source，延迟为 $min_delay 秒"
                export DOWNLOAD_URL="$selected_source"
                
                for alt_source in "${docker_install_scripts[@]}"; do
                    log "尝试从备选链接 $alt_source 下载 Docker 安装脚本..."
                    if curl -fsSL --retry 2 --retry-delay 3 --connect-timeout 5 --max-time 10 "$alt_source" -o get-docker.sh; then
                        log "成功从 $alt_source 下载安装脚本"
                        break
                    else
                        log "从 $alt_source 下载安装脚本失败，尝试下一个备选链接"
                    fi
                done
                
                if [ ! -f "get-docker.sh" ]; then
                    log "所有下载尝试都失败了。您可以尝试手动安装 Docker，运行以下命令："
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
                    log "docker 安装失败\n您可以尝试使用离线包进行安装，具体安装步骤请参考以下链接：https://1panel.cn/docs/installation/package_installation/"
                    exit 1
                else
                    log "docker 安装成功"
                    systemctl enable docker 2>&1 | tee -a "${CURRENT_DIR}"/install.log
                    configure_accelerator
                fi
            else
                log "无法选择源进行安装"
                exit 1
            fi
        else
            log "非中国大陆地区，无需更改源"
            export DOWNLOAD_URL="https://download.docker.com"
            curl -fsSL "https://get.docker.com" -o get-docker.sh
            sh get-docker.sh 2>&1 | tee -a "${CURRENT_DIR}"/install.log

            log "... 启动 docker"
            systemctl enable docker; systemctl daemon-reload; systemctl start docker 2>&1 | tee -a "${CURRENT_DIR}"/install.log

            docker_config_folder="/etc/docker"
            if [[ ! -d "$docker_config_folder" ]];then
                mkdir -p "$docker_config_folder"
            fi

            docker version >/dev/null 2>&1
            if [[ $? -ne 0 ]]; then
                log "docker 安装失败\n您可以尝试使用安装包进行安装，具体安装步骤请参考以下链接：https://1panel.cn/docs/installation/package_installation/"
                exit 1
            else
                log "docker 安装成功"
            fi
        fi
    fi
}

function Install_Compose(){
    docker-compose version >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        log "... 在线安装 docker-compose"
        
        arch=$(uname -m)
		if [ "$arch" == 'armv7l' ]; then
			arch='armv7'
		fi
		curl -L https://resource.fit2cloud.com/docker/compose/releases/download/v2.26.1/docker-compose-$(uname -s | tr A-Z a-z)-"$arch" -o /usr/local/bin/docker-compose 2>&1 | tee -a "${CURRENT_DIR}"/install.log
        if [[ ! -f /usr/local/bin/docker-compose ]];then
            log "docker-compose 下载失败，请稍候重试"
            exit 1
        fi
        chmod +x /usr/local/bin/docker-compose
        ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

        docker-compose version >/dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            log "docker-compose 安装失败"
            exit 1
        else
            log "docker-compose 安装成功"
        fi
    else
        compose_v=$(docker-compose -v)
        if [[ $compose_v =~ 'docker-compose' ]];then
            read -p "检测到已安装 Docker Compose 版本较低（需大于等于 v2.0.0 版本），是否升级 [y/n] : " UPGRADE_DOCKER_COMPOSE
            if [[ "$UPGRADE_DOCKER_COMPOSE" == "Y" ]] || [[ "$UPGRADE_DOCKER_COMPOSE" == "y" ]]; then
                rm -rf /usr/local/bin/docker-compose /usr/bin/docker-compose
                Install_Compose
            else
                log "Docker Compose 版本为 $compose_v，可能会影响应用商店的正常使用"
            fi
        else
            log "检测到 Docker Compose 已安装，跳过安装步骤"
        fi
    fi
}

function Set_Port(){
    DEFAULT_PORT=$(expr $RANDOM % 55535 + 10000)

    while true; do
        read -p "设置 1Panel 端口（默认为$DEFAULT_PORT）：" PANEL_PORT

        if [[ "$PANEL_PORT" == "" ]];then
            PANEL_PORT=$DEFAULT_PORT
        fi

        if ! [[ "$PANEL_PORT" =~ ^[1-9][0-9]{0,4}$ && "$PANEL_PORT" -le 65535 ]]; then
            log "错误：输入的端口号必须在 1 到 65535 之间"
            continue
        fi

        if command -v ss >/dev/null 2>&1; then
            if ss -tlun | grep -q ":$PANEL_PORT " >/dev/null 2>&1; then
                log "端口$PANEL_PORT被占用，请重新输入..."
                continue
            fi
        elif command -v netstat >/dev/null 2>&1; then
            if netstat -tlun | grep -q ":$PANEL_PORT " >/dev/null 2>&1; then
                log "端口$PANEL_PORT被占用，请重新输入..."
                continue
            fi
        fi

        log "您设置的端口为：$PANEL_PORT"
        break
    done
}

function Set_Firewall(){
    if which firewall-cmd >/dev/null 2>&1; then
        if systemctl status firewalld | grep -q "Active: active" >/dev/null 2>&1;then
            log "防火墙开放 $PANEL_PORT 端口"
            firewall-cmd --zone=public --add-port="$PANEL_PORT"/tcp --permanent
            firewall-cmd --reload
        else
            log "防火墙未开启，忽略端口开放"
        fi
    fi

    if which ufw >/dev/null 2>&1; then
        if systemctl status ufw | grep -q "Active: active" >/dev/null 2>&1;then
            log "防火墙开放 $PANEL_PORT 端口"
            ufw allow "$PANEL_PORT"/tcp
            ufw reload
        else
            log "防火墙未开启，忽略端口开放"
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
            log "错误：面板安全入口仅支持字母、数字、下划线，长度 3-30 位"
            continue
    	fi
    
        log "您设置的面板安全入口为：$PANEL_ENTRANCE"
    	break
    done
}

function Set_Username(){
    DEFAULT_USERNAME=$(cat /dev/urandom | head -n 16 | md5sum | head -c 10)

    while true; do
        read -p "设置 1Panel 面板用户（默认为$DEFAULT_USERNAME）：" PANEL_USERNAME

        if [[ "$PANEL_USERNAME" == "" ]];then
            PANEL_USERNAME=$DEFAULT_USERNAME
        fi

        if [[ ! "$PANEL_USERNAME" =~ ^[a-zA-Z0-9_]{3,30}$ ]]; then
            log "错误：面板用户仅支持字母、数字、下划线，长度 3-30 位"
            continue
        fi

        log "您设置的面板用户为：$PANEL_USERNAME"
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
        log "设置 1Panel 面板密码，设置完成后直接回车以继续（默认为$DEFAULT_PASSWORD）："
        passwd
        PANEL_PASSWORD=$reply
        if [[ "$PANEL_PASSWORD" == "" ]];then
            PANEL_PASSWORD=$DEFAULT_PASSWORD
        fi

        if [[ ! "$PANEL_PASSWORD" =~ ^[a-zA-Z0-9_!@#$%*,.?]{8,30}$ ]]; then
            log "错误：面板密码仅支持字母、数字、特殊字符（!@#$%*_,.?），长度 8-30 位"
            continue
        fi

        break
    done
}

function Init_Panel(){
    log "配置 1Panel Service"

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

    log "启动 1Panel 服务"
    systemctl start 1panel | tee -a "${CURRENT_DIR}"/install.log

    for b in {1..30}
    do
        sleep 3
        service_status=$(systemctl status 1panel 2>&1 | grep Active)
        if [[ $service_status == *running* ]];then
            log "1Panel 服务启动成功!"
            break;
        else
            log "1Panel 服务启动出错!"
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
    log "=================感谢您的耐心等待，安装已经完成=================="
    log ""
    log "请用浏览器访问面板:"
    log "外网地址: http://$PUBLIC_IP:$PANEL_PORT/$PANEL_ENTRANCE"
    log "内网地址: http://$LOCAL_IP:$PANEL_PORT/$PANEL_ENTRANCE"
    log "面板用户: $PANEL_USERNAME"
    log "面板密码: $PANEL_PASSWORD"
    log ""
    log "项目官网: https://1panel.cn"
    log "项目文档: https://1panel.cn/docs"
    log "代码仓库: https://github.com/1Panel-dev/1Panel"
    log ""
    log "如果使用的是云服务器，请至安全组开放 $PANEL_PORT 端口"
    log ""
    log "为了您的服务器安全，在您离开此界面后您将无法再看到您的密码，请务必牢记您的密码。"
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
