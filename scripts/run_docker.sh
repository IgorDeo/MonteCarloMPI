#!/bin/bash

# Script para executar MPI distribuído com Docker Containers
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
NETWORK_NAME="mpi-network"

# Verificar se Docker está rodando
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker não está rodando. Inicie o Docker e tente novamente."
        exit 1
    fi
    log_info "Docker está rodando"
}

# Criar rede customizada para comunicação entre containers
create_network() {
    if ! docker network inspect "$NETWORK_NAME" > /dev/null 2>&1; then
        log_info "Criando rede customizada '$NETWORK_NAME'..."
        docker network create --driver bridge "$NETWORK_NAME"
        log_info "Rede '$NETWORK_NAME' criada com sucesso"
    else
        log_info "Rede '$NETWORK_NAME' já existe"
    fi
}

# Remover rede customizada
remove_network() {
    if docker network inspect "$NETWORK_NAME" > /dev/null 2>&1; then
        log_info "Removendo rede '$NETWORK_NAME'..."
        docker network rm "$NETWORK_NAME" 2>/dev/null || true
    fi
}

# Construir imagem
build_image() {
    log_info "Construindo imagem MPI otimizada (Alpine Multi-stage)..."
    cd "$(dirname "$0")/.."
    docker build -t mpi-node:latest -f docker/Dockerfile .
    log_info "Imagem construída com sucesso"
}

# Deploy com containers individuais
deploy_containers() {
    local replicas=${1:-$DEFAULT_REPLICAS}
    
    log_info "Fazendo deploy com $replicas containers MPI..."
    
    # Limpar containers e rede existentes
    cleanup_containers
    
    # Criar rede customizada
    create_network
    
    # Criar containers usando rede customizada
    for i in $(seq 1 $replicas); do
        log_info "Criando container mpi-node-$i..."
        docker run -d \
            --name "mpi-node-$i" \
            --hostname "mpi-node-$i" \
            --network "$NETWORK_NAME" \
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
    
    local containers=$(docker ps --filter "name=mpi-node-" --format "{{.Names}}")
    
    if [ -z "$containers" ]; then
        log_error "Nenhum container MPI encontrado"
        return 1
    fi
    
    local first_container=$(echo "$containers" | head -1)
    log_info "Usando container '$first_container' como base para testes"
    
    # Teste 1: Conectividade por hostname
    log_info "=== Teste 1: Conectividade por hostname ==="
    for container in $containers; do
        if [ "$container" = "$first_container" ]; then
            log_info "✓ $container: SELF (pular)"
            continue
        fi
        
        if docker exec "$first_container" ping -c 1 -W 2 "$container" > /dev/null 2>&1; then
            log_info "✓ Conectividade com $container: OK"
        else
            log_warn "✗ Conectividade com $container: FALHOU (hostname)"
        fi
    done
    
    # Teste 2: Conectividade por IP
    log_info "=== Teste 2: Conectividade por IP ==="
    for container in $containers; do
        if [ "$container" = "$first_container" ]; then
            continue
        fi
        
        local container_ip=$(docker inspect "$container" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
        if [ -n "$container_ip" ]; then
            if docker exec "$first_container" ping -c 1 -W 2 "$container_ip" > /dev/null 2>&1; then
                log_info "✓ Conectividade com $container ($container_ip): OK"
            else
                log_warn "✗ Conectividade com $container ($container_ip): FALHOU"
            fi
        else
            log_warn "✗ Não foi possível obter IP do $container"
        fi
    done
    
    # Teste 3: Resolução DNS
    log_info "=== Teste 3: Resolução DNS ==="
    for container in $containers; do
        if [ "$container" = "$first_container" ]; then
            continue
        fi
        
        if docker exec "$first_container" nslookup "$container" > /dev/null 2>&1; then
            log_info "✓ DNS para $container: OK"
        else
            log_warn "✗ DNS para $container: FALHOU"
        fi
    done
    
    # Teste 4: Informações da rede
    log_info "=== Informações da Rede ==="
    log_info "Rede utilizada: $NETWORK_NAME"
    docker network inspect "$NETWORK_NAME" --format '{{.Driver}} - {{.Scope}} - {{len .Containers}} containers' 2>/dev/null || log_warn "Rede não encontrada"
    
    # Listar IPs de todos os containers
    log_info "IPs dos containers:"
    for container in $containers; do
        local container_ip=$(docker inspect "$container" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
        log_info "  $container: $container_ip"
    done
}

# Verificar processos MPI em execução
check_mpi_processes() {
    log_info "Verificando processos MPI em execução..."
    
    local containers=$(docker ps --filter "name=mpi-node-" --format "{{.Names}}" | sort)
    
    for container in $containers; do
        local mpi_processes=$(docker exec "$container" ps aux | grep monte_carlo_pi | grep -v grep | wc -l)
        if [ "$mpi_processes" -gt 0 ]; then
            log_info "✓ $container: $mpi_processes processo(s) MPI"
            docker exec "$container" ps aux | grep monte_carlo_pi | grep -v grep | while read line; do
                log_info "  $line"
            done
        else
            log_info "○ $container: nenhum processo MPI"
        fi
    done
}

# Executar programa MPI com verificação de distribuição
run_mpi_containers_with_verification() {
    local np=${1:-$DEFAULT_REPLICAS}
    local points=${2:-$DEFAULT_POINTS}
    
    log_info "Executando Monte Carlo Pi DISTRIBUÍDO com verificação..."
    log_info "Processos: $np | Pontos: $points"
    
    # Verificar containers disponíveis
    local available_containers=$(docker ps --filter "name=mpi-node-" --format "{{.Names}}" | wc -l)
    if [ "$available_containers" -eq 0 ]; then
        log_error "Nenhum container MPI encontrado. Execute 'deploy' primeiro."
        return 1
    fi
    
    # Obter lista de containers
    local containers=$(docker ps --filter "name=mpi-node-" --format "{{.Names}}" | sort)
    local first_container=$(echo "$containers" | head -1)
    
    log_info "Container master: $first_container"
    log_info "Containers disponíveis: $available_containers"
    
    # Criar hostfile dinâmico
    log_info "Criando hostfile para execução distribuída..."
    local hostfile_content=""
    local slots_per_container=$((np / available_containers))
    local remaining_slots=$((np % available_containers))
    
    for container in $containers; do
        local container_slots=$slots_per_container
        # Distribuir slots restantes no primeiro container
        if [ "$container" = "$first_container" ] && [ $remaining_slots -gt 0 ]; then
            container_slots=$((container_slots + remaining_slots))
        fi
        
        if [ $container_slots -gt 0 ]; then
            hostfile_content="${hostfile_content}${container} slots=${container_slots}\n"
        fi
    done
    
    # Criar hostfile no container master
    echo -e "$hostfile_content" | docker exec -i "$first_container" tee /home/mpiuser/hostfile > /dev/null
    
    log_info "Hostfile criado:"
    docker exec "$first_container" cat /home/mpiuser/hostfile
    
    # Configurar SSH entre containers
    log_info "Configurando SSH entre containers..."
    setup_ssh_between_containers "$containers" "$first_container"
    
    # Testar SSH
    log_info "Testando SSH entre containers..."
    test_ssh_connectivity "$containers" "$first_container"
    
    # Executar MPI distribuído em background para verificação
    log_info "Iniciando execução MPI distribuído..."
    log_info "Comando: mpirun --hostfile /home/mpiuser/hostfile -np $np /home/mpiuser/monte_carlo_pi $points"
    
    # Executar em background
    docker exec -u mpiuser "$first_container" mpirun \
        --hostfile /home/mpiuser/hostfile \
        --mca btl_tcp_if_include eth0 \
        --mca oob_tcp_if_include eth0 \
        --allow-run-as-root \
        -np $np \
        /home/mpiuser/monte_carlo_pi $points &
    
    local mpi_pid=$!
    
    # Aguardar um pouco e verificar processos
    sleep 2
    log_info "Verificando distribuição de processos..."
    check_mpi_processes
    
    # Aguardar conclusão
    wait $mpi_pid
    
    log_info "Execução MPI concluída!"
}

# Configurar SSH entre containers
setup_ssh_between_containers() {
    local containers="$1"
    local master_container="$2"
    
    log_info "Copiando chaves SSH entre containers..."
    
    # Obter chave pública do master
    local master_pubkey=$(docker exec "$master_container" cat /home/mpiuser/.ssh/id_rsa.pub)
    
    # Distribuir chave pública para todos os containers
    for container in $containers; do
        if [ "$container" != "$master_container" ]; then
            log_info "Configurando SSH: $master_container -> $container"
            
            # Adicionar chave pública do master no container de destino
            echo "$master_pubkey" | docker exec -i "$container" tee -a /home/mpiuser/.ssh/authorized_keys > /dev/null
            
            # Obter chave pública do container atual e adicionar no master
            local container_pubkey=$(docker exec "$container" cat /home/mpiuser/.ssh/id_rsa.pub)
            echo "$container_pubkey" | docker exec -i "$master_container" tee -a /home/mpiuser/.ssh/authorized_keys > /dev/null
            
            # Adicionar host key para evitar prompt de verificação
            docker exec "$master_container" sh -c "ssh-keyscan -H $container >> /home/mpiuser/.ssh/known_hosts 2>/dev/null"
            docker exec "$container" sh -c "ssh-keyscan -H $master_container >> /home/mpiuser/.ssh/known_hosts 2>/dev/null"
        fi
    done
    
    # Configurar permissões corretas
    for container in $containers; do
        docker exec "$container" chown -R mpiuser:mpiuser /home/mpiuser/.ssh
        docker exec "$container" chmod 700 /home/mpiuser/.ssh
        docker exec "$container" chmod 600 /home/mpiuser/.ssh/authorized_keys
        docker exec "$container" chmod 600 /home/mpiuser/.ssh/id_rsa
        docker exec "$container" chmod 644 /home/mpiuser/.ssh/id_rsa.pub
        docker exec "$container" chmod 644 /home/mpiuser/.ssh/known_hosts 2>/dev/null || true
    done
}

# Testar conectividade SSH
test_ssh_connectivity() {
    local containers="$1" 
    local master_container="$2"
    
    log_info "Testando conectividade SSH..."
    
    for container in $containers; do
        if [ "$container" != "$master_container" ]; then
            if docker exec -u mpiuser "$master_container" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$container" echo "SSH OK" > /dev/null 2>&1; then
                log_info "✓ SSH $master_container -> $container: OK"
            else
                log_warn "✗ SSH $master_container -> $container: FALHOU"
            fi
        fi
    done
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
    
    # Remover rede customizada
    remove_network
}

# Escalar containers (recriar com novo número)
scale_containers() {
    local replicas=${1:-$DEFAULT_REPLICAS}
    log_info "Escalando para $replicas containers..."
    deploy_containers "$replicas"
}

# Logs do primeiro container
show_logs() {
    log_info "Logs do primeiro container MPI:"
    docker logs mpi-node-1 2>/dev/null || log_error "Container mpi-node-1 não encontrado"
}

# Menu interativo
show_menu() {
    echo "==============================================="
    echo "    MPI Distribuído com Docker Containers"
    echo "==============================================="
    echo "1. Verificar dependências"
    echo "2. Construir imagem otimizada"
    echo "3. Deploy dos containers"
    echo "4. Verificar status dos containers"
    echo "5. Testar conectividade"
    echo "6. Executar programa MPI"
    echo "7. Escalar containers"
    echo "8. Ver logs"
    echo "9. Limpar containers"
    echo "0. Sair"
    echo "==============================================="
}

# Função principal
main() {
    case "$1" in
        "check")
            check_docker
            ;;
        "build")
            build_image
            ;;
        "deploy")
            check_docker
            build_image
            deploy_containers "$2"
            ;;
        "status")
            check_containers_status
            ;;
        "test")
            test_containers_connectivity
            ;;
        "run")
            run_mpi_containers_with_verification "$2" "$3"
            ;;
        "scale")
            scale_containers "$2"
            ;;
        "logs")
            show_logs
            ;;
        "cleanup")
            cleanup_containers
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
                        run_mpi_containers_with_verification "$np" "$points"
                        ;;
                    7) 
                        read -p "Novo número de containers: " replicas
                        scale_containers "$replicas"
                        ;;
                    8) show_logs ;;
                    9) cleanup_containers ;;
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
            echo "Comandos:"
            echo "  check          - Verificar dependências do Docker"
            echo "  build          - Construir imagem Docker otimizada"
            echo "  deploy [N]     - Deploy com N containers MPI"
            echo "  status         - Verificar status dos containers"
            echo "  test           - Testar conectividade"
            echo "  run [N] [P]    - Executar MPI com N processos e P pontos"
            echo "  scale [N]      - Escalar para N containers"
            echo "  logs           - Ver logs do primeiro container"
            echo "  cleanup        - Limpar containers"
            echo "  menu           - Menu interativo"
            echo ""
            echo "Exemplos:"
            echo "  $0 build                 # Construir imagem otimizada"
            echo "  $0 deploy 4              # Deploy com 4 containers"
            echo "  $0 run 4 1000000        # Executar com 4 processos, 1M pontos"
            echo "  $0 scale 8              # Escalar para 8 containers"
            ;;
    esac
}

# Executar função principal
main "$@" 