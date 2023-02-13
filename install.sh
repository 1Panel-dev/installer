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

echo -e "======================= 开始安装 =======================" 2>&1 | tee -a ${CURRENT_DIR}/install.log

function Prepare_System(){
    is64bit=`getconf LONG_BIT`
    if [ $is64bit != '64' ]; then
        echo "错误：32位系统不支持安装 1Panel Linux 面板，请更换64位系统安装。"
        exit 1
    fi

    isInstalled=`systemctl status 1panel 2>&1 | grep Active`
    if [ $isInstalled != "" ]; then
        echo "错误：1Panel Linux 面板已安装，请勿重复安装。"
        exit 1
    fi
}

function Set_Dir(){
    if read -t 120 -p "设置 1Panel 安装目录,默认 /opt: " PANEL_BASE_DIR;then
        if [ "$PANEL_BASE_DIR" != "" ];then
            echo "你选择的安装路径为 $PANEL_BASE_DIR"
            if [ ! -d $PANEL_BASE_DIR ];then
                mkdir -p $PANEL_BASE_DIR
            fi
        else
            PANEL_BASE_DIR=/opt
            echo "你选择的安装路径为 $PANEL_BASE_DIR"
        fi
    else
        PANEL_BASE_DIR=/opt
        echo "(设置超时，使用默认安装路径 /opt)"
    fi
}

function Install_Docker(){
    if which docker >/dev/null; then
        log "检测到 Docker 已安装，跳过安装步骤"
        log "启动 Docker "
        service docker start 2>&1 | tee -a ${CURRENT_DIR}/install.log
    else
        log "... 在线安装 docker"
        curl -fsSL https://get.docker.com -o get-docker.sh 2>&1 | tee -a ${CURRENT_DIR}/install.log
        sudo sh get-docker.sh 2>&1 | tee -a ${CURRENT_DIR}/install.log
        log "... 启动 docker"
        systemctl enable docker; systemctl daemon-reload; service docker start 2>&1 | tee -a ${CURRENT_DIR}/install.log

        docker_config_folder="/etc/docker"
        if [ ! -d "$docker_config_folder" ];then
            mkdir -p "$docker_config_folder"
        fi

        docker version >/dev/null
        if [ $? -ne 0 ]; then
            log "docker 安装失败"
            exit 1
        else
            log "docker 安装成功"
        fi
    fi
}

function Install_Compose(){
    docker-compose version >/dev/null
    if [ $? -ne 0 ]; then
        log "... 在线安装 docker-compose"
        curl -L https://get.daocloud.io/docker/compose/releases/download/1.29.2/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose 2>&1 | tee -a ${CURRENT_DIR}/install.log
        chmod +x /usr/local/bin/docker-compose
        ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

        docker-compose version >/dev/null
        if [ $? -ne 0 ]; then
            log "docker-compose 安装失败"
            exit 1
        else
            log "docker-compose 安装成功"
        fi
    else
        log "检测到 Docker Compose 已安装，跳过安装步骤"
    fi
}

function Set_Firewall(){
    if which firewall-cmd >/dev/null; then
        if systemctl is-active firewalld &>/dev/null ;then
            log "防火墙端口开放"
            firewall-cmd --zone=public --add-port=9999/tcp --permanent
            firewall-cmd --reload
        else
            log "防火墙未开启，忽略端口开放"
        fi
    fi
}

function Init_Panel(){
    log "配置 1Panel Service"

    RUN_BASE_DIR=$PANEL_BASE_DIR/1panel
    mkdir -p $RUN_BASE_DIR
    rm -rf $RUN_BASE_DIR/*

    cd ${CURRENT_DIR}

    cp ./1panel /usr/local/bin && chmod +x /usr/local/bin/1panel
    if [ ! -f /usr/bin/1panel ]; then
        ln -s /usr/local/bin/1panel /usr/bin/1panel 2>/dev/null
    fi

    sed -i -e "s#BASE_DIR=.*#BASE_DIR=${PANEL_BASE_DIR}#g" ./1pctl
    cp ./1pctl /usr/local/bin && chmod +x /usr/local/bin/1pctl
    if [ ! -f /usr/bin/1pctl ]; then
        ln -s /usr/local/bin/1pctl /usr/bin/1pctl 2>/dev/null
    fi

    cp ./1panel.service /etc/systemd/system

    systemctl enable 1panel; systemctl daemon-reload 2>&1 | tee -a ${CURRENT_DIR}/install.log

    log "启动服务"
    1pctl start | tee -a ${CURRENT_DIR}/install.log
    1pctl status 2>&1 | tee -a ${CURRENT_DIR}/install.log

    for b in {1..30}
    do
        sleep 3
        service_status=`systemctl status 1panel 2>&1 | grep Active`
        if [[ $service_status == *running* ]];then
            log "服务启动成功!"
            break;
        else
            log "服务启动出错!"
            exit 1
        fi
    done

    echo -e "======================= 安装完成 =======================\n" 2>&1 | tee -a ${CURRENT_DIR}/install.log
    echo -e "请通过以下方式访问:\n URL: http://\$LOCAL_IP:9999" 2>&1 | tee -a ${CURRENT_DIR}/install.log
}

function main(){
    Prepare_System
    Set_Dir
    Install_Docker
    Install_Compose
    Set_Firewall
    Init_Panel
}
main
