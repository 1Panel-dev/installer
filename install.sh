#!/bin/bash

CURRENT_DIR=$(
    cd "$(dirname "$0")"
    pwd
)

LOG_FILE=${CURRENT_DIR}/install.log
PASSWORD_MASK="**********"

function log() {
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    message="[1Panel ${timestamp} install Log]: $1 "
    echo -e "\033[32m ${message}\033[0m" 2>&1 | tee -a ${LOG_FILE}
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
    echo "请使用 root 或 sudo 权限运行此脚本"
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
                mkdir -p $PANEL_BASE_DIR
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

function Install_Docker(){
    if which docker >/dev/null 2>&1; then
        log "检测到 Docker 已安装，跳过安装步骤"
        log "启动 Docker "
        if [[ $(which busybox &>/dev/null && service dockerd start && service dockerd status 2>&1 || systemctl start docker && systemctl status docker 2>&1) == *running* ]]; then
            log "Docker 服务启动成功!"

        else
            log "Docker 服务启动失败，安装完成后，请尝试手动启动Docker！"

        fi
    else
        log "... 在线安装 docker"
        if  command -v opkg &>/dev/null;then
            log "... 当前为busybox环境，尝试使用 opkg 安装 docker"
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

                get_average_delay() {
                    local source=$1
                    local total_delay=0
                    local iterations=3

                    for ((i = 0; i < iterations; i++)); do
                        delay=$(curl -o /dev/null -s -w "%{time_total}\n" "$source")
                        total_delay=$(awk "BEGIN {print $total_delay + $delay}")
                    done

                    average_delay=$(awk "BEGIN {print $total_delay / $iterations}")
                    echo "$average_delay"
                }

                min_delay=${#sources[@]}
                selected_source=""

                for source in "${sources[@]}"; do
                    average_delay=$(get_average_delay "$source")

                    if (( $(awk 'BEGIN { print '"$average_delay"' < '"$min_delay"' }') )); then
                        min_delay=$average_delay
                        selected_source=$source
                    fi
                done

                if [ -n "$selected_source" ]; then
                    echo "选择延迟最低的源 $selected_source，延迟为 $min_delay 秒"
                    export DOWNLOAD_URL="$selected_source"
                    curl -fsSL "https://get.docker.com" -o get-docker.sh
                    sh get-docker.sh 2>&1 | tee -a ${LOG_FILE}

                    log "... 启动 docker"
                    systemctl enable docker; systemctl daemon-reload; systemctl start docker 2>&1 | tee -a ${LOG_FILE}

                    docker_config_folder="/etc/docker"
                    if [[ ! -d "$docker_config_folder" ]];then
                        mkdir -p "$docker_config_folder"
                    fi

                else
                    log "无法选择源进行安装"
                    exit 1
                fi
            else
                log "非中国大陆地区，无需更改源"
                export DOWNLOAD_URL="https://download.docker.com"
                curl -fsSL "https://get.docker.com" -o get-docker.sh
                sh get-docker.sh 2>&1 | tee -a ${LOG_FILE}

                log "... 启动 docker"
                systemctl enable docker; systemctl daemon-reload; systemctl start docker 2>&1 | tee -a ${LOG_FILE}

                docker_config_folder="/etc/docker"
                if [[ ! -d "$docker_config_folder" ]];then
                    mkdir -p "$docker_config_folder"
                fi
            fi
        fi

        docker version >/dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            log "docker 安装失败"
            exit 1
        else
            log "docker 安装成功"
                
        fi
    fi
}

function Install_Compose(){
    docker-compose version >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        log "... 在线安装 docker-compose"
        if which opkg &>/dev/null;then
            log "... 当前环境为busybox，尝试使用 opkg 安装 docker-compose"
            opkg update || log "软件包更新失败，请检查网络或稍后重试"
            opkg install docker-compose
        else
            arch=$(uname -m)
            if [ "$arch" == 'armv7l' ]; then
                arch='armv7'
            fi
            curl -L https://resource.fit2cloud.com/docker/compose/releases/download/v2.26.1/docker-compose-$(uname -s | tr A-Z a-z)-$arch -o /usr/local/bin/docker-compose 2>&1 | tee -a ${LOG_FILE}
            if [[ ! -f /usr/local/bin/docker-compose ]];then
                log "docker-compose 下载失败，请稍候重试"
                exit 1
            fi
            chmod +x /usr/local/bin/docker-compose
            ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
        fi

        docker-compose version >/dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            log "docker-compose 安装失败"
            exit 1
        else
            log "docker-compose 安装成功"
        fi
    else
        compose_v=`docker-compose -v`
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
    DEFAULT_PORT=`expr $RANDOM % 55535 + 10000`

    while true; do
        read -p "设置 1Panel 端口（默认为$DEFAULT_PORT）：" PANEL_PORT

        if [[ "$PANEL_PORT" == "" ]];then
            PANEL_PORT=$DEFAULT_PORT
        fi

        if ! [[ "$PANEL_PORT" =~ ^[1-9][0-9]{0,4}$ && "$PANEL_PORT" -le 65535 ]]; then
            echo "错误：输入的端口号必须在 1 到 65535 之间"
            continue
        fi

 	if command -v lsof >/dev/null 2>&1; then 
	    if lsof -i:$PANEL_PORT >/dev/null 2>&1; then
 		echo "端口$PANEL_PORT被占用，请重新输入..."
   		continue
 	    fi
        elif command -v ss >/dev/null 2>&1; then
	    if ss -tlun | grep -q ":$PANEL_PORT " >/dev/null 2>&1; then
     		echo "端口$PANEL_PORT被占用，请重新输入..."
       		continue
     	    fi
	elif command -v netstat >/dev/null 2>&1; then
	    if netstat -tlun | grep -q ":$PANEL_PORT " >/dev/null 2>&1; then
	    	echo "端口$PANEL_PORT被占用，请重新输入..."
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
            firewall-cmd --zone=public --add-port=$PANEL_PORT/tcp --permanent
            firewall-cmd --reload
        else
            log "防火墙未开启，忽略端口开放"
        fi
    fi

    if which ufw >/dev/null 2>&1; then
        if systemctl status ufw | grep -q "Active: active" >/dev/null 2>&1;then
            log "防火墙开放 $PANEL_PORT 端口"
            ufw allow $PANEL_PORT/tcp
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
            echo "错误：面板安全入口仅支持字母、数字、下划线，长度 3-30 位"
            continue
    	fi
    
        log "您设置的面板安全入口为：$PANEL_ENTRANCE"
    	break
    done
}

function Set_Username(){
    DEFAULT_USERNAME=`cat /dev/urandom | head -n 16 | md5sum | head -c 10`

    while true; do
        read -p "设置 1Panel 面板用户（默认为$DEFAULT_USERNAME）：" PANEL_USERNAME

        if [[ "$PANEL_USERNAME" == "" ]];then
            PANEL_USERNAME=$DEFAULT_USERNAME
        fi

        if [[ ! "$PANEL_USERNAME" =~ ^[a-zA-Z0-9_]{3,30}$ ]]; then
            echo "错误：面板用户仅支持字母、数字、下划线，长度 3-30 位"
            continue
        fi

        log "您设置的面板用户为：$PANEL_USERNAME"
        break
    done
}

function Set_Password(){
    DEFAULT_PASSWORD=`cat /dev/urandom | head -n 16 | md5sum | head -c 10`

    while true; do
        echo "设置 1Panel 面板密码（默认为$DEFAULT_PASSWORD）："
        read -s PANEL_PASSWORD

        if [[ "$PANEL_PASSWORD" == "" ]];then
            PANEL_PASSWORD=$DEFAULT_PASSWORD
        fi

        if [[ ! "$PANEL_PASSWORD" =~ ^[a-zA-Z0-9_!@#$%*,.?]{8,30}$ ]]; then
            echo "错误：面板密码仅支持字母、数字、特殊字符（!@#$%*_,.?），长度 8-30 位"
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
    }
install_and_configure() {
    if which busybox &>/dev/null; then
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
" > /etc/init.d/1panel
        # curl -sSL https://raw.githubusercontent.com/gcsong023/wrt_installer/wrt_1panel/etc/init.d/1panel -o /etc/init.d/1panel
        chmod +x /etc/init.d/1panel
        /etc/init.d/1panel enable && /etc/init.d/1panel reload 2>&1 | tee -a ${LOG_FILE}
        /etc/init.d/1panel start | tee -a ${LOG_FILE}
    else
    	init_configure
        cp ./1panel.service /etc/systemd/system
        systemctl enable 1panel.service; systemctl daemon-reload 2>&1 | tee -a ${LOG_FILE}
        systemctl start 1panel.service | tee -a ${LOG_FILE}
    fi
}

function Init_Panel(){
    log "配置 1Panel Service"
    MAX_ATTEMPTS=5
    RUN_BASE_DIR=$PANEL_BASE_DIR/1panel
    mkdir -p $RUN_BASE_DIR
    rm -rf $RUN_BASE_DIR/* 2>/dev/null

    cd ${CURRENT_DIR}

    install_and_configure

    for attempt in $(seq 1 $MAX_ATTEMPTS); do
        if [[ $(command -v busybox) && $(/etc/init.d/1panel status 2>&1) == *running* ]] || \
        [[ $(command -v systemctl) && $(systemctl status 1panel 2>&1) =~ Active.*running ]]; then
            log "1Panel 服务启动成功!"
            break
        else
            if [ $attempt -eq $MAX_ATTEMPTS ]; then
                log "1Panel 服务启动出错! 尝试次数已达上限。"
                exit 1
            else
                log "1Panel 服务尚未启动，将在 $((MAX_ATTEMPTS - attempt)) 秒后重试。"
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
        if which busybox &>/dev/null;then
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
    log "=================感谢您的耐心等待，安装已经完成=================="
    log ""
    log "请用浏览器访问面板:"
    log "外网地址: http://$PUBLIC_IP:$PANEL_PORT/$PANEL_ENTRANCE"
    log "内网地址: http://$LOCAL_IP:$PANEL_PORT/$PANEL_ENTRANCE"
    log "面板用户: $PANEL_USERNAME"
    log "面板密码: $PANEL_PASSWORD"
    log "密码仅显示一次，如遗忘请使用 1pctl update password 重置！"
    log "项目官网: https://1panel.cn"
    log "项目文档: https://1panel.cn/docs"
    log "代码仓库: https://github.com/1Panel-dev/1Panel"
    log ""
    log "如果使用的是云服务器，请至安全组开放 $PANEL_PORT 端口"
    log ""
    log "================================================================"
    sed -i -e "s#面板密码:.*#面板密码:${PASSWORD_MASK}#g" ${LOG_FILE}
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
