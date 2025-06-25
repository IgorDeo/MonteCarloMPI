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

# Utilizando Docker com MPI Distribuído
Este projeto demonstra como executar um programa paralelo com MPI (Message Passing Interface) utilizando quatro containers Docker que atuam como nós de um cluster.

Os containers são definidos no docker-compose.yml e compartilham uma mesma rede Docker personalizada (mpi-net), permitindo que se comuniquem diretamente pelos nomes de host (mpi-node1, mpi-node2, etc.). Cada container é configurado com:

- OpenSSH Server para permitir acesso remoto via SSH.

- MPICH (implementação do MPI).

- Um usuário comum (mpiuser) com autenticação via chave SSH para permitir comunicação sem senha entre os nós.

## 1. Build da imagem
Para construir a imagem base utilizada pelos nós, rode o comando `docker-compose build`. Isso criará os containers com todas as dependências do MPI e SSH.

## 2 Mudar para o usuário mpiuser

Para facilitar os testes de conectividade SSH entre os containers, utilize o usuário mpiuser, que já está configurado com as chaves públicas e senha padrão mpiuser.

Acesse o terminal do container mpi-node1 e mude para o usuário:

```bash
docker exec -it mpi-node1 bash
su - mpiuser
```

Com isso, todos os testes seguintes (como ping, ssh e mpirun) devem ser executados a partir desse usuário.

## 3. Testar conectividade e SSH de mpi-node1 para os outros nós

### 3.1 Verificar conectividade via ping

```bash
for host in mpi-node1 mpi-node2 mpi-node3 mpi-node4; do
  echo "Pingando $host..."
  ping -c 1 -W 1 $host && echo "Ping OK" || echo "Ping falhou"
done
```
Isso confirma que todos os nós estão acessíveis pela rede Docker.

### 3.2 Testar conexão SSH
O comando abaixo tenta conectar via SSH a partir de mpi-node1 e evita o prompt interativo da primeira conexão:

```bash
for host in mpi-node1 mpi-node2 mpi-node3 mpi-node4; do
  echo "Testando SSH em $host..."
  ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 mpiuser@$host "echo 'Conexão bem sucedida a $host'" || echo "Falha SSH em $host"
done
```

Com isso os hosts também são adicionados ao `known_hosts`, permitindo executar o MPI distribuído.

## 4. Executar o MPI distribuído
Uma vez que os testes de rede e SSH estejam funcionando:

```bash
mpirun -np 4 --host mpi-node1,mpi-node2,mpi-node3,mpi-node4 /home/mpiuser/monte_carlo_pi 1000000000
```
Esse comando executa o programa monte_carlo_pi de forma distribuída nos 4 nós.

# 🌥️ **Cluster Híbrido AWS (Avançado)**

Pode executar seu programa distribuído entre **sua máquina local e 1 instância EC2** na nuvem!

### Configuração Rápida
```bash
# 1. Instalar AWS CLI e configurar
pip install awscli
aws configure

# 2. Configurar cluster automaticamente
make aws-setup

# 3. Executar distribuído (10 processos: 8 local + 2 EC2)
make aws-run
```

### Arquitetura do Cluster
```
┌─────────────────┐    ┌─────────────────┐
│   Sua Máquina   │    │     EC2-1       │
│   (macOS)       │    │   (Ubuntu)      │
│   8 slots       │◄──►│   2 slots       │
│                 │    │                 │
└─────────────────┘    └─────────────────┘
```

### Custo Estimado
- **1 instância t3.medium**: ~$0.04/hora
- **Teste de 1 dia**: ~$1.00
- **Muito econômico** para demonstração de MPI distribuído

### Comandos Úteis
```bash
make aws-check      # Verificar dependências
make aws-setup      # Configurar cluster completo
make aws-test       # Testar conectividade
make aws-run        # Executar programa distribuído
make aws-cleanup    # Terminar instância EC2
```

> 📖 **Manual completo**: `docs/aws_cluster_setup.md` 