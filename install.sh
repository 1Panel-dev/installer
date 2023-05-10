#!/bin/bash

CURRENT_DIR=$(
    cd "$(dirname "$0")"
    pwd
)

function log() {
    message="[1Panel Log]: $1 "
    echo -e "${message}" 2>&1 | tee -a ${CURRENT_DIR}/install.log
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

function Prepare_System(){
    is64bit=`getconf LONG_BIT`
    if [[ $is64bit != "64" ]]; then
        log "不支持 32 位系统安装 1Panel Linux 服务器运维管理面板，请更换 64 位系统安装"
        exit 1
    fi

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
        systemctl start docker 2>&1 | tee -a ${CURRENT_DIR}/install.log
    else
        log "... 在线安装 docker"

        curl -fsSL https://get.docker.com -o get-docker.sh 2>&1 | tee -a ${CURRENT_DIR}/install.log
        if [[ ! -f get-docker.sh ]];then
            log "docker 在线安装脚本下载失败，请稍候重试"
            exit 1
        fi
        if [[ $(curl -s ipinfo.io/country) == "CN" ]]; then
            sh get-docker.sh --mirror Aliyun 2>&1 | tee -a ${CURRENT_DIR}/install.log
        else
            sh get-docker.sh 2>&1 | tee -a ${CURRENT_DIR}/install.log
        fi
        
        log "... 启动 docker"
        systemctl enable docker; systemctl daemon-reload; systemctl start docker 2>&1 | tee -a ${CURRENT_DIR}/install.log

        docker_config_folder="/etc/docker"
        if [[ ! -d "$docker_config_folder" ]];then
            mkdir -p "$docker_config_folder"
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
        
        curl -L https://resource.fit2cloud.com/docker/compose/releases/download/v2.16.0/docker-compose-$(uname -s | tr A-Z a-z)-`uname -m` -o /usr/local/bin/docker-compose 2>&1 | tee -a ${CURRENT_DIR}/install.log
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

function Set_Username(){
    DEFAULT_USERNAME=`cat /dev/urandom | head -n 16 | md5sum | head -c 10`

    while true; do
        read -p "设置 1Panel 用户名称（默认为$DEFAULT_USERNAME）：" PANEL_USERNAME

        if [[ "$PANEL_USERNAME" == "" ]];then
            PANEL_USERNAME=$DEFAULT_USERNAME
        fi

        if [[ ! "$PANEL_USERNAME" =~ ^[a-zA-Z0-9_]{3,30}$ ]]; then
            echo "错误：用户名称仅支持字母、数字、下划线，长度 3-30 位"
            continue
        fi

        log "您设置的用户名称为：$PANEL_USERNAME"
        break
    done
}

function Set_Password(){
    DEFAULT_PASSWORD=`cat /dev/urandom | head -n 16 | md5sum | head -c 10`

    while true; do
        echo "设置 1Panel 用户密码（默认为$DEFAULT_PASSWORD）："
        read -s PANEL_PASSWORD

        if [[ "$PANEL_PASSWORD" == "" ]];then
            PANEL_PASSWORD=$DEFAULT_PASSWORD
        fi

        if [[ ! "$PANEL_PASSWORD" =~ ^[a-zA-Z0-9_!@#$%\&*,.?]{8,30}$ ]]; then
            echo "错误：用户密码仅支持字母、数字、特殊字符（!@#$%&*_,.?），长度 8-30 位"
            continue
        fi

        break
    done
}

function Init_Panel(){
    log "配置 1Panel Service"

    RUN_BASE_DIR=$PANEL_BASE_DIR/1panel
    mkdir -p $RUN_BASE_DIR
    rm -rf $RUN_BASE_DIR/*

    cd ${CURRENT_DIR}

    cp ./1panel /usr/local/bin && chmod +x /usr/local/bin/1panel
    if [[ ! -f /usr/bin/1panel ]]; then
        ln -s /usr/local/bin/1panel /usr/bin/1panel >/dev/null 2>&1
    fi

    cp ./1pctl /usr/local/bin && chmod +x /usr/local/bin/1pctl
    sed -i -e "s#BASE_DIR=.*#BASE_DIR=${PANEL_BASE_DIR}#g" /usr/local/bin/1pctl
    sed -i -e "s#ORIGINAL_PORT=.*#ORIGINAL_PORT=${PANEL_PORT}#g" /usr/local/bin/1pctl
    sed -i -e "s#ORIGINAL_USERNAME=.*#ORIGINAL_USERNAME=${PANEL_USERNAME}#g" /usr/local/bin/1pctl
    sed -i -e "s#ORIGINAL_PASSWORD=.*#ORIGINAL_PASSWORD=${PANEL_PASSWORD}#g" /usr/local/bin/1pctl
    PANEL_ENTRANCE=`cat /dev/urandom | head -n 16 | md5sum | head -c 10`
    sed -i -e "s#ORIGINAL_ENTRANCE=.*#ORIGINAL_ENTRANCE=${PANEL_ENTRANCE}#g" /usr/local/bin/1pctl
    if [[ ! -f /usr/bin/1pctl ]]; then
        ln -s /usr/local/bin/1pctl /usr/bin/1pctl >/dev/null 2>&1
    fi

    cp ./1panel.service /etc/systemd/system

    systemctl enable 1panel; systemctl daemon-reload 2>&1 | tee -a ${CURRENT_DIR}/install.log

    log "启动 1Panel 服务"
    systemctl start 1panel | tee -a ${CURRENT_DIR}/install.log

    for b in {1..30}
    do
        sleep 3
        service_status=`systemctl status 1panel 2>&1 | grep Active`
        if [[ $service_status == *running* ]];then
            log "1Panel 服务启动成功!"
            break;
        else
            log "1Panel 服务启动出错!"
            exit 1
        fi
    done
}

function Show_Result(){
    log ""
    log "=================感谢您的耐心等待，安装已经完成=================="
    log ""
    log "请用浏览器访问面板:"
    log "面板地址: http://\$LOCAL_IP:$PANEL_PORT/$PANEL_ENTRANCE"
    log "用户名称: $PANEL_USERNAME"
    log "用户密码: $PANEL_PASSWORD"
    log ""
    log "项目官网: https://1panel.cn"
    log "项目文档: https://1panel.cn/docs"
    log "代码仓库: https://github.com/1Panel-dev/1Panel"
    log ""
    log "如果使用的是云服务器，请至安全组开放 $PANEL_PORT 端口"
    log ""
    log "================================================================"
}

function main(){
    Prepare_System
    Set_Dir
    Install_Docker
    Install_Compose
    Set_Port
    Set_Firewall
    Set_Username
    Set_Password
    Init_Panel
    Show_Result
}
main
