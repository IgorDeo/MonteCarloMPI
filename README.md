# Projeto MPI: Cálculo de Pi usando Monte Carlo

## 📋 Descrição do Projeto

Este projeto implementa o cálculo do valor de Pi (π) utilizando o método Monte Carlo com programação paralela através do MPI (Message Passing Interface). O projeto oferece duas formas de execução:

1. **Execução Local**: Usando MPI instalado diretamente no sistema
2. **Execução Distribuída**: Usando containers Docker para simular um cluster

### 🎯 Método Monte Carlo para Cálculo de Pi

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

## 🏗️ Estrutura do Projeto

```
/
├── README.md              # Documentação completa
├── Makefile              # Comandos automatizados
├── Dockerfile        # Imagem Alpine otimizada (36.3MB)
├── src/
│   ├── monte_carlo_pi.c   # Programa principal MPI
│   └── utils.h            # Funções utilitárias
├── scripts/
│   ├── compile.sh         # Script de compilação
│   ├── run.sh            # Script de execução local
│   └── run_docker.sh     # Script para containers Docker
```

## 🚀 Execução Rápida

### Opção 1: Execução Local (MPI no Sistema)

```bash
# Compilar e testar
make test

# Testes com diferentes configurações
make test-scaling      # Teste de escalabilidade
make test-precision    # Teste de precisão
```

### Opção 2: Execução com Docker (Recomendado)

```bash
# 1. Deploy dos containers
make docker-deploy

# 2. Executar cálculo distribuído
make docker-run

# 3. Limpar quando terminar
make docker-cleanup
```

## 🐳 Execução com Docker Containers

### Vantagens da Solução Docker

- ✅ **Imagem Ultra-Otimizada**: Alpine Linux (36.3MB - 94% menor que Ubuntu)
- ✅ **Isolamento Completo**: Cada processo roda em container separado
- ✅ **Portabilidade Total**: Funciona em qualquer sistema com Docker
- ✅ **Setup Automático**: Um comando faz todo o deploy
- ✅ **Escalabilidade Fácil**: Ajuste o número de containers dinamicamente

### Comandos Docker Disponíveis

| Comando | Descrição |
|---------|-----------|
| `make docker-build` | Construir imagem otimizada |
| `make docker-deploy` | Deploy dos containers MPI |
| `make docker-run` | Executar programa distribuído |
| `make docker-status` | Ver status dos containers |
| `make docker-scale` | Escalar número de containers |
| `make docker-menu` | Menu interativo completo |
| `make docker-cleanup` | Limpar containers |

### Menu Interativo Docker

Para uma experiência mais amigável:

```bash
make docker-menu
```

Isso abrirá um menu completo:

```
===============================================
    MPI Distribuído com Docker Containers
===============================================
1. Verificar dependências
2. Construir imagem otimizada  
3. Deploy dos containers
4. Verificar status dos containers
5. Testar conectividade
6. Executar programa MPI
7. Escalar containers
8. Ver logs
9. Limpar containers
0. Sair
===============================================
```

### Execução Personalizada

```bash
# Deploy com número específico de containers
./scripts/run_docker.sh deploy 4

# Executar com parâmetros personalizados
./scripts/run_docker.sh run 8 1000000    # 8 processos, 1M pontos
./scripts/run_docker.sh run 16 50000000  # 16 processos, 50M pontos

# Escalar para mais containers
./scripts/run_docker.sh scale 12
```

## 💻 Execução Local (MPI Nativo)

### Instalação das Dependências

**Ubuntu/Debian:**
```bash
make install-deps-ubuntu
```

**macOS:**
```bash
make install-deps-macos
```

**Verificar instalação:**
```bash
make check-mpi
make mpi-info
```

### Comandos de Execução Local

```bash
# Compilação
make compile

# Testes básicos
make test              # Teste rápido (4 processos, 100K pontos)
make test-scaling      # Teste de escalabilidade (1,2,4,8 processos)
make test-precision    # Teste de precisão (100K, 1M, 10M pontos)

# Execução manual
mpirun -np 4 ./build/monte_carlo_pi 1000000
mpirun -np 8 ./build/monte_carlo_pi 10000000
```

### Execução Distribuída (Múltiplas Máquinas)

Para executar em múltiplas máquinas físicas:

```bash
# 1. Configurar SSH sem senha entre máquinas
ssh-keygen -t rsa
ssh-copy-id user@machine2
ssh-copy-id user@machine3

# 2. Criar arquivo hostfile
echo "machine1 slots=8" > hostfile
echo "machine2 slots=4" >> hostfile  
echo "machine3 slots=16" >> hostfile

# 3. Executar distribuído
mpirun -np 28 --hostfile hostfile ./build/monte_carlo_pi 100000000
```

## 📊 Resultados e Performance

### Exemplo de Saída

```
==========================================
Calculando Pi usando Monte Carlo com MPI
==========================================
Número de processos: 8
Total de pontos: 10000000
Pontos por processo: 1250000
------------------------------------------
Processo 0: 981976 pontos dentro do círculo (de 1250000 pontos)
Processo 1: 981311 pontos dentro do círculo (de 1250000 pontos)
Processo 2: 981706 pontos dentro do círculo (de 1250000 pontos)
Processo 3: 982444 pontos dentro do círculo (de 1250000 pontos)
Processo 4: 981970 pontos dentro do círculo (de 1250000 pontos)
Processo 5: 980772 pontos dentro do círculo (de 1250000 pontos)
Processo 6: 981788 pontos dentro do círculo (de 1250000 pontos)
Processo 7: 981803 pontos dentro do círculo (de 1250000 pontos)
------------------------------------------
RESULTADOS FINAIS:
Total de pontos dentro do círculo: 7853770
Pi estimado: 3.141508
Pi real: 3.141593
Erro absoluto: 0.000085
Erro percentual: 0.003%
Tempo de execução: 0.044737 segundos
------------------------------------------
```

## 🔬 Conceitos MPI Demonstrados

### Funcionalidades MPI Utilizadas

1. **Inicialização e Finalização**
   ```c
   MPI_Init(&argc, &argv)     // Inicializar ambiente MPI
   MPI_Finalize()             // Finalizar ambiente MPI
   ```

2. **Identificação de Processos**
   ```c
   MPI_Comm_rank(MPI_COMM_WORLD, &rank)  // ID do processo
   MPI_Comm_size(MPI_COMM_WORLD, &size)  // Total de processos
   ```

3. **Sincronização**
   ```c
   MPI_Barrier(MPI_COMM_WORLD)  // Sincronizar todos os processos
   ```

4. **Operações Coletivas**
   ```c
   MPI_Reduce()  // Redução para somar pontos dentro do círculo
   ```

5. **Medição de Tempo**
   ```c
   MPI_Wtime()  // Medição precisa de tempo para análise
   ```

### Arquitetura Paralela

**Estratégia SPMD (Single Program, Multiple Data):**
- **Todos os processos**: Executam o mesmo programa com dados diferentes
- **Distribuição**: Cada processo calcula N/P pontos (N=total, P=processos)
- **Agregação**: MPI_Reduce soma todos os resultados locais

### Padrões de Paralelização

1. **Decomposição de Domínio**: Problema dividido em partes independentes
2. **Load Balancing**: Trabalho distribuído uniformemente
3. **Comunicação Coletiva**: Uso eficiente de MPI_Reduce
4. **Sincronização**: Coordenação entre processos com MPI_Barrier

## 🏗️ Detalhes Técnicos

### Imagem Docker Otimizada

A imagem Docker utiliza **Alpine Linux Multi-stage** para máxima otimização:

```dockerfile
# Estágio 1: Build (descartado após compilação)
FROM alpine:3.19 AS builder
RUN apk add --no-cache openmpi-dev gcc g++ make libc-dev
COPY src/ /tmp/
RUN mpicc /tmp/monte_carlo_pi.c -o /tmp/monte_carlo_pi -lm

# Estágio 2: Runtime (imagem final)
FROM alpine:3.19  
RUN apk add --no-cache openmpi openssh-server openssh-client bash
COPY --from=builder /tmp/monte_carlo_pi /home/mpiuser/
# ... configurações SSH e usuário
```

**Vantagens:**
- **Tamanho**: 36.3MB (94% menor que Ubuntu)
- **Segurança**: Menor superfície de ataque
- **Performance**: Menos overhead, mais rápido
- **Portabilidade**: Funciona em qualquer Docker

### Algoritmo Detalhado

#### Algoritmo SPMD (Single Program, Multiple Data):
1. **Todos os processos** executam o mesmo código
2. **Inicialização**: MPI_Init, obter rank e size
3. **Distribuição**: Cada processo calcula pontos_totais/num_processos
4. **Sincronização**: MPI_Barrier para medição precisa de tempo
5. **Simulação**: Cada processo executa Monte Carlo independentemente
6. **Agregação**: MPI_Reduce soma resultados de todos os processos
7. **Resultado**: Processo rank 0 calcula Pi final e exibe resultados
8. **Finalização**: MPI_Finalize em todos os processos

### Geração de Números Aleatórios

O programa utiliza gerador congruencial linear com:
- **Semente única por processo**: Baseada no rank MPI
- **Período longo**: Evita repetição de sequências
- **Distribuição uniforme**: Garante cobertura adequada do espaço

## 🧪 Testes e Validação

### Suíte de Testes Automatizada

```bash
# Teste básico de funcionamento
make test

# Análise de escalabilidade
make test-scaling
# Testa com 1, 2, 4, 8 processos para medir speedup

# Análise de precisão  
make test-precision
# Testa com 100K, 1M, 10M pontos para medir convergência
```

### Validação dos Resultados

**Critérios de Validação:**
- Erro percentual < 1% para 1M+ pontos
- Speedup próximo ao número de processos
- Eficiência > 80% até 8 processos
- Convergência para Pi com mais pontos

## 🔧 Solução de Problemas

### Problemas Comuns

**1. "mpicc not found"**
```bash
# Ubuntu/Debian
sudo apt-get install libopenmpi-dev openmpi-bin

# macOS  
brew install open-mpi
```

**2. "Docker não encontrado"**
```bash
# Instalar Docker Desktop
# Verificar se está rodando
docker --version
make docker-check
```

**3. "Permission denied" nos scripts**
```bash
chmod +x scripts/*.sh
```

**4. Containers não inicializam**
```bash
# Limpar ambiente
make docker-cleanup
docker system prune -f

# Tentar novamente
make docker-deploy
```

### Debugging

```bash
# Ver logs detalhados dos containers
make docker-logs

# Verificar status
make docker-status

# Testar conectividade
make docker-test

# Executar comandos dentro do container
docker exec -it mpi-node-1 bash
```

## 📈 Extensões Futuras

### Melhorias Possíveis

1. **MPI Avançado**
   - MPI_Scatter/MPI_Gather para distribuição mais sofisticada
   - MPI_Isend/MPI_Irecv para comunicação não-bloqueante
   - Múltiplos communicators para hierarquias

2. **Algoritmos**
   - Outros métodos Monte Carlo (integração, otimização)
   - Algoritmos determinísticos para comparação
   - Análise estatística mais robusta

3. **Infraestrutura**
   - Kubernetes para orquestração em produção
   - Monitoramento com Prometheus/Grafana
   - CI/CD para testes automatizados

4. **Interface**
   - Web dashboard para visualização
   - API REST para execução remota
   - Gráficos de convergência em tempo real

## 📚 Recursos Adicionais

### Comandos de Referência Rápida

```bash
# EXECUÇÃO LOCAL
make test                    # Teste básico
make test-scaling           # Análise de performance
mpirun -np 8 ./build/monte_carlo_pi 10000000

# EXECUÇÃO DOCKER  
make docker-deploy          # Setup completo
make docker-run             # Executar distribuído
make docker-menu            # Interface interativa
./scripts/run_docker.sh run 16 100000000

# UTILITÁRIOS
make clean                  # Limpar arquivos
make check-mpi             # Verificar MPI
make mpi-info              # Info do sistema
make help                  # Ajuda completa
```

### Parâmetros Recomendados

| Cenário | Processos | Pontos | Tempo Aprox |
|---------|-----------|--------|-------------|
| Teste Rápido | 4 | 100K | < 1s |
| Desenvolvimento | 8 | 1M | ~1s |
| Benchmark | 16 | 10M | ~10s |
| Produção | 32 | 100M+ | ~60s+ |

---

## 🎯 Conclusão

Este projeto demonstra conceitos fundamentais de:
- **Programação Paralela** com MPI
- **Métodos Monte Carlo** para computação científica  
- **Containerização** com Docker
- **Otimização de Performance** em sistemas distribuídos

**Ideal para:** Estudantes de computação paralela, desenvolvedores interessados em MPI, e profissionais que trabalham com simulações numéricas.

**Tecnologias:** C, MPI, Docker, Alpine Linux, Shell Script, Makefile 