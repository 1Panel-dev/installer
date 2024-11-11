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
        *"Falha"*|*"Erro"*|*"Por favor, execute este script com privilégios de root ou sudo"*)
            echo -e "${RED}${message}${NC}" 2>&1 | tee -a "${CURRENT_DIR}"/install.log
            ;;
        *"Sucesso"*)
            echo -e "${GREEN}${message}${NC}" 2>&1 | tee -a "${CURRENT_DIR}"/install.log
            ;;
        *"Ignorar"*|*"Pular"*)
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

log "======================= Iniciar a instalação ======================="

function Check_Root() {
    if [[ $EUID -ne 0 ]]; then
        log "Execute este script com privilégios de root ou sudo"
        exit 1
    fi
}

function Prepare_System(){
    if which 1panel >/dev/null 2>&1; then
        log "1Panel Linux O painel de gerenciamento de operação e manutenção do servidor foi instalado, não o instale novamente. Para manutenções use 1pctl --help"
        exit 1
    fi
}

function Set_Dir(){
    if read -t 120 -p "Defina o diretório de instalação do 1Panel. (o padrão é /opt)：" PANEL_BASE_DIR;then
        if [[ "$PANEL_BASE_DIR" != "" ]];then
            if [[ "$PANEL_BASE_DIR" != /* ]];then
                log "Por favor insira o caminho completo para o diretório"
                Set_Dir
            fi

            if [[ ! -d $PANEL_BASE_DIR ]];then
                mkdir -p "$PANEL_BASE_DIR"
                log "O caminho de instalação que você selecionou é $PANEL_BASE_DIR"
            fi
        else
            PANEL_BASE_DIR=/opt
            log "O caminho de instalação que você selecionou é $PANEL_BASE_DIR"
        fi
    else
        PANEL_BASE_DIR=/opt
        log "(Defina o tempo limite, use o caminho de instalação padrão /opt)"
    fi
}

ACCELERATOR_URL="https://docker.1panelproxy.com"
DAEMON_JSON="/etc/docker/daemon.json"
BACKUP_FILE="/etc/docker/daemon.json.1panel_bak"

function create_daemon_json() {
    log "Criar novo perfil ${DAEMON_JSON}..."
    mkdir -p /etc/docker
    echo '{
        "registry-mirrors": ["'"$ACCELERATOR_URL"'"]
    }' | tee "$DAEMON_JSON" > /dev/null
    log "A configuração de aceleração de imagem foi adicionada."
}

function configure_accelerator() {
    read -p "Deseja configurar a aceleração da imagem?(y/n): " configure_accelerator
    if [[ "$configure_accelerator" == "y" ]]; then
        if [ -f "$DAEMON_JSON" ]; then
            log "O arquivo de configuração já existe, faremos backup do arquivo de configuração existente como ${BACKUP_FILE} e criaremos um novo arquivo."
            cp "$DAEMON_JSON" "$BACKUP_FILE"
            create_daemon_json
        else
            create_daemon_json
        fi

        log "Reiniciando o serviço Docker..."
        systemctl daemon-reload
        systemctl restart docker
        log "O serviço Docker foi reiniciado com sucesso."
    else
        log "A aceleração da imagem não está configurada."
    fi
}

function Install_Docker(){
    if which docker >/dev/null 2>&1; then
        docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+' | head -n 1)
        major_version=${docker_version%%.*}
        minor_version=${docker_version##*.}
        if [[ $major_version -lt 20 ]]; then
            log "A versão do Docker detectada é $docker_version. Caso a versão do seu docker seja inferior a 20.x, isso pode afetar o uso normal de algumas funções. Recomenda-se atualizar manualmente para uma versão superior."
        fi
        configure_accelerator
    else
        log "... Instale o docker on-line"

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
                log "Escolha a fonte com a menor latência $selected_source， a latência é $min_delay 秒"
                export DOWNLOAD_URL="$selected_source"
                
                for alt_source in "${docker_install_scripts[@]}"; do
                    log "Tentar link alternativo $alt_source para baixar o script de instalação do Docker..."
                    if curl -fsSL --retry 2 --retry-delay 3 --connect-timeout 5 --max-time 10 "$alt_source" -o get-docker.sh; then
                        log "Script de instalação baixado com sucesso de $alt_source "
                        break
                    else
                        log "Falha ao baixar de: $alt_source tente o próximo link alternativo"
                    fi
                done
                
                if [ ! -f "get-docker.sh" ]; then
                    log "Todas as tentativas de download falharam. Você pode tentar instalar o Docker manualmente executando o seguinte comando："
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
                    log "Falha na instalação do Docker\nVocê pode tentar usar o pacote offline para instalação. Consulte o link a seguir para obter etapas de instalação específicas.：https://1panel.cn/docs/installation/package_installation/"
                    exit 1
                else
                    log "Docker instalado com sucesso"
                    systemctl enable docker 2>&1 | tee -a "${CURRENT_DIR}"/install.log
                    configure_accelerator
                fi
            else
                log "Não foi possível selecionar a fonte para instalação"
                exit 1
            fi
        else
            log "Fora da China continental, não há necessidade de alterar a fonte"
            export DOWNLOAD_URL="https://download.docker.com"
            curl -fsSL "https://get.docker.com" -o get-docker.sh
            sh get-docker.sh 2>&1 | tee -a "${CURRENT_DIR}"/install.log

            log "... Iniciar o serviço Docker"
            systemctl enable docker; systemctl daemon-reload; systemctl start docker 2>&1 | tee -a "${CURRENT_DIR}"/install.log

            docker_config_folder="/etc/docker"
            if [[ ! -d "$docker_config_folder" ]];then
                mkdir -p "$docker_config_folder"
            fi

            docker version >/dev/null 2>&1
            if [[ $? -ne 0 ]]; then
                log "Falha na instalação do Docker\nVocê pode tentar instalar usando o pacote de instalação. Consulte o link a seguir para obter etapas de instalação específicas.：https://1panel.cn/docs/installation/package_installation/"
                exit 1
            else
                log "Docker Instalado com sucesso"
            fi
        fi
    fi
}

function Install_Compose(){
    docker-compose version >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        log "... Instale o docker-compose online"
        
        arch=$(uname -m)
		if [ "$arch" == 'armv7l' ]; then
			arch='armv7'
		fi
		curl -L https://resource.fit2cloud.com/docker/compose/releases/download/v2.26.1/docker-compose-$(uname -s | tr A-Z a-z)-"$arch" -o /usr/local/bin/docker-compose 2>&1 | tee -a "${CURRENT_DIR}"/install.log
        if [[ ! -f /usr/local/bin/docker-compose ]];then
            log "Falha no download do Docker-compose. Tente novamente mais tarde."
            exit 1
        fi
        chmod +x /usr/local/bin/docker-compose
        ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

        docker-compose version >/dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            log "Falha na instalação do Docker Compose"
            exit 1
        else
            log "Docker Compose instalado com sucesso"
        fi
    else
        compose_v=$(docker-compose -v)
        if [[ $compose_v =~ 'docker-compose' ]];then
            read -p "Foi detectado que a versão instalada do Docker Compose é inferior (precisa ser maior ou igual a v2.0.0). Deseja atualizá-lo? [y/n] : " UPGRADE_DOCKER_COMPOSE
            if [[ "$UPGRADE_DOCKER_COMPOSE" == "Y" ]] || [[ "$UPGRADE_DOCKER_COMPOSE" == "y" ]]; then
                rm -rf /usr/local/bin/docker-compose /usr/bin/docker-compose
                Install_Compose
            else
                log "A versão do Docker Compose é: $compose_v， e isso pode afetar o desempenho da App Store. Recomenda-se atualizar manualmente para uma versão superior."
            fi
        else
            log "Detectado que o Docker Compose está instalado, pule essa etapa de instalação"
        fi
    fi
}

function Set_Port(){
    DEFAULT_PORT=$(expr $RANDOM % 55535 + 10000)

    while true; do
        read -p "Defina a porta 1Panel (o padrão é $DEFAULT_PORT）：" PANEL_PORT

        if [[ "$PANEL_PORT" == "" ]];then
            PANEL_PORT=$DEFAULT_PORT
        fi

        if ! [[ "$PANEL_PORT" =~ ^[1-9][0-9]{0,4}$ && "$PANEL_PORT" -le 65535 ]]; then
            log "Erro: O número da porta deve estar entre 1 e 65535 e não deve estar sendo utilizado por outra aplicação"
            continue
        fi

        if command -v ss >/dev/null 2>&1; then
            if ss -tlun | grep -q ":$PANEL_PORT " >/dev/null 2>&1; then
                log "A porta $PANEL_PORT está ocupada, escolha outra..."
                continue
            fi
        elif command -v netstat >/dev/null 2>&1; then
            if netstat -tlun | grep -q ":$PANEL_PORT " >/dev/null 2>&1; then
                log "A porta $PANEL_PORT está ocupada, digite novamente..."
                continue
            fi
        fi

        log "A porta definida é：$PANEL_PORT"
        break
    done
}

function Set_Firewall(){
    if which firewall-cmd >/dev/null 2>&1; then
        if systemctl status firewalld | grep -q "Active: active" >/dev/null 2>&1;then
            log "Abrindo porta $PANEL_PORT / TCP no firewall"
            firewall-cmd --zone=public --add-port="$PANEL_PORT"/tcp --permanent
            firewall-cmd --reload
        else
            log "O firewall não está ativo, aberturas de portas serão ignoradas."
        fi
    fi

    if which ufw >/dev/null 2>&1; then
        if systemctl status ufw | grep -q "Active: active" >/dev/null 2>&1;then
            log "Abrindo porta $PANEL_PORT / TCP no firewall"
            ufw allow "$PANEL_PORT"/tcp
            ufw reload
        else
            log "O firewall não está ativo, aberturas de portas serão ignoradas."
        fi
    fi
}

function Set_Entrance(){
    DEFAULT_ENTRANCE=`cat /dev/urandom | head -n 16 | md5sum | head -c 10`

    while true; do
	    read -p "Defina a entrada de segurança 1Panel (o padrão é $DEFAULT_ENTRANCE）：" PANEL_ENTRANCE
	    if [[ "$PANEL_ENTRANCE" == "" ]]; then
    	    PANEL_ENTRANCE=$DEFAULT_ENTRANCE
    	fi

    	if [[ ! "$PANEL_ENTRANCE" =~ ^[a-zA-Z0-9_]{3,30}$ ]]; then
            log "Erro: A entrada de segurança do painel suporta apenas letras, números e unrderlines/underscores, com comprimento de 3 a 30 caracteres."
            continue
    	fi
    
        log "A entrada de segurança do painel que você definiu é：$PANEL_ENTRANCE"
    	break
    done
}

function Set_Username(){
    DEFAULT_USERNAME=$(cat /dev/urandom | head -n 16 | md5sum | head -c 10)

    while true; do
        read -p "Definir usuário do painel 1Panel (o padrão é $DEFAULT_USERNAME）：" PANEL_USERNAME

        if [[ "$PANEL_USERNAME" == "" ]];then
            PANEL_USERNAME=$DEFAULT_USERNAME
        fi

        if [[ ! "$PANEL_USERNAME" =~ ^[a-zA-Z0-9_]{3,30}$ ]]; then
            log "Erro: os usuários do painel suportam apenas letras, números e unrderlines/underscores, com 3 a 30 caracteres de comprimento"
            continue
        fi

        log "O usuário do painel que você definiu é: $PANEL_USERNAME"
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
        log "Defina a senha do painel 1Panel. Após a conclusão da configuração, pressione Enter para continuar (o padrão é: $DEFAULT_PASSWORD）："
        passwd
        PANEL_PASSWORD=$reply
        if [[ "$PANEL_PASSWORD" == "" ]];then
            PANEL_PASSWORD=$DEFAULT_PASSWORD
        fi

        if [[ ! "$PANEL_PASSWORD" =~ ^[a-zA-Z0-9_!@#$%*,.?]{8,30}$ ]]; then
            log "Erro: a senha do painel suporta apenas letras, números, caracteres especiais (!@#$%*_,.?) e tem de 8 a 30 caracteres de comprimento"
            continue
        fi

        break
    done
}

function Init_Panel(){
    log "Configurar serviço 1Panel"

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

    log "Iniciar serviço 1Panel"
    systemctl start 1panel | tee -a "${CURRENT_DIR}"/install.log

    for b in {1..30}
    do
        sleep 3
        service_status=$(systemctl status 1panel 2>&1 | grep Active)
        if [[ $service_status == *running* ]];then
            log "O serviço 1Panel foi iniciado com sucesso!"
            break;
        else
            log "Erro na inicialização do serviço 1Panel"
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
    log "=================Obrigado pela sua paciência, a instalação foi concluída=================="
    log ""
    log "Utilize seu navegador para acessar o painel:"
    log "Endereço de rede externo: http://$PUBLIC_IP:$PANEL_PORT/$PANEL_ENTRANCE"
    log "Endereço da intranet: http://$LOCAL_IP:$PANEL_PORT/$PANEL_ENTRANCE"
    log "Usuário do painel: $PANEL_USERNAME"
    log "Senha do painel: $PANEL_PASSWORD"
    log ""
    log "Site oficial do projeto: https://1panel.cn"
    log "Documentação do projeto: https://1panel.cn/docs"
    log "repositório de código: https://github.com/1Panel-dev/1Panel"
    log ""
    log "Se você estiver usando um servidor em nuvem, abra a porta $PANEL_PORT no grupo de segurança"
    log ""
    log "Para a segurança do seu servidor, você não poderá mais ver sua senha depois de sair desta interface."
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
