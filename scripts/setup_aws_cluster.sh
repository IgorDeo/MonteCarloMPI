#!/bin/bash

# Script de automação para configurar cluster MPI híbrido (Local + AWS EC2)
# Autor: Igor Deo Alves e Roger Castellar

set -e  # Parar em caso de erro

echo "============================================"
echo "Configurador de Cluster MPI Híbrido (AWS)"
echo "============================================"

# Configurações (modifique conforme necessário)
INSTANCE_TYPE="t3.medium"
KEY_NAME="mpi-cluster-key"
SECURITY_GROUP="sg-mpi-cluster"
NUM_INSTANCES=1  # Apenas 1 instância EC2

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar dependências
check_dependencies() {
    log_info "Verificando dependências..."
    
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI não encontrado. Instale com: pip install awscli"
        exit 1
    fi
    
    if ! command -v mpirun &> /dev/null; then
        log_error "MPI não encontrado. Execute: make install-deps-macos"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS CLI não configurado. Execute: aws configure"
        exit 1
    fi
    
    log_info "✓ Dependências verificadas"
}

# Criar chave SSH se não existir
setup_ssh_key() {
    log_info "Configurando chave SSH..."
    
    if [[ ! -f ~/.ssh/id_rsa ]]; then
        log_info "Gerando nova chave SSH..."
        ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ""
    fi
    
    # Criar key pair na AWS se não existir
    if ! aws ec2 describe-key-pairs --key-names $KEY_NAME &> /dev/null; then
        log_info "Criando key pair na AWS..."
        aws ec2 import-key-pair --key-name $KEY_NAME --public-key-material fileb://~/.ssh/id_rsa.pub
    fi
    
    log_info "✓ Chave SSH configurada"
}

# Criar security group
setup_security_group() {
    log_info "Configurando Security Group..."
    
    # Criar security group se não existir
    if ! aws ec2 describe-security-groups --group-names $SECURITY_GROUP &> /dev/null; then
        log_info "Criando Security Group..."
        SECURITY_GROUP_ID=$(aws ec2 create-security-group \
            --group-name $SECURITY_GROUP \
            --description "MPI Cluster Security Group" \
            --query 'GroupId' --output text)
        
        # Obter IP público local
        LOCAL_IP=$(curl -s ifconfig.me)
        
        # Regras de firewall
        aws ec2 authorize-security-group-ingress \
            --group-id $SECURITY_GROUP_ID \
            --protocol tcp \
            --port 22 \
            --cidr ${LOCAL_IP}/32
        
        aws ec2 authorize-security-group-ingress \
            --group-id $SECURITY_GROUP_ID \
            --protocol tcp \
            --port 1024-65535 \
            --source-group $SECURITY_GROUP_ID
        
        aws ec2 authorize-security-group-ingress \
            --group-id $SECURITY_GROUP_ID \
            --protocol icmp \
            --port -1 \
            --cidr 0.0.0.0/0
    else
        SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
            --group-names $SECURITY_GROUP \
            --query 'SecurityGroups[0].GroupId' --output text)
    fi
    
    log_info "✓ Security Group configurado: $SECURITY_GROUP_ID"
}

# Criar instância EC2
create_instances() {
    log_info "Criando 1 instância EC2..."
    
    # Usar Ubuntu 22.04 LTS
    AMI_ID=$(aws ec2 describe-images \
        --owners 099720109477 \
        --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
        --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
        --output text)
    
    INSTANCE_IDS=$(aws ec2 run-instances \
        --image-id $AMI_ID \
        --count $NUM_INSTANCES \
        --instance-type $INSTANCE_TYPE \
        --key-name $KEY_NAME \
        --security-group-ids $SECURITY_GROUP_ID \
        --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MPI-Node}]' \
        --query 'Instances[].InstanceId' \
        --output text)
    
    log_info "Instância criada: $INSTANCE_IDS"
    log_info "Aguardando instância ficar pronta..."
    
    aws ec2 wait instance-running --instance-ids $INSTANCE_IDS
    
    log_info "✓ Instância EC2 criada e rodando"
}

# Obter IP da instância
get_instance_ips() {
    log_info "Obtendo IP da instância..."
    
    PUBLIC_IP=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=MPI-Node" "Name=instance-state-name,Values=running" \
        --query 'Reservations[].Instances[].PublicIpAddress' \
        --output text)
    
    echo "$PUBLIC_IP" > /tmp/mpi_instance_ips.txt
    
    log_info "IP da instância: $PUBLIC_IP"
}

# Configurar instância EC2
setup_instances() {
    log_info "Configurando instância EC2..."
    
    EC2_IP=$(cat /tmp/mpi_instance_ips.txt)
    log_info "Configurando instância $EC2_IP..."
    
    # Aguardar SSH ficar disponível
    while ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$EC2_IP "echo 'SSH OK'" &> /dev/null; do
        log_info "Aguardando SSH em $EC2_IP..."
        sleep 10
    done
    
    # Instalar MPI e dependências
    ssh -o StrictHostKeyChecking=no ubuntu@$EC2_IP << 'EOF'
sudo apt update
sudo apt install -y openmpi-bin openmpi-common libopenmpi-dev build-essential
EOF
    
    # Copiar programa compilado
    if [[ -f build/monte_carlo_pi ]]; then
        scp -o StrictHostKeyChecking=no build/monte_carlo_pi ubuntu@$EC2_IP:~/
        ssh ubuntu@$EC2_IP "chmod +x monte_carlo_pi"
    fi
    
    log_info "✓ Instância $EC2_IP configurada"
}

# Criar hostfile AWS
create_hostfile() {
    log_info "Criando hostfile AWS..."
    
    EC2_IP=$(cat /tmp/mpi_instance_ips.txt)
    
    cat > examples/hostfile_aws << EOF
localhost slots=8
$EC2_IP slots=2 user=ubuntu
EOF
    
    log_info "Hostfile criado:"
    cat examples/hostfile_aws
}

# Testar cluster
test_cluster() {
    log_info "Testando cluster MPI..."
    
    # Teste de conectividade
    log_info "Teste 1: Conectividade"
    mpirun --hostfile examples/hostfile_aws --np 2 hostname
    
    # Teste do programa Monte Carlo
    if [[ -f build/monte_carlo_pi ]]; then
        log_info "Teste 2: Monte Carlo Pi"
        mpirun --hostfile examples/hostfile_aws --np 5 ./build/monte_carlo_pi 100000
    fi
    
    log_info "✓ Cluster testado com sucesso!"
}

# Mostrar informações finais
show_final_info() {
    echo ""
    echo "============================================"
    echo "✅ CLUSTER MPI HÍBRIDO CONFIGURADO!"
    echo "============================================"
    echo ""
    echo "📋 Resumo:"
    echo "- Máquina local: 8 slots"
    echo "- Instância EC2: 1 x 2 slots"
    echo "- Total de slots: 10"
    echo ""
    echo "🚀 Como usar:"
    echo "mpirun --hostfile examples/hostfile_aws --np 10 ./build/monte_carlo_pi 10000000"
    echo ""
    echo "💰 Custo estimado: ~$0.04/hora (1 instância t3.medium)"
    echo ""
    echo "🛑 Não esqueça de parar a instância:"
    echo "aws ec2 stop-instances --instance-ids $(aws ec2 describe-instances --filters 'Name=tag:Name,Values=MPI-Node' 'Name=instance-state-name,Values=running' --query 'Reservations[].Instances[].InstanceId' --output text)"
    echo ""
}

# Limpeza (opcional)
cleanup() {
    log_warn "Parando e terminando instância EC2..."
    
    INSTANCE_IDS=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=MPI-Node" "Name=instance-state-name,Values=running" \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text)
    
    if [[ -n "$INSTANCE_IDS" ]]; then
        aws ec2 terminate-instances --instance-ids $INSTANCE_IDS
        log_info "✓ Instância terminada"
    fi
}

# Menu principal
show_menu() {
    echo ""
    echo "Escolha uma opção:"
    echo "1) Configurar cluster completo"
    echo "2) Apenas criar instância"
    echo "3) Apenas configurar instância existente"
    echo "4) Testar cluster existente"
    echo "5) Limpar/Terminar instância"
    echo "0) Sair"
    echo ""
    read -p "Opção: " choice
    
    case $choice in
        1)
            check_dependencies
            setup_ssh_key
            setup_security_group
            create_instances
            sleep 30  # Aguardar instância ficar totalmente pronta
            get_instance_ips
            setup_instances
            create_hostfile
            test_cluster
            show_final_info
            ;;
        2)
            check_dependencies
            setup_ssh_key
            setup_security_group
            create_instances
            get_instance_ips
            log_info "✓ Instância criada. Execute opção 3 para configurar."
            ;;
        3)
            get_instance_ips
            setup_instances
            create_hostfile
            log_info "✓ Instância configurada."
            ;;
        4)
            create_hostfile
            test_cluster
            ;;
        5)
            cleanup
            ;;
        0)
            log_info "Saindo..."
            exit 0
            ;;
        *)
            log_error "Opção inválida"
            show_menu
            ;;
    esac
}

# Verificar se é chamada com parâmetro
if [[ $# -eq 0 ]]; then
    show_menu
else
    case $1 in
        "setup")
            check_dependencies
            setup_ssh_key
            setup_security_group
            create_instances
            sleep 30
            get_instance_ips
            setup_instances
            create_hostfile
            test_cluster
            show_final_info
            ;;
        "cleanup")
            cleanup
            ;;
        *)
            echo "Uso: $0 [setup|cleanup]"
            exit 1
            ;;
    esac
fi 