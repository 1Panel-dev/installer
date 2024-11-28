#!/bin/bash

TXT_START_INSTALLATION="======================= Iniciando Instalação ======================="
TXT_RUN_AS_ROOT="Por favor, execute esse script como root"
TXT_SUCCESS_MESSAGE="Sucesso"
TXT_SUCCESSFULLY_MESSAGE="Sucesso"
TXT_FAIELD_MESSAGE="Falhou"
TXT_IGNORE_MESSAGE="Ignorar"
TXT_SKIP_MESSAGE="Pular"
TXT_PANEL_ALREADY_INSTALLED="O gerenciador de servidores 1Panel Linux já está instalado, por favor não instale novamente."
TXT_SET_INSTALL_DIR="Definir o diretório de instalação padrão do 1Panel. (O padrão é /opt): "
TXT_PROVIDE_FULL_PATH="Por favor indique o caminho completo do diretório."
TXT_SELECTED_INSTALL_PATH="O caminho selecionado para a instalação é:"
TXT_TIMEOUT_USE_DEFAULT_PATH="(Tempo limite atingido, usando o caminho de instalação padrão /opt)"
TXT_CREATE_NEW_CONFIG="Criando novo arquivo de configuração"
TXT_ACCELERATION_CONFIG_ADDED="A aceleração de imagem foi adicionada."
TXT_ACCELERATION_CONFIG_NOT="Aceleração de imagem não configurada."
TXT_ACCELERATION_CONFIG_ADD="Você gostaria de configurar a aceleração de imagem (y/n): "
TXT_ACCELERATION_CONFIG_EXISTS="O arquivo de configuração já existe, faremos backup do arquivo de configuração existente para: "
TXT_RESTARTING_DOCKER="Reiniciando serviços Docker..."
TXT_DOCKER_RESTARTED="Serviços Docker reiniciados com sucesso."
TXT_DOCKER_INSTALL_ONLINE="... Instalando Docker Online"
TXT_ACCELERATOR_NOT_CONFIGURED="Aceleração de imagem não configurada."
TXT_LOW_DOCKER_VERSION="Detectado que a versão do Docker do servidor é inferior a 20.x. É recomendado atualizar manualmente para evitar limitações de funcionalidade."
TXT_INSTALL_DOCKER_ONLINE="... Instalando Docker Online"
TXT_DOWNLOAD_DOCKER_SCRIPT_FAIL="Falha ao baixar o script de instalação de"
TXT_DOWNLOAD_DOCKER_SCRIPT="Baixando script de instalação do Docker"
TXT_DOWNLOAD_DOCKER_SCRIPT_SUCCESS="Docker baixado de"
TXT_TRY_NEXT_LINK="Tentando próximo link alternativo"
TXT_DOWNLOAD_FAIELD="Falha ao baixar o script de instalação de"
TXT_ALL_DOWNLOAD_ATTEMPTS_FAILED="Todas as tentativas de download falharam. Você pode tentar instalar o Docker manualmente executando o seguinte comando:"
TXT_REGIONS_OTHER_THAN_CHINA="Para regiões fora da China continental, não é necessário alterar a fonte"
TXT_DOCKER_INSTALL_SUCCESS="Docker instalado com sucesso"
TXT_DOCKER_INSTALL_FAIL="A instalação do Docker falhou\nVocê pode tentar instalar o Docker usando um pacote offline. Consulte o link a seguir para obter etapas detalhadas de instalação: https://1panel.cn/docs/installation/package_installation/"
TXT_CHOOSE_LOWEST_LATENCY_SOURCE="Escolha a fonte com menor latência"
TXT_CHOOSE_LOWEST_LATENCY_DELAY="Atraso (em segundos)"
TXT_CANNOT_SELECT_SOURCE="Não foi possível selecionar a fonte para instalação"
TXT_DOCKER_START_NOTICE="... iniciando Docker"
TXT_DOCKER_COMPOSE_INSTALL_ONLINE="... Instalando Docker Compose online"
TXT_DOCKER_COMPOSE_DOWNLOAD_FAIL="Falha ao baixar o Docker Compose, tente novamente mais tarde"
TXT_DOCKER_COMPOSE_INSTALL_SUCCESS="Docker Compose instalado com sucesso"
TXT_DOCKER_COMPOSE_INSTALL_FAIL="A instalação do Docker Compose falhou"
TXT_LOWER_VERSION_DETECTED="Uma versão mais antiga do Docker Compose foi detectada (a versão deve ser maior ou igual a v2.0.0), deseja atualizar [y/n]: "
TXT_DOCKER_COMPOSE_VERSION="Versão do Docker Compose"
TXT_DOCKER_MAY_EFFECT_STORE="o que pode afetar o uso normal da App Store."
TXT_DOCKER_COMPOSE_INSTALLED_SKIP="Docker Compose já está instalado, pulando etapa de instalação"
TXT_SET_PANEL_PORT="Definir porta do 1Panel (o padrão é"
TXT_INPUT_PORT_NUMBER="Erro: O número da porta inserido deve estar entre 1 e 65535"
TXT_THE_PORT_U_SET="A porta que você definiu é:"
TXT_PORT_OCCUPIED="Porta ocupada, por favor insira novamente..."
TXT_FIREWALL_OPEN_PORT="Abrindo porta no firewall"
TXT_FIREWALL_NOT_ACTIVE_SKIP="O firewall não está ativo, pulando abertura de porta"
TXT_FIREWALL_NOT_ACTIVE_IGNORE="O firewall não está ativo, ignorando abertura de porta"
TXT_SET_PANEL_ENTRANCE="Definir entrada segura do 1Panel (o padrão é"
TXT_INPUT_ENTRANCE_RULE="Erro: A entrada segura do painel suporta apenas letras, números, sublinhados, com comprimento de 3-30 caracteres"
TXT_YOUR_PANEL_ENTRANCE="A entrada segura do painel que você definiu é:"
TXT_SET_PANEL_USER="Definir usuário do painel 1Panel (o padrão é"
TXT_INPUT_USERNAME_RULE="Erro: O nome de usuário do painel suporta apenas letras, números, sublinhados, com comprimento de 3-30 caracteres"
TXT_YOUR_PANEL_USERNAME="O usuário do painel que você definiu é:"
TXT_SET_PANEL_PASSWORD="Definir senha do painel 1Panel, pressione Enter para continuar após definir (o padrão é"
TXT_INPUT_PASSWORD_RULE="Erro: A senha do painel suporta apenas letras, números, caracteres especiais (!@#$%*_,.?), com comprimento de 8-30 caracteres"
TXT_CONFIGURE_PANEL_SERVICE="Configurando o serviço 1Panel"
TXT_START_PANEL_SERVICE="Iniciando o serviço 1Panel"
TXT_PANEL_SERVICE_START_SUCCESS="Serviço 1Panel iniciado com sucesso!"
TXT_PANEL_SERVICE_START_ERROR="Erro ao iniciar o serviço 1Panel!"
TXT_THANK_YOU_WAITING="================= Obrigado pela sua paciência, a instalação está completa =================="
TXT_BROWSER_ACCESS_PANEL="Por favor, acesse o painel usando o navegador:"
TXT_EXTERNAL_ADDRESS="Endereço externo:"
TXT_INTERNAL_ADDRESS="Endereço interno:"
TXT_PANEL_USER="Usuário do painel:"
TXT_PANEL_PASSWORD="Senha do painel:"
TXT_PROJECT_OFFICIAL_WEBSITE="Site oficial: https://1panel.cn"
TXT_PROJECT_DOCUMENTATION="Documentação do projeto: https://1panel.cn/docs"
TXT_PROJECT_REPOSITORY="Repositório de código: https://github.com/1Panel-dev/1Panel"
TXT_OPEN_PORT_SECURITY_GROUP="Se você estiver usando um servidor em nuvem, por favor, abra a porta no grupo de segurança"
TXT_REMEMBER_YOUR_PASSWORD="Para a segurança do seu servidor, você não poderá ver sua senha novamente após sair desta tela, por favor, lembre-se dela."
TXT_SYSTEM_ARCHITECTURE="A arquitetura do sistema não é atualmente suportada. Consulte a documentação oficial para selecionar um sistema compatível."
TXT_INSTALLATIO_MODE="Por favor, insira o modo de instalação correto (dev ou estável)"
TXT_OBTAIN_VERSION_FAIELD="Falha ao obter a versão mais recente, tente novamente mais tarde"
TXT_INSTALLATION_PACKAGE_HASH="O pacote de instalação já existe. Pulando download."
TXT_INSTALLATION_PACKAGE_ERROR="O pacote de instalação já existe, mas o valor do hash é inconsistente. Iniciando download novamente"
TXT_START_DOWNLOADING_PANEL="Iniciando download do 1Panel"
TXT_INSTALLATION_PACKAGE_DOWNLOAD_ADDRESS="Endereço de download do pacote de instalação:"
TXT_INSTALLATION_PACKAGE_DOWNLOAD_FAIL="Falha ao baixar o pacote de instalação"
TXT_PANEL_SERVICE_STATUS="Verificar status do serviço 1Panel"
TXT_PANEL_SERVICE_RESTART="Reiniciar serviço 1Panel"
TXT_PANEL_SERVICE_STOP="Parar serviço 1Panel"
TXT_PANEL_SERVICE_START="Iniciar serviço 1Panel"
TXT_PANEL_SERVICE_UNINSTALL="Desinstalar serviço 1Panel"
TXT_PANEL_SERVICE_USER_INFO="Obter informações do usuário do 1Panel"
TXT_PANEL_SERVICE_LISTEN_IP="Trocar IP de escuta do 1Panel"
TXT_PANEL_SERVICE_VERSION="Obter informações da versão do 1Panel"
TXT_PANEL_SERVICE_UPDATE="Atualizar sistema 1Panel"
TXT_PANEL_SERVICE_RESET="Redefinir sistema 1Panel"
TXT_PANEL_SERVICE_RESTORE="Restaurar sistema 1Panel"
TXT_PANEL_SERVICE_UNINSTALL_NOTICE="A desinstalação irá limpar completamente os serviços e diretórios de dados do 1Panel. Deseja continuar? [y/n]"
TXT_PANEL_SERVICE_UNINSTALL_START="Iniciando desinstalação do 1Panel"
TXT_PANEL_SERVICE_UNINSTALL_STOP="Parando processo do serviço 1Panel..."
TXT_PANEL_SERVICE_UNINSTALL_REMOVE="Excluindo serviço e diretórios de dados do 1Panel..."
TXT_PANEL_SERVICE_UNINSTALL_REMOVE_CONFIG="Recarregando arquivos de configuração do serviço..."
TXT_PANEL_SERVICE_UNINSTALL_REMOVE_SUCCESS="Desinstalação concluída!"
TXT_PANEL_SERVICE_RESTORE_NOTICE="O 1Panel será restaurado para a última versão estável. Deseja continuar? [y/n]"
TXT_PANEL_SERVICE_UNSUPPORTED_PARAMETER="Parâmetros não suportados, use help ou o parâmetro --help para obter ajuda"
TXT_PANEL_CONTROL_SCRIPT="Script de controle do 1Panel"
TXT_LANG_SELECTED_MSG="Idioma já selecionado:"
TXT_LANG_PROMPT_MSG="Selecione um idioma:"
TXT_LANG_CHOICE_MSG="Digite o número correspondente à sua escolha de idioma:"
TXT_LANG_SELECTED_CONFIRM_MSG="Você selecionou:"
TXT_LANG_INVALID_MSG="Seleção inválida. Padrão definido para Inglês (en)."
TXT_LANG_NOT_FOUND_MSG="Arquivo de idioma não encontrado:"
