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

# ==================== DOCKER CONTAINERS ====================

# Construir imagem Docker otimizada (Alpine Multi-stage)
docker-build: $(TARGET)
	@echo "Construindo imagem Docker MPI otimizada (Alpine Multi-stage)..."
	docker build -t mpi-node:latest -f ./Dockerfile .

# Verificar dependências do Docker
docker-check:
	@echo "Verificando dependências do Docker..."
	./scripts/run_docker.sh check

# Fazer deploy com containers MPI
docker-deploy: $(TARGET)
	@echo "Fazendo deploy com containers MPI..."
	./scripts/run_docker.sh deploy

# Verificar status dos containers
docker-status:
	@echo "Status dos containers MPI:"
	./scripts/run_docker.sh status

# Executar teste de conectividade
docker-test:
	@echo "Testando conectividade..."
	./scripts/run_docker.sh test

# Executar programa MPI distribuído
docker-run:
	@echo "Executando Monte Carlo Pi nos containers..."
	./scripts/run_docker.sh run

# Escalar o número de containers
docker-scale:
	@echo "Escalando containers MPI..."
	./scripts/run_docker.sh scale

# Menu interativo
docker-menu:
	@echo "Abrindo menu interativo..."
	./scripts/run_docker.sh menu

# Limpar containers
docker-cleanup:
	@echo "Removendo containers MPI..."
	./scripts/run_docker.sh cleanup

# Visualizar logs
docker-logs:
	@echo "Logs dos containers MPI:"
	./scripts/run_docker.sh logs

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
	@echo "DOCKER CONTAINERS (Distribuído):"
	@echo "  docker-build  - Construir imagem Docker otimizada"
	@echo "  docker-deploy - Deploy com containers MPI"
	@echo "  docker-status - Verificar status dos containers"
	@echo "  docker-test   - Testar conectividade"
	@echo "  docker-run    - Executar programa nos containers"
	@echo "  docker-scale  - Escalar número de containers"
	@echo "  docker-menu   - Menu interativo"
	@echo "  docker-logs   - Ver logs dos containers"
	@echo "  docker-cleanup - Remover containers"
	@echo "  docker-check  - Verificar dependências do Docker"
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
	@echo "  Docker:      make docker-deploy && make docker-run"
	@echo ""
	@echo "EXEMPLOS:"
	@echo "  make test                    # Teste rápido local"
	@echo "  make docker-build           # Construir imagem otimizada"
	@echo "  make docker-deploy           # Deploy cluster Docker"
	@echo "  make docker-run              # Executar no cluster"
	@echo "  make docker-menu             # Menu interativo"
	@echo "  ./scripts/run_docker.sh menu # Script direto"
	@echo "  mpirun -np 8 ./$(TARGET) 10000000  # Manual local"

.PHONY: all compile test test-full test-scaling test-precision clean check-mpi install-deps-ubuntu install-deps-macos mpi-info help docker-build docker-deploy docker-status docker-test docker-run docker-scale docker-menu docker-cleanup docker-logs 