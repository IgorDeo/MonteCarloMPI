# Cluster MPI Híbrido: Local + AWS EC2

## Visão Geral

Este guia mostra como executar o programa Monte Carlo Pi distribuído entre sua máquina local e **1 instância EC2** da AWS, criando um cluster híbrido simples e econômico.

## 🚀 **Passo 1: Criar Instância EC2**

### Console AWS
```bash
# Tipo de instância recomendada
- Instance Type: t3.medium (2 vCPUs, 4GB RAM)
- AMI: Ubuntu 22.04 LTS
- Quantidade: 1 instância
- Key Pair: Criar nova ou usar existente
- Security Group: Permitir SSH (porta 22)
```

### Via AWS CLI
```bash
# Criar 1 instância EC2
aws ec2 run-instances \
    --image-id ami-0c02fb55956c7d316 \
    --count 1 \
    --instance-type t3.medium \
    --key-name mpi-cluster-key \
    --security-group-ids sg-xxxxxxxxx \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MPI-Node}]'
```

## 🔧 **Passo 2: Configurar a EC2**

### Conectar à instância
```bash
# Obter IP público
aws ec2 describe-instances --query 'Reservations[].Instances[].PublicIpAddress'

# Conectar via SSH
ssh -i ~/.ssh/mpi-cluster-key.pem ubuntu@<EC2-IP>
```

### Instalar MPI na EC2
```bash
# Na instância EC2
sudo apt update
sudo apt install -y openmpi-bin openmpi-common libopenmpi-dev
sudo apt install -y build-essential

# Verificar instalação
mpicc --version
mpirun --version
```

## 🔑 **Passo 3: Configurar SSH sem Senha**

### Na sua máquina local
```bash
# Gerar chave SSH (se não existir)
ssh-keygen -t rsa -b 2048

# Copiar chave pública para EC2
ssh-copy-id -i ~/.ssh/id_rsa.pub ubuntu@<EC2-IP>

# Testar conexão sem senha
ssh ubuntu@<EC2-IP> "echo 'EC2 OK'"
```

## 📁 **Passo 4: Transferir Programa**

### Compilar localmente
```bash
# Na sua máquina local
make compile

# Verificar se foi compilado estaticamente (para compatibilidade)
ldd build/monte_carlo_pi
```

### Transferir para EC2
```bash
# Copiar executável para EC2
scp build/monte_carlo_pi ubuntu@<EC2-IP>:~/

# Tornar executável
ssh ubuntu@<EC2-IP> "chmod +x monte_carlo_pi"
```

## 🌐 **Passo 5: Configurar Hostfile**

### Criar hostfile híbrido
```bash
# No diretório local do projeto
cat > examples/hostfile_aws << EOF
localhost slots=8
<EC2-IP> slots=2 user=ubuntu
EOF

# Exemplo com IP real
cat > examples/hostfile_aws << EOF
localhost slots=8
54.123.45.67 slots=2 user=ubuntu
EOF
```

## 🚀 **Passo 6: Executar Distribuído**

### Teste de conectividade
```bash
# Testar se ambas as máquinas respondem
mpirun --hostfile examples/hostfile_aws --np 2 hostname

# Resultado esperado:
# MacBook-Air-de-Igor.local
# ip-172-31-xx-xx
```

### Executar Monte Carlo distribuído
```bash
# 10 processos: 8 local + 2 na EC2
mpirun --hostfile examples/hostfile_aws --np 10 ./build/monte_carlo_pi 10000000

# Exemplo com menos processos
mpirun --hostfile examples/hostfile_aws --np 5 ./build/monte_carlo_pi 1000000
```

## 📊 **Exemplo de Execução**

### Comando
```bash
mpirun --hostfile examples/hostfile_aws --np 10 ./build/monte_carlo_pi 10000000
```

### Saída Esperada
```
==========================================
Calculando Pi usando Monte Carlo com MPI
==========================================
Número de processos: 10
Total de pontos: 10000000
Pontos por processo: 1000000

Processo 0: 785432 pontos dentro do círculo (MacBook local)
Processo 1: 785876 pontos dentro do círculo (MacBook local)
Processo 2: 785123 pontos dentro do círculo (MacBook local)
Processo 3: 785654 pontos dentro do círculo (MacBook local)
Processo 4: 785234 pontos dentro do círculo (MacBook local)
Processo 5: 785456 pontos dentro do círculo (MacBook local)
Processo 6: 785789 pontos dentro do círculo (MacBook local)
Processo 7: 785321 pontos dentro do círculo (MacBook local)
Processo 8: 785567 pontos dentro do círculo (EC2)
Processo 9: 785432 pontos dentro do círculo (EC2)

Total de pontos dentro do círculo: 7854884
Pi estimado: 3.141954
Tempo de execução: 1.234 segundos
==========================================
```

## 🔒 **Configurações de Segurança**

### Security Group EC2
```bash
# Regras necessárias
- SSH (22): Seu IP público
- Personalizada (1024-65535): Para comunicação MPI
- ICMP: Para ping/conectividade
```

### Firewall local (se necessário)
```bash
# macOS
sudo pfctl -d  # Desabilitar temporariamente

# Linux
sudo ufw allow from <EC2-IP>
```

## 💰 **Custos AWS**

### Estimativa de custo
```bash
# t3.medium em us-east-1
- $0.0416/hora por instância
- 1 instância = $0.0416/hora
- Teste de 1 hora ≈ $0.04
- Teste de 1 dia ≈ $1.00
```

### Dicas para economizar
```bash
# Parar instância quando não usar
aws ec2 stop-instances --instance-ids i-xxxxxxxxx

# Usar Spot Instances (até 90% desconto)
aws ec2 request-spot-instances --launch-specification file://spot-config.json
```

## 🐛 **Troubleshooting**

### Problemas comuns

#### 1. **Timeout de conexão**
```bash
# Verificar Security Groups
# Testar conectividade
ping <EC2-IP>
telnet <EC2-IP> 22
```

#### 2. **Programa não encontrado**
```bash
# Verificar se programa está no caminho correto
ssh ubuntu@<EC2-IP> "ls -la monte_carlo_pi"
```

#### 3. **Diferentes versões MPI**
```bash
# Compilar estaticamente ou usar mesmo MPI
mpicc --version  # Local
ssh ubuntu@<EC2-IP> "mpicc --version"  # Remote
```

#### 4. **Firewall bloqueando**
```bash
# Debug verboso
export OMPI_MCA_btl_base_verbose=1
mpirun --hostfile hostfile_aws --np 2 hostname
```

## 📈 **Análise de Performance**

### Cluster Híbrido (Local + 1 EC2)
```
┌─────────────────┐    ┌─────────────────┐
│   Sua Máquina   │    │     EC2-1       │
│   (macOS)       │    │   (Ubuntu)      │
│   8 slots       │◄──►│   2 slots       │
│                 │    │                 │
└─────────────────┘    └─────────────────┘
```

### Fatores que afetam performance
1. **Latência de rede**: Internet vs LAN (~50-200ms)
2. **Largura de banda**: Upload/download da sua conexão
3. **Localização EC2**: Região AWS mais próxima
4. **Tipo de instância**: vCPUs, memória

### Benchmark de rede
```bash
# Entre local e EC2
ping <EC2-IP>
mpirun --host localhost,<EC2-IP> --np 2 ./network_benchmark
```

## 🎯 **Vantagens do Cluster Híbrido Simples**

1. **Custo baixo**: ~$0.04/hora
2. **Fácil configuração**: Apenas 1 EC2
3. **Demonstração clara**: Conceito MPI distribuído
4. **Escalabilidade**: Pode adicionar mais EC2s depois

## 🚀 **Comandos Rápidos**

### Configuração completa
```bash
make aws-setup
```

### Execução
```bash
# Teste básico
make aws-test

# Execução completa
mpirun --hostfile examples/hostfile_aws --np 10 ./build/monte_carlo_pi 10000000
```

### Limpeza
```bash
make aws-cleanup
```

## 📊 **Performance Esperada**

### Escalabilidade
- **Local (8 cores)**: Baseline
- **Local + EC2 (10 cores)**: ~1.2x speedup
- **Limitação**: Latência de rede Internet

### Exemplo de tempos
```bash
# Local apenas (8 processos)
Time: 2.5 segundos

# Híbrido (10 processos: 8 local + 2 EC2)  
Time: 2.1 segundos (pequeno ganho devido à latência)
```

Este setup demonstra perfeitamente o conceito de MPI distribuído com custo mínimo! 