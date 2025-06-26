# Projeto MPI: Cálculo de Pi usando Monte Carlo

## Descrição do Problema

Este projeto implementa o cálculo do valor de Pi (π) utilizando o método Monte Carlo com programação paralela através do MPI (Message Passing Interface). O método Monte Carlo é uma técnica estatística que usa números aleatórios para resolver problemas matemáticos, sendo ideal para demonstrar conceitos de computação paralela.

### Método Monte Carlo para Cálculo de Pi

O método baseia-se na relação geométrica entre um círculo inscrito em um quadrado:

1. **Princípio**: Consideramos um círculo de raio 1 inscrito em um quadrado de lado 2
2. **Área do círculo**: π × r² = π × 1² = π
3. **Área do quadrado**: (2r)² = 4
4. **Razão**: π/4 = (área do círculo)/(área do quadrado)

**Algoritmo**:
- Gerar pontos aleatórios (x, y) no intervalo [-1, 1]
- Verificar se cada ponto está dentro do círculo: x² + y² ≤ 1
- Calcular a razão: pontos_dentro_círculo / total_pontos
- Estimar π: 4 × (pontos_dentro_círculo / total_pontos)

## MPI: Distribuído vs Threads

### 🌐 **MPI é para Computação Distribuída**
- **MPI usa PROCESSOS**, não threads
- **Funciona em múltiplas máquinas** conectadas por rede
- **Memória distribuída**: cada processo tem sua própria memória
- **Comunicação via mensagens**: processos se comunicam enviando dados
- **Escalável para clusters e supercomputadores**

### 🔧 **Verificar Slots Disponíveis**

```bash
# Ver mapeamento de processos
mpirun --display-map --np 8 hostname

# Ver alocação de recursos  
mpirun --display-allocation --np 4 hostname

# Número de cores do sistema
sysctl -n hw.ncpu  # macOS
nproc              # Linux
```

### 🌐 **Execução Distribuída**

#### Arquivo de Hosts (hostfile)
```bash
# Criar hostfile para múltiplas máquinas
echo "server1 slots=8" > hostfile
echo "server2 slots=4" >> hostfile
echo "192.168.1.10 slots=16" >> hostfile

# Executar distribuído
mpirun -np 28 --hostfile hostfile ./monte_carlo_pi 10000000
```

#### Configuração SSH
```bash
# Configurar acesso sem senha
ssh-keygen -t rsa
ssh-copy-id user@server1
ssh-copy-id user@server2
```

## Plano da Solução com MPI

### Arquitectura Paralela

**Estratégia de Paralelização**:
- **Processo Master (rank 0)**: Coordena a execução, coleta resultados e calcula Pi final
- **Processos Worker (rank > 0)**: Executam simulações Monte Carlo independentes
- **Distribuição do trabalho**: Cada processo gera N/P pontos (onde N = total de pontos, P = número de processos)

### Funcionalidades MPI Utilizadas

#### 1. **Inicialização e Finalização**
```c
MPI_Init(&argc, &argv)     // Inicializar ambiente MPI
MPI_Finalize()             // Finalizar ambiente MPI
```

#### 2. **Identificação de Processos**
```c
MPI_Comm_rank(MPI_COMM_WORLD, &rank)  // Identifica o rank do processo
MPI_Comm_size(MPI_COMM_WORLD, &size)  // Obtém número total de processos
```

#### 3. **Comunicação Point-to-Point**
```c
MPI_Send()  // Processos worker enviam resultados para master
MPI_Recv()  // Processo master recebe resultados dos workers
```

#### 4. **Operações Coletivas**
```c
MPI_Reduce()     // Redução para somar todos os pontos dentro do círculo
MPI_Bcast()      // Broadcast do número de pontos por processo (opcional)
```

#### 5. **Medição de Tempo**
```c
MPI_Wtime()  // Medir tempo de execução para análise de performance
```

### Estrutura do Programa

#### Arquivos do Projeto

```
/
├── README.md              # Este arquivo
├── src/
│   ├── monte_carlo_pi.c   # Programa principal MPI
│   └── utils.h            # Funções utilitárias
├── scripts/
│   ├── compile.sh         # Script de compilação
│   └── run.sh            # Script de execução
├── examples/
│   ├── hostfile           # Exemplo de configuração distribuída
│   └── hostfile_simple    # Configuração local simples
├── results/
│   └── performance.txt    # Resultados de performance
└── docs/
    ├── mpi_analysis.md    # Análise das funcionalidades MPI
    └── mpi_distributed.md # Guia de execução distribuída
```

### Algoritmo Detalhado

#### Processo Master (rank 0):
1. Inicializar MPI
2. Determinar número de pontos por processo
3. Executar simulação Monte Carlo local
4. Receber resultados dos processos worker
5. Calcular Pi final e tempo de execução
6. Exibir resultados e estatísticas

#### Processos Worker (rank > 0):
1. Inicializar MPI
2. Receber número de pontos para processar
3. Executar simulação Monte Carlo local
4. Enviar resultado para processo master

### Análise de Performance

**Métricas a serem medidas**:
- Tempo de execução sequencial vs paralelo
- Speedup: T_sequencial / T_paralelo
- Eficiência: Speedup / número_de_processos
- Escalabilidade com diferentes números de processos

**Testes Planejados**:
- Execução com 1, 2, 4, 8 processos
- Diferentes números de pontos (10⁶, 10⁷, 10⁸)
- Análise da precisão vs. performance

### Funcionalidades MPI em Detalhes

#### 1. **MPI_Init e MPI_Finalize**
- **Propósito**: Inicialização e finalização do ambiente MPI
- **Uso**: Obrigatório no início e fim de qualquer programa MPI

#### 2. **MPI_Comm_rank e MPI_Comm_size**
- **Propósito**: Identificação de processos e conhecimento do ambiente
- **Uso**: Determinar papel de cada processo (master/worker)

#### 3. **MPI_Send e MPI_Recv**
- **Propósito**: Comunicação ponto-a-ponto bloqueante
- **Uso**: Workers enviam contagem de pontos para master

#### 4. **MPI_Reduce**
- **Propósito**: Operação coletiva de redução (soma)
- **Uso**: Somar todos os pontos dentro do círculo de todos os processos
- **Vantagem**: Mais eficiente que múltiplos Send/Recv

#### 5. **MPI_Wtime**
- **Propósito**: Medição precisa de tempo
- **Uso**: Análise de performance e benchmarking

### Compilação e Execução

```bash
# Compilação
mpicc -o monte_carlo_pi src/monte_carlo_pi.c -lm

# Execução local
mpirun -np 4 ./monte_carlo_pi 1000000

# Execução distribuída
mpirun -np 16 --hostfile hostfile ./monte_carlo_pi 10000000

# Execução com diferentes configurações
mpirun -np 2 ./monte_carlo_pi 10000000
mpirun -np 8 ./monte_carlo_pi 100000000
```

### Usando o Makefile

```bash
# Compilar
make compile

# Testes rápidos
make test              # Teste básico
make test-scaling      # Teste de escalabilidade  
make test-precision    # Teste de precisão

# Verificar sistema
make check-mpi         # Verificar se MPI está instalado
make mpi-info          # Informações do sistema MPI

# Limpeza
make clean            # Remover arquivos gerados
```

### Resultados Esperados

**Saída do Programa**:
```
Calculando Pi usando Monte Carlo com MPI
Número de processos: 4
Pontos por processo: 250000
Total de pontos: 1000000

Processo 0: 196350 pontos dentro do círculo
Processo 1: 196428 pontos dentro do círculo  
Processo 2: 196502 pontos dentro do círculo
Processo 3: 196381 pontos dentro do círculo

Total de pontos dentro do círculo: 785661
Pi estimado: 3.142644
Pi real: 3.141593
Erro: 0.033%
Tempo de execução: 0.025 segundos
Speedup: 3.2x
Eficiência: 80%
```

### Vantagens da Solução MPI

1. **Escalabilidade**: Pode ser executado em múltiplas máquinas
2. **Flexibilidade**: Funciona em clusters e supercomputadores
3. **Portabilidade**: Padrão MPI é amplamente suportado
4. **Performance**: Distribuição eficiente do trabalho computacional

### Conceitos de MPI Demonstrados

- **SPMD** (Single Program, Multiple Data): Mesmo programa, dados diferentes
- **Decomposição de domínio**: Divisão do problema em partes independentes
- **Comunicação coletiva**: Uso eficiente de operações MPI
- **Sincronização**: Coordenação entre processos
- **Load balancing**: Distribuição equilibrada do trabalho

### Extensões Futuras

1. **MPI_Scatter/MPI_Gather**: Para distribuição mais sofisticada
2. **MPI_Isend/MPI_Irecv**: Comunicação não-bloqueante
3. **Múltiplos communicators**: Para hierarquias de processos
4. **MPI-IO**: Para escrita paralela de resultados

Este projeto fornece uma base sólida para compreender os conceitos fundamentais do MPI e sua aplicação em problemas de computação científica.

# Utilizando Docker Swarm com MPI Distribuído

Este projeto demonstra como executar um programa paralelo com MPI (Message Passing Interface) utilizando múltiplos containers Docker que atuam como nós de um cluster distribuído.

O cluster utiliza Docker Swarm para orquestração e pode ser facilmente escalado conforme a necessidade. Cada nó executa em um container separado com todas as dependências MPI configuradas.

## Arquitetura do Cluster

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Container 1   │    │   Container 2   │    │   Container N   │
│   (mpi-node-1)  │◄──►│   (mpi-node-2)  │◄──►│   (mpi-node-N)  │
│   Ubuntu + MPI  │    │   Ubuntu + MPI  │    │   Ubuntu + MPI  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲                       ▲                       ▲
         └───────────────────────┼───────────────────────┘
                          Docker Swarm
                        Rede Overlay (mpi-net)
```

## Configuração Rápida

### 1. Verificar dependências
```bash
make docker-check      # Verificar se Docker está instalado e funcionando
```

### 2. Construir e fazer deploy do cluster
```bash
make swarm-deploy      # Constrói imagem otimizada e faz deploy no Swarm
```

### 3. Verificar status do cluster
```bash
make swarm-status      # Ver status dos containers
```

### 4. Executar programa distribuído
```bash
make swarm-run         # Executar Monte Carlo Pi no cluster
```

## Imagem Docker Otimizada

O projeto utiliza uma **imagem Alpine Linux multi-stage** altamente otimizada:

### 🚀 **Vantagens da Otimização**

| Aspecto | Ubuntu Original | **Alpine Otimizada** | **Melhoria** |
|---------|-----------------|---------------------|--------------|
| **Tamanho** | ~180MB | **~60MB** | **🔥 67% menor** |
| **Build Time** | Lento | **Muito Rápido** | **⚡ 3x mais rápido** |
| **Segurança** | Média | **Alta** | **🛡️ Menor superfície de ataque** |
| **Recursos** | Altos | **Mínimos** | **💾 Menos CPU/RAM** |

### 🏗️ **Tecnologia Multi-stage**

A imagem utiliza build em **2 estágios**:

```dockerfile
# Estágio 1: Compilação (descartado)
FROM alpine:3.19 AS builder
# Instala ferramentas de build (gcc, g++, make)
# Compila o programa MPI

# Estágio 2: Runtime (imagem final)  
FROM alpine:3.19
# Instala apenas runtime MPI + SSH
# Copia apenas o binário compilado
```

**Resultado**: Imagem final contém apenas o necessário para executar, sem ferramentas de compilação.

## Comandos Detalhados

### Construção e Deploy
```bash
make docker-build      # Construir imagem otimizada
make swarm-init        # Inicializar Docker Swarm
make swarm-deploy      # Deploy completo (build + init + deploy)
```

### Operação do Cluster
```bash
make swarm-status      # Status dos serviços e containers
make swarm-test        # Testar conectividade entre nós
make swarm-run         # Executar programa MPI distribuído
make swarm-scale       # Escalar número de nós interativamente
```

### Limpeza
```bash
make swarm-cleanup     # Remover stack do Swarm
make clean            # Limpar arquivos locais
```

## Configuração Manual Avançada

### 1. Personalizar número de réplicas

Edite o arquivo `docker/docker-compose.yml`:
```yaml
services:
  mpi-node:
    # ... existing code ...
    deploy:
      replicas: 8  # Altere para o número desejado de nós
```

### 2. Executar comandos personalizados no cluster

Acesse um container:
```bash
# Listar containers
docker ps | grep mpi_stack

# Acessar container específico
docker exec -u mpiuser -it <container_name> bash

# Executar MPI personalizado
mpirun -np 16 --host mpi-node-1,mpi-node-2,... ./monte_carlo_pi 1000000000
```

### 3. Monitoramento do cluster

```bash
# Ver logs dos serviços
docker service logs mpi_stack_mpi-node

# Monitorar recursos
docker stats

# Inspecionar rede
docker network ls
docker network inspect mpi_stack_mpi-net
```

## Vantagens do Docker Swarm

1. **Facilidade de uso**: Deploy com um comando
2. **Escalabilidade**: Adicione/remova nós facilmente
3. **Isolamento**: Cada processo MPI roda em container isolado
4. **Portabilidade**: Funciona em qualquer ambiente com Docker
5. **Reprodutibilidade**: Ambiente idêntico em qualquer máquina
6. **Orquestração nativa**: Gerenciamento automático de containers

## Solução de Problemas

### Problema: Docker Swarm não inicializado
```bash
docker swarm init
```

### Problema: Containers não se comunicam
```bash
# Verificar rede overlay
docker network ls | grep overlay

# Testar conectividade
make swarm-test
```

### Problema: Imagem não encontrada
```bash
# Reconstruir imagem
make docker-build
```

### Problema: Stack não remove
```bash
# Forçar remoção
docker stack rm mpi_stack
docker system prune -f
```

## Comparação: Local vs Docker Swarm

| Aspecto | Execução Local | Docker Swarm |
|---------|----------------|--------------|
| Setup | Instalar MPI localmente | Docker + 1 comando |
| Escalabilidade | Limitada aos cores locais | Ilimitada (múltiplas máquinas) |
| Isolamento | Processos compartilham OS | Containers isolados |
| Portabilidade | Dependente do SO | Funciona em qualquer Docker |
| Overhead | Mínimo | Pequeno (containers) |
| Gerenciamento | Manual | Automático (Swarm) |

## Conceitos de MPI Demonstrados

- **SPMD** (Single Program, Multiple Data): Mesmo programa, dados diferentes
- **Decomposição de domínio**: Divisão do problema em partes independentes
- **Comunicação coletiva**: Uso eficiente de operações MPI
- **Sincronização**: Coordenação entre processos
- **Load balancing**: Distribuição equilibrada do trabalho
- **Cluster computing**: Execução em múltiplos nós físicos/virtuais

Este projeto fornece uma base sólida para compreender tanto os conceitos fundamentais do MPI quanto sua aplicação em ambientes containerizados e distribuídos. 