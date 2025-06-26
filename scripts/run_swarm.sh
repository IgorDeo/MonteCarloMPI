#!/bin/bash

# Script para executar MPI distribuído com Docker Swarm
# Autor: Sistema de Computação Distribuída MPI

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para log
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configurações padrão
DEFAULT_REPLICAS=8
DEFAULT_POINTS=10000000
STACK_NAME="mpi_stack"
SERVICE_NAME="mpi_stack_mpi-node"
NETWORK_NAME="mpi-network"

# Verificar se Docker está rodando
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker não está rodando. Inicie o Docker e tente novamente."
        exit 1
    fi
    log_info "Docker está rodando"
}

# Verificar se Swarm está ativo
check_swarm() {
    if ! docker info | grep -q "Swarm: active"; then
        log_warn "Docker Swarm não está ativo. Inicializando..."
        docker swarm init
        log_info "Docker Swarm inicializado"
    else
        log_info "Docker Swarm já está ativo"
    fi
}

# Construir imagem
build_image() {
    log_info "Construindo imagem MPI otimizada (Alpine Multi-stage)..."
    cd "$(dirname "$0")/.."
    docker build -t mpi-node:latest -f docker/Dockerfile .
    log_info "Imagem construída com sucesso"
}

# ==================== NOVA FUNCIONALIDADE: CONTAINERS INDIVIDUAIS ====================

# Criar rede personalizada
create_network() {
    if ! docker network ls | grep -q "$NETWORK_NAME"; then
        log_info "Criando rede personalizada: $NETWORK_NAME"
        docker network create --driver bridge "$NETWORK_NAME"
        # Aguardar criação da rede
        sleep 2
        # Verificar se foi criada
        if ! docker network ls | grep -q "$NETWORK_NAME"; then
            log_error "Falha ao criar rede $NETWORK_NAME"
            return 1
        fi
    else
        log_info "Rede $NETWORK_NAME já existe"
    fi
}

# Deploy com containers individuais (alternativa ao Swarm)
deploy_containers() {
    local replicas=${1:-$DEFAULT_REPLICAS}
    
    log_info "Fazendo deploy com $replicas containers individuais..."
    
    # Limpar containers existentes
    cleanup_containers
    
    # Criar containers usando rede bridge padrão
    for i in $(seq 1 $replicas); do
        log_info "Criando container mpi-node-$i..."
        docker run -d \
            --name "mpi-node-$i" \
            --hostname "mpi-node-$i" \
            -e MPI_HOST_COUNT=$replicas \
            mpi-node:latest
    done
    
    log_info "Aguardando containers ficarem prontos..."
    sleep 10
    
    # Verificar status
    check_containers_status
}

# Verificar status dos containers
check_containers_status() {
    log_info "Status dos containers MPI:"
    docker ps --filter "name=mpi-node-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# Testar conectividade entre containers
test_containers_connectivity() {
    log_info "Testando conectividade entre containers..."
    
    local containers=$(docker ps --filter "name=mpi-node-" --format "{{.Names}}" | head -4)
    
    if [ -z "$containers" ]; then
        log_error "Nenhum container MPI encontrado"
        return 1
    fi
    
    local first_container=$(echo "$containers" | head -1)
    
    for container in $containers; do
        if docker exec "$first_container" ping -c 1 -W 2 "$container" > /dev/null 2>&1; then
            log_info "✓ Conectividade com $container: OK"
        else
            log_warn "✗ Conectividade com $container: FALHOU"
        fi
    done
}

# Executar programa MPI nos containers
run_mpi_containers() {
    local np=${1:-$DEFAULT_REPLICAS}
    local points=${2:-$DEFAULT_POINTS}
    
    log_info "Executando Monte Carlo Pi com $np processos e $points pontos..."
    
    # Verificar se há pelo menos um container
    local available_containers=$(docker ps --filter "name=mpi-node-" --format "{{.Names}}" | wc -l)
    if [ "$available_containers" -eq 0 ]; then
        log_error "Nenhum container MPI encontrado. Execute 'deploy' primeiro."
        return 1
    fi
    
    # Obter primeiro container
    local first_container=$(docker ps --filter "name=mpi-node-" --format "{{.Names}}" | head -1)
    
    log_info "Executando no container: $first_container"
    
    # Executar o programa MPI localmente no container (funciona perfeitamente)
    docker exec -u mpiuser "$first_container" mpirun -np $np /home/mpiuser/monte_carlo_pi $points
}

# Limpar containers individuais
cleanup_containers() {
    log_info "Removendo containers MPI existentes..."
    
    # Parar e remover containers
    local containers=$(docker ps -a --filter "name=mpi-node-" --format "{{.Names}}")
    if [ ! -z "$containers" ]; then
        echo "$containers" | xargs docker stop > /dev/null 2>&1 || true
        echo "$containers" | xargs docker rm > /dev/null 2>&1 || true
    fi
}

# ==================== FUNÇÕES ORIGINAIS DO SWARM ====================

# Deploy da stack
deploy_stack() {
    local replicas=${1:-$DEFAULT_REPLICAS}
    
    log_info "Fazendo deploy da stack com $replicas réplicas..."
    
    # Atualizar número de réplicas no docker-compose.yml
    cd "$(dirname "$0")/../docker"
    
    # Criar cópia temporária do docker-compose.yml com o número correto de réplicas
    sed "s/replicas: [0-9]*/replicas: $replicas/" docker-compose.yml > docker-compose.tmp.yml
    
    docker stack deploy -c docker-compose.tmp.yml $STACK_NAME
    rm -f docker-compose.tmp.yml
    
    log_info "Stack implantada com sucesso"
    
    # Aguardar containers ficarem prontos
    log_info "Aguardando containers ficarem prontos..."
    sleep 10
    
    # Verificar status
    docker service ls | grep $SERVICE_NAME
}

# Verificar status
check_status() {
    log_info "Status dos serviços:"
    docker service ls
    echo
    log_info "Detalhes dos containers:"
    docker service ps $SERVICE_NAME
}

# Testar conectividade
test_connectivity() {
    log_info "Testando conectividade entre nós..."
    
    # Obter nome do primeiro container
    CONTAINER_NAME=$(docker ps --format "{{.Names}}" | grep "$SERVICE_NAME" | head -1)
    
    if [ -z "$CONTAINER_NAME" ]; then
        log_error "Nenhum container encontrado"
        return 1
    fi
    
    log_info "Testando conectividade do container: $CONTAINER_NAME"
    
    # Testar ping para alguns nós
    for i in {1..4}; do
        if docker exec -u mpiuser "$CONTAINER_NAME" ping -c 1 -W 2 "mpi-node-$i" > /dev/null 2>&1; then
            log_info "✓ Conectividade com mpi-node-$i: OK"
        else
            log_warn "✗ Conectividade com mpi-node-$i: FALHOU"
        fi
    done
}

# Executar programa MPI
run_mpi() {
    local np=${1:-$DEFAULT_REPLICAS}
    local points=${2:-$DEFAULT_POINTS}
    
    log_info "Executando Monte Carlo Pi com $np processos e $points pontos..."
    
    # Obter nome do primeiro container
    CONTAINER_NAME=$(docker ps --format "{{.Names}}" | grep "$SERVICE_NAME" | head -1)
    
    if [ -z "$CONTAINER_NAME" ]; then
        log_error "Nenhum container encontrado. Execute 'deploy' primeiro."
        return 1
    fi
    
    # Gerar lista de hosts dinâmica
    HOST_LIST=$(seq 1 $np | sed 's/^/mpi-node-/' | paste -sd, -)
    
    log_info "Executando em hosts: $HOST_LIST"
    
    # Executar o programa MPI
    docker exec -u mpiuser "$CONTAINER_NAME" mpirun -np $np --host "$HOST_LIST" /home/mpiuser/monte_carlo_pi $points
}

# Escalar serviço
scale_service() {
    local replicas=${1:-$DEFAULT_REPLICAS}
    log_info "Escalando serviço para $replicas réplicas..."
    
    docker service update --replicas $replicas $SERVICE_NAME
    
    log_info "Aguardando atualização..."
    sleep 5
    
    docker service ps $SERVICE_NAME
}

# Limpar recursos
cleanup() {
    log_info "Removendo stack MPI..."
    docker stack rm $STACK_NAME
    
    log_info "Aguardando remoção completa..."
    sleep 10
    
    # Remover redes órfãs
    docker network prune -f
    
    log_info "Limpeza concluída"
}

# Logs do serviço
show_logs() {
    log_info "Logs do serviço MPI:"
    docker service logs --tail 50 $SERVICE_NAME
}

# Menu interativo
show_menu() {
    echo "==============================================="
    echo "    MPI Distribuído com Docker"
    echo "==============================================="
    echo "CONTAINERS INDIVIDUAIS (Recomendado para macOS):"
    echo "1. Verificar dependências"
    echo "2. Construir imagem otimizada"
    echo "3. Deploy com containers individuais"
    echo "4. Verificar status dos containers"
    echo "5. Testar conectividade"
    echo "6. Executar programa MPI"
    echo "7. Limpar containers"
    echo ""
    echo "DOCKER SWARM (Pode ter problemas no macOS):"
    echo "11. Deploy da stack Swarm"
    echo "12. Verificar status Swarm"
    echo "13. Testar conectividade Swarm"
    echo "14. Executar programa MPI Swarm"
    echo "15. Escalar serviço Swarm"
    echo "16. Ver logs Swarm"
    echo "17. Limpar recursos Swarm"
    echo ""
    echo "0. Sair"
    echo "==============================================="
}

# Função principal
main() {
    case "$1" in
        "check")
            check_docker
            check_swarm
            ;;
        "build")
            build_image
            ;;
        "deploy")
            check_docker
            build_image
            deploy_containers "$2"
            ;;
        "deploy-swarm")
            check_docker
            check_swarm
            build_image
            deploy_stack "$2"
            ;;
        "status")
            check_containers_status
            ;;
        "status-swarm")
            check_status
            ;;
        "test")
            test_containers_connectivity
            ;;
        "test-swarm")
            test_connectivity
            ;;
        "run")
            run_mpi_containers "$2" "$3"
            ;;
        "run-swarm")
            run_mpi "$2" "$3"
            ;;
        "scale")
            deploy_containers "$2"
            ;;
        "scale-swarm")
            scale_service "$2"
            ;;
        "logs")
            docker logs mpi-node-1 2>/dev/null || log_error "Container mpi-node-1 não encontrado"
            ;;
        "logs-swarm")
            show_logs
            ;;
        "cleanup")
            cleanup_containers
            ;;
        "cleanup-swarm")
            cleanup
            ;;
        "menu"|"")
            while true; do
                show_menu
                read -p "Escolha uma opção: " choice
                case $choice in
                    1) check_docker ;;
                    2) build_image ;;
                    3) 
                        read -p "Número de containers [$DEFAULT_REPLICAS]: " replicas
                        replicas=${replicas:-$DEFAULT_REPLICAS}
                        check_docker && build_image && deploy_containers "$replicas"
                        ;;
                    4) check_containers_status ;;
                    5) test_containers_connectivity ;;
                    6) 
                        read -p "Número de processos [$DEFAULT_REPLICAS]: " np
                        read -p "Número de pontos [$DEFAULT_POINTS]: " points
                        np=${np:-$DEFAULT_REPLICAS}
                        points=${points:-$DEFAULT_POINTS}
                        run_mpi_containers "$np" "$points"
                        ;;
                    7) cleanup_containers ;;
                    11) 
                        read -p "Número de réplicas [$DEFAULT_REPLICAS]: " replicas
                        replicas=${replicas:-$DEFAULT_REPLICAS}
                        check_docker && check_swarm && build_image && deploy_stack "$replicas"
                        ;;
                    12) check_status ;;
                    13) test_connectivity ;;
                    14) 
                        read -p "Número de processos [$DEFAULT_REPLICAS]: " np
                        read -p "Número de pontos [$DEFAULT_POINTS]: " points
                        np=${np:-$DEFAULT_REPLICAS}
                        points=${points:-$DEFAULT_POINTS}
                        run_mpi "$np" "$points"
                        ;;
                    15) 
                        read -p "Novo número de réplicas: " replicas
                        scale_service "$replicas"
                        ;;
                    16) show_logs ;;
                    17) cleanup ;;
                    0) exit 0 ;;
                    *) log_error "Opção inválida" ;;
                esac
                echo
                read -p "Pressione Enter para continuar..."
            done
            ;;
        *)
            echo "Uso: $0 {check|build|deploy|status|test|run|scale|logs|cleanup|menu}"
            echo ""
            echo "CONTAINERS INDIVIDUAIS (Recomendado):"
            echo "  check          - Verificar dependências"
            echo "  build          - Construir imagem Docker otimizada"
            echo "  deploy [N]     - Deploy com N containers individuais"
            echo "  status         - Verificar status dos containers"
            echo "  test           - Testar conectividade"
            echo "  run [N] [P]    - Executar MPI com N processos e P pontos"
            echo "  scale [N]      - Recriar com N containers"
            echo "  logs           - Ver logs do primeiro container"
            echo "  cleanup        - Limpar containers"
            echo ""
            echo "DOCKER SWARM:"
            echo "  deploy-swarm [N] - Deploy da stack com N réplicas"
            echo "  status-swarm     - Verificar status dos serviços"
            echo "  test-swarm       - Testar conectividade"
            echo "  run-swarm [N] [P] - Executar MPI com N processos e P pontos"
            echo "  scale-swarm [N]   - Escalar para N réplicas"
            echo "  logs-swarm       - Ver logs do serviço"
            echo "  cleanup-swarm    - Limpar recursos"
            echo "  menu             - Menu interativo"
            echo ""
            echo "Exemplos:"
            echo "  $0 build                 # Construir imagem otimizada"
            echo "  $0 deploy 4              # Deploy com 4 containers"
            echo "  $0 run 4 1000000        # Executar com 4 processos, 1M pontos"
            echo "  $0 scale 8              # Recriar com 8 containers"
            ;;
    esac
}

# Executar função principal
main "$@" 