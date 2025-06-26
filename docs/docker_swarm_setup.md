# MPI Distribuído com Docker Swarm

Este guia completo mostra como executar o programa Monte Carlo Pi distribuído usando Docker Swarm para orquestração de containers MPI.

## 🚀 **Início Rápido**

### Pré-requisitos
- Docker Engine 17.06+
- Docker Compose 3.8+
- 4GB RAM disponível
- Portas 22, 7946, 4789 disponíveis

### Configuração em 3 comandos
```bash
# 1. Verificar sistema
make docker-check

# 2. Deploy do cluster
make swarm-deploy

# 3. Executar programa distribuído
make swarm-run
```

## 🔧 **Configuração Detalhada**

### 1. Preparação do Ambiente

#### Verificar Docker
```bash
docker --version
docker-compose --version
```

#### Inicializar Swarm (se necessário)
```bash
docker swarm init
```

### 2. Construção da Imagem MPI

A imagem contém:
- Ubuntu 22.04 LTS
- MPICH (implementação MPI)
- OpenSSH Server
- Usuário `mpiuser` pré-configurado
- Chaves SSH sem senha

```bash
# Construir imagem
make docker-build

# Ou usando script direto
./scripts/run_swarm.sh build
```

### 3. Deploy do Cluster

#### Configuração Padrão (8 nós)
```bash
make swarm-deploy
```

#### Configuração Personalizada
```bash
# Deploy com número específico de nós
./scripts/run_swarm.sh deploy 16

# Ou editar docker-compose.yml
# replicas: 16
```

### 4. Verificação do Cluster

#### Status dos Serviços
```bash
make swarm-status
```

#### Teste de Conectividade
```bash
make swarm-test
```

#### Logs do Cluster
```bash
make swarm-logs
```

## 🖥️ **Execução do Programa MPI**

### Execução Simples
```bash
# Usar configuração padrão (8 processos, 10M pontos)
make swarm-run
```

### Execução Personalizada
```bash
# Via script (mais flexível)
./scripts/run_swarm.sh run 16 100000000

# Parâmetros: número_processos pontos_monte_carlo
```

### Exemplo de Saída
```
[INFO] Executando Monte Carlo Pi com 8 processos e 10000000 pontos...
[INFO] Executando em hosts: mpi-node-1,mpi-node-2,mpi-node-3,mpi-node-4,mpi-node-5,mpi-node-6,mpi-node-7,mpi-node-8

Calculando Pi usando Monte Carlo com MPI
Número de processos: 8
Pontos por processo: 1250000
Total de pontos: 10000000

Processo 0: 981234 pontos dentro do círculo
Processo 1: 981456 pontos dentro do círculo
Processo 2: 981678 pontos dentro do círculo
Processo 3: 981345 pontos dentro do círculo
Processo 4: 981567 pontos dentro do círculo
Processo 5: 981789 pontos dentro do círculo
Processo 6: 981234 pontos dentro do círculo
Processo 7: 981456 pontos dentro do círculo

Total de pontos dentro do círculo: 7851759
Pi estimado: 3.140704
Pi real: 3.141593
Erro: 0.028%
Tempo de execução: 0.156 segundos
Speedup: 7.2x
Eficiência: 90%
```

## ⚙️ **Gerenciamento do Cluster**

### Escalabilidade Dinâmica

#### Escalar Número de Nós
```bash
# Via Makefile
make swarm-scale

# Via script (mais direto)
./scripts/run_swarm.sh scale 12
```

#### Monitoramento de Recursos
```bash
# Uso de CPU e memória
docker stats

# Status detalhado dos containers
docker service ps mpi_stack_mpi-node
```

### Menu Interativo
```bash
# Interface amigável para todas as operações
make swarm-menu

# Ou diretamente
./scripts/run_swarm.sh menu
```

## 🐛 **Solução de Problemas**

### Problemas Comuns

#### 1. Docker Swarm não inicializado
```bash
# Erro: "This node is not a swarm manager"
# Solução:
docker swarm init
```

#### 2. Containers não se comunicam
```bash
# Verificar rede overlay
docker network ls | grep mpi

# Recriar stack se necessário
make swarm-cleanup
make swarm-deploy
```

#### 3. Imagem não encontrada
```bash
# Reconstruir imagem
make docker-build
```

#### 4. SSH não funciona entre containers
```bash
# Acessar container para debug
docker exec -it $(docker ps | grep mpi_stack | head -1 | cut -d' ' -f1) bash

# Testar SSH manualmente
ssh mpiuser@mpi-node-2
```

### Logs Detalhados
```bash
# Logs de todos os containers
docker service logs -f mpi_stack_mpi-node

# Logs de container específico
docker logs <container_id>
```

### Reset Completo
```bash
# Limpar tudo e recomeçar
make swarm-cleanup
docker system prune -f
make swarm-deploy
```

## 📊 **Monitoramento e Métricas**

### Métricas de Performance

#### Comandos de Monitoramento
```bash
# Uso de recursos em tempo real
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Informações da rede
docker network inspect mpi_stack_mpi-net
```

#### Benchmarks Recomendados
```bash
# Teste de escalabilidade
for np in 2 4 8 16; do
  echo "=== $np processos ==="
  ./scripts/run_swarm.sh run $np 1000000
done

# Teste de precisão
for points in 100000 1000000 10000000; do
  echo "=== $points pontos ==="
  ./scripts/run_swarm.sh run 8 $points
done
```

## 🏗️ **Arquitetura Técnica**

### Componentes do Sistema

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Swarm Manager                    │
├─────────────────────────────────────────────────────────────┤
│  Service: mpi_stack_mpi-node (Replicas: N)                │
├─────────────────┬─────────────────┬─────────────────────────┤
│  Container 1    │  Container 2    │  Container N            │
│  mpi-node-1     │  mpi-node-2     │  mpi-node-N             │
│  Ubuntu+SSH+MPI │  Ubuntu+SSH+MPI │  Ubuntu+SSH+MPI         │
└─────────────────┴─────────────────┴─────────────────────────┘
                            │
                    ┌───────┴────────┐
                    │  Overlay Net   │
                    │   mpi-net      │
                    │  10.0.0.0/24   │
                    └────────────────┘
```

### Configuração de Rede
- **Rede**: Overlay (10.0.0.0/24)
- **DNS**: Resolução automática entre containers
- **Portas**: SSH (22) para comunicação MPI
- **Descoberta**: Docker Swarm service discovery

### Configuração de Recursos
- **Memória**: 256MB mínimo, 512MB máximo por container
- **CPU**: Sem limitação específica
- **Restart**: Automático em caso de falha

## 🔄 **Comparação com Outras Soluções**

| Características | Docker Swarm | Kubernetes | MPI Nativo | AWS EC2 |
|----------------|--------------|------------|------------|---------|
| **Setup** | Muito Fácil | Complexo | Médio | Médio |
| **Custo** | Grátis | Grátis* | Grátis | Pago |
| **Escalabilidade** | Excelente | Excelente | Limitada | Excelente |
| **Isolamento** | Alto | Alto | Baixo | Alto |
| **Gerenciamento** | Automático | Automático | Manual | Automático |
| **Overhead** | Baixo | Médio | Mínimo | Baixo |

*Kubernetes é grátis, mas gerenciado (GKE, EKS) é pago

## 📚 **Comandos de Referência**

### Makefile Targets
```bash
make docker-check      # Verificar dependências
make docker-build      # Construir imagem
make swarm-deploy      # Deploy completo
make swarm-status      # Status do cluster
make swarm-test        # Teste de conectividade
make swarm-run         # Executar programa
make swarm-scale       # Escalar cluster
make swarm-menu        # Interface interativa
make swarm-logs        # Ver logs
make swarm-cleanup     # Limpar recursos
```

### Script Direto
```bash
./scripts/run_swarm.sh check
./scripts/run_swarm.sh build
./scripts/run_swarm.sh deploy [replicas]
./scripts/run_swarm.sh status
./scripts/run_swarm.sh test
./scripts/run_swarm.sh run [processos] [pontos]
./scripts/run_swarm.sh scale [replicas]
./scripts/run_swarm.sh logs
./scripts/run_swarm.sh cleanup
./scripts/run_swarm.sh menu
```

### Docker Nativo
```bash
# Construir imagem
docker build -t mpi-node:latest -f docker/Dockerfile .

# Inicializar Swarm
docker swarm init

# Deploy da stack
cd docker && docker stack deploy -c docker-compose.yml mpi_stack

# Verificar serviços
docker service ls
docker service ps mpi_stack_mpi-node

# Executar programa
docker exec -u mpiuser -it $(docker ps | grep mpi_stack | head -1 | cut -d' ' -f1) \
  mpirun -np 8 --host mpi-node-1,mpi-node-2,mpi-node-3,mpi-node-4,mpi-node-5,mpi-node-6,mpi-node-7,mpi-node-8 \
  /home/mpiuser/monte_carlo_pi 10000000

# Limpar
docker stack rm mpi_stack
```

## 🎯 **Casos de Uso**

### Educacional
- Aprendizado de MPI distribuído
- Demonstração de computação paralela
- Experimentos com escalabilidade

### Desenvolvimento
- Teste de algoritmos MPI
- Prototipagem de clusters
- Validação antes de deploy em produção

### Pesquisa
- Simulações científicas
- Benchmark de algoritmos
- Análise de performance

## 🛠️ **Personalização Avançada**

### Modificar Configuração do Container
Edite `docker/Dockerfile` para:
- Adicionar bibliotecas científicas
- Instalar ferramentas específicas
- Modificar configurações SSH

### Ajustar Recursos
Edite `docker/docker-compose.yml`:
```yaml
deploy:
  resources:
    limits:
      memory: 1G
      cpus: '2.0'
    reservations:
      memory: 512M
      cpus: '1.0'
```

### Configurar Rede Personalizada
```yaml
networks:
  mpi-net:
    driver: overlay
    attachable: true
    ipam:
      config:
        - subnet: 192.168.100.0/24
```

Este guia fornece uma base completa para executar MPI distribuído usando Docker Swarm, oferecendo uma alternativa robusta e econômica para clusters tradicionais. 