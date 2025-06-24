# MPI: Distribuído em Rede vs Execução Local

## Visão Geral

O **MPI (Message Passing Interface)** foi projetado especificamente para **computação distribuída** em múltiplas máquinas conectadas em rede. Não é limitado a threads ou execução local.

## 🔄 **MPI vs Threads**

### MPI (Message Passing)
- ✅ **Processos independentes** (não threads)
- ✅ **Memória distribuída** (cada processo tem sua própria memória)
- ✅ **Comunicação via mensagens**
- ✅ **Escalável para clusters e supercomputadores**
- ✅ **Funciona em múltiplas máquinas**

### Threads (OpenMP/pthreads)
- 🔄 **Threads compartilham memória**
- 🔄 **Limitado a uma única máquina**
- 🔄 **Comunicação via memória compartilhada**
- 🔄 **Mais simples, mas menos escalável**

## 🌐 **Configuração MPI Distribuído**

### 1. **Execução Local (Single Node)**
```bash
# Executando em uma máquina (8 cores)
mpirun -np 8 ./programa

# O que acontece:
# - 8 processos MPI na mesma máquina
# - Cada processo em um núcleo diferente
# - Comunicação via memória compartilhada (mais rápida)
```

### 2. **Execução Distribuída (Multi-Node)**

#### Arquivo de Hosts (`hostfile`)
```bash
# Criar arquivo com lista de máquinas
echo "192.168.1.10 slots=4" > hostfile
echo "192.168.1.11 slots=4" >> hostfile
echo "192.168.1.12 slots=8" >> hostfile

# Executar em múltiplas máquinas
mpirun -np 16 --hostfile hostfile ./programa
```

#### Configuração SSH (sem senha)
```bash
# Gerar chave SSH (se não existir)
ssh-keygen -t rsa -b 2048

# Copiar chave para máquinas remotas
ssh-copy-id user@192.168.1.10
ssh-copy-id user@192.168.1.11
ssh-copy-id user@192.168.1.12

# Testar conexão
ssh user@192.168.1.10 "echo 'Conexão OK'"
```

#### Exemplo de Execução Distribuída
```bash
# 16 processos distribuídos em 3 máquinas
mpirun -np 16 \
       --host 192.168.1.10,192.168.1.11,192.168.1.12 \
       ./monte_carlo_pi 10000000

# Ou usando hostfile
mpirun -np 16 --hostfile hostfile ./monte_carlo_pi 10000000
```

## 🏗️ **Arquiteturas Suportadas**

### 1. **Single Machine (SMP)**
- Múltiplos processos em uma máquina
- Comunicação via memória compartilhada
- Ideal para desenvolvimento e testes

### 2. **Cluster (Distributed Memory)**
- Múltiplas máquinas conectadas por rede
- Comunicação via rede (Ethernet, InfiniBand)
- Escalável para milhares de nós

### 3. **Hybrid (MPI + OpenMP)**
- MPI entre nós, OpenMP dentro de cada nó
- Combina vantagens de ambos os modelos
- Comum em supercomputadores modernos

## 🔧 **Configuração Prática**

### Verificar Capacidades do Sistema
```bash
# Número de cores por máquina
sysctl -n hw.ncpu  # macOS
nproc              # Linux

# Informações sobre alocação MPI
mpirun --display-allocation --np 4 hostname

# Mapear processos para cores
mpirun --display-map --np 8 hostname
```

### Teste de Conectividade
```bash
# Testar MPI em múltiplas máquinas (exemplo)
mpirun --host localhost,remote-host --np 4 hostname

# Verificar latência de rede
mpirun --host host1,host2 --np 2 ./benchmark_latencia
```

## 📊 **Performance: Local vs Distribuído**

### Comunicação Local (Intra-node)
- **Latência**: ~1-10 microsegundos
- **Bandwidth**: ~10-100 GB/s
- **Mecanismo**: Memória compartilhada, pipes

### Comunicação Distribuída (Inter-node)
- **Latência**: ~1-100 milissegundos
- **Bandwidth**: ~1-100 GB/s (depende da rede)
- **Mecanismo**: TCP/IP, InfiniBand, Omni-Path

## 🌟 **Vantagens do MPI Distribuído**

1. **Escalabilidade Massiva**
   - Milhares de nós
   - Milhões de cores
   - Petabytes de memória

2. **Tolerância a Falhas**
   - Isolamento de processos
   - Falha de um nó não afeta outros

3. **Flexibilidade**
   - Heterogeneidade de hardware
   - Diferentes arquiteturas

4. **Padrão Industrial**
   - Usado em TOP500 supercomputers
   - Bibliotecas otimizadas (Intel MPI, MVAPICH)

## 🚀 **Exemplo: Cluster Caseiro**

### Configuração com Raspberry Pi
```bash
# 4 Raspberry Pi conectados por Wi-Fi
# hostfile
pi1 slots=4
pi2 slots=4  
pi3 slots=4
pi4 slots=4

# Executar Monte Carlo distribuído
mpirun -np 16 --hostfile hostfile ./monte_carlo_pi 100000000
```

### Configuração com Docker
```bash
# Criar cluster MPI com Docker
docker-compose up mpi-cluster

# Executar programa distribuído
docker exec mpi-master mpirun --hostfile /etc/hostfile \
                              -np 8 ./monte_carlo_pi 10000000
```

## 🔍 **Debugging Distribuído**

### Variáveis de Ambiente Úteis
```bash
export OMPI_DEBUG=1                    # Debug geral
export OMPI_DEBUG_VERBOSE=1            # Verbose
export OMPI_MCA_btl_base_verbose=1     # Comunicação
export OMPI_MCA_plm_base_verbose=1     # Process management
```

### Comandos de Diagnóstico
```bash
# Verificar conectividade
mpirun --host host1,host2 --np 2 hostname

# Testar largura de banda
mpirun --host host1,host2 --np 2 ./mpi_bandwidth_test

# Verificar latência
mpirun --host host1,host2 --np 2 ./mpi_latency_test
```

## 📝 **Resumo**

| Aspecto | Local (SMP) | Distribuído (Cluster) |
|---------|-------------|----------------------|
| **Máquinas** | 1 | Múltiplas |
| **Memória** | Compartilhada | Distribuída |
| **Comunicação** | Rápida | Rede (mais lenta) |
| **Escalabilidade** | Limitada | Massiva |
| **Complexidade** | Baixa | Alta |
| **Casos de Uso** | Desenvolvimento | Produção científica |

**Conclusão**: MPI pode e deve ser usado tanto localmente quanto distribuído. Sua verdadeira força está na capacidade de escalar para clusters e supercomputadores, permitindo resolver problemas computacionalmente intensivos que não caberiam em uma única máquina. 