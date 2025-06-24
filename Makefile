# Makefile para o projeto Monte Carlo Pi com MPI
# Compilação, execução e limpeza automatizadas

# Configurações do compilador
CC = mpicc
CFLAGS = -O3 -Wall -std=c99
LDFLAGS = -lm
TARGET = build/monte_carlo_pi
SRCDIR = src
SOURCE = $(SRCDIR)/monte_carlo_pi.c
BUILDDIR = build
RESULTSDIR = results

# Regra padrão
all: $(TARGET)

# Criar diretório de build
$(BUILDDIR):
	mkdir -p $(BUILDDIR)

# Criar diretório de resultados
$(RESULTSDIR):
	mkdir -p $(RESULTSDIR)

# Compilar o programa
$(TARGET): $(SOURCE) $(BUILDDIR)
	@echo "Compilando Monte Carlo Pi com MPI..."
	$(CC) $(CFLAGS) -o $(TARGET) $(SOURCE) $(LDFLAGS)
	@echo "✓ Compilação concluída: $(TARGET)"

# Regra para compilar
compile: $(TARGET)

# Regra para executar teste rápido
test: $(TARGET) $(RESULTSDIR)
	@echo "Executando teste rápido..."
	mpirun -np 4 $(TARGET) 100000

# Regra para executar testes completos
test-full: $(TARGET) $(RESULTSDIR)
	@echo "Executando testes completos..."
	./scripts/run.sh

# Regra para executar com diferentes configurações
test-scaling: $(TARGET) $(RESULTSDIR)
	@echo "Teste de escalabilidade..."
	@echo "1 processo:"
	mpirun -np 1 $(TARGET) 1000000
	@echo "\n2 processos:"
	mpirun -np 2 $(TARGET) 1000000
	@echo "\n4 processos:"
	mpirun -np 4 $(TARGET) 1000000
	@echo "\n8 processos:"
	mpirun -np 8 $(TARGET) 1000000

# Regra para executar com diferentes números de pontos
test-precision: $(TARGET) $(RESULTSDIR)
	@echo "Teste de precisão..."
	@echo "100K pontos:"
	mpirun -np 4 $(TARGET) 100000
	@echo "\n1M pontos:"
	mpirun -np 4 $(TARGET) 1000000
	@echo "\n10M pontos:"
	mpirun -np 4 $(TARGET) 10000000

# ==================== AWS CLUSTER ====================

# Configurar cluster AWS automaticamente
aws-setup: $(TARGET)
	@echo "Configurando cluster MPI híbrido (Local + AWS EC2)..."
	./scripts/setup_aws_cluster.sh setup

# Menu interativo para AWS
aws-menu: $(TARGET)
	@echo "Abrindo menu de configuração AWS..."
	./scripts/setup_aws_cluster.sh

# Testar cluster AWS existente
aws-test: $(TARGET)
	@if [ -f examples/hostfile_aws ]; then \
		echo "Testando cluster AWS..."; \
		mpirun --hostfile examples/hostfile_aws --np 2 hostname; \
		echo "\nExecutando Monte Carlo distribuído..."; \
		mpirun --hostfile examples/hostfile_aws --np 5 $(TARGET) 1000000; \
	else \
		echo "❌ Hostfile AWS não encontrado. Execute 'make aws-setup' primeiro."; \
	fi

# Executar programa no cluster AWS
aws-run: $(TARGET)
	@if [ -f examples/hostfile_aws ]; then \
		echo "Executando no cluster AWS (10 processos: 8 local + 2 EC2, 10M pontos)..."; \
		mpirun --hostfile examples/hostfile_aws --np 10 $(TARGET) 10000000; \
	else \
		echo "❌ Hostfile AWS não encontrado. Execute 'make aws-setup' primeiro."; \
	fi

# Limpar recursos AWS
aws-cleanup:
	@echo "Terminando instância EC2..."
	./scripts/setup_aws_cluster.sh cleanup

# Verificar dependências AWS
aws-check:
	@echo "Verificando dependências AWS..."
	@which aws > /dev/null && echo "✓ AWS CLI encontrado" || echo "✗ AWS CLI não encontrado - instale com: pip install awscli"
	@aws sts get-caller-identity > /dev/null 2>&1 && echo "✓ AWS CLI configurado" || echo "✗ AWS CLI não configurado - execute: aws configure"
	@which ssh > /dev/null && echo "✓ SSH disponível" || echo "✗ SSH não encontrado"

# ==================== GERAL ====================

# Limpar arquivos gerados
clean:
	rm -rf $(BUILDDIR)
	rm -rf $(RESULTSDIR)
	@echo "Arquivos limpos."

# Verificar se MPI está instalado
check-mpi:
	@which mpicc > /dev/null && echo "✓ mpicc encontrado" || echo "✗ mpicc não encontrado - instale OpenMPI"
	@which mpirun > /dev/null && echo "✓ mpirun encontrado" || echo "✗ mpirun não encontrado - instale OpenMPI"

# Instalar dependências (Ubuntu/Debian)
install-deps-ubuntu:
	sudo apt-get update
	sudo apt-get install -y libopenmpi-dev openmpi-bin

# Instalar dependências (macOS)
install-deps-macos:
	brew install open-mpi

# Mostrar informações sobre o sistema MPI
mpi-info:
	@echo "Informações do sistema MPI:"
	@echo "=========================="
	@which mpicc && mpicc --version | head -1
	@which mpirun && echo "mpirun disponível"
	@echo "Número de cores: $$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 'desconhecido')"

# Ajuda
help:
	@echo "Makefile para Monte Carlo Pi com MPI"
	@echo "====================================="
	@echo "Alvos disponíveis:"
	@echo ""
	@echo "COMPILAÇÃO E TESTES LOCAIS:"
	@echo "  all          - Compilar o programa (padrão)"
	@echo "  compile      - Compilar o programa"
	@echo "  test         - Teste rápido (4 processos, 100K pontos)"
	@echo "  test-full    - Executar todos os testes"
	@echo "  test-scaling - Teste de escalabilidade"
	@echo "  test-precision - Teste de precisão"
	@echo ""
	@echo "CLUSTER AWS (Local + EC2):"
	@echo "  aws-setup    - Configurar cluster AWS automaticamente"
	@echo "  aws-menu     - Menu interativo para AWS"
	@echo "  aws-test     - Testar cluster AWS existente"
	@echo "  aws-run      - Executar programa no cluster AWS"
	@echo "  aws-cleanup  - Terminar instâncias EC2"
	@echo "  aws-check    - Verificar dependências AWS"
	@echo ""
	@echo "SISTEMA:"
	@echo "  clean        - Limpar arquivos gerados"
	@echo "  check-mpi    - Verificar instalação do MPI"
	@echo "  mpi-info     - Informações do sistema MPI"
	@echo "  help         - Mostrar esta ajuda"
	@echo ""
	@echo "DEPENDÊNCIAS:"
	@echo "  install-deps-ubuntu - Instalar MPI no Ubuntu/Debian"
	@echo "  install-deps-macos  - Instalar MPI no macOS"
	@echo ""
	@echo "USO MANUAL:"
	@echo "  Local:       mpirun -np <processos> ./$(TARGET) <pontos>"
	@echo "  Distribuído: mpirun --hostfile examples/hostfile_aws -np <processos> ./$(TARGET) <pontos>"
	@echo ""
	@echo "EXEMPLOS:"
	@echo "  make test                    # Teste rápido local"
	@echo "  make aws-setup              # Configurar cluster AWS"
	@echo "  make aws-run                # Executar no cluster AWS"
	@echo "  mpirun -np 8 ./$(TARGET) 10000000  # Manual local"

.PHONY: all compile test test-full test-scaling test-precision clean check-mpi install-deps-ubuntu install-deps-macos mpi-info help aws-setup aws-menu aws-test aws-run aws-cleanup aws-check 