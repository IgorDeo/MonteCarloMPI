#!/bin/bash

# Script de execução para testes do Monte Carlo Pi com MPI
# Executa diferentes configurações para análise de performance

echo "========================================"
echo "Executando testes Monte Carlo Pi - MPI"
echo "========================================"

# Verificar se o executável existe
if [ ! -f "build/monte_carlo_pi" ]; then
    echo "Erro: Executável não encontrado. Execute primeiro ./scripts/compile.sh"
    exit 1
fi

# Verificar se mpirun está disponível
if ! command -v mpirun &> /dev/null; then
    echo "Erro: mpirun não encontrado. Instale OpenMPI ou MPICH."
    exit 1
fi

# Criar diretório de resultados se não existir
if [ ! -d "results" ]; then
    mkdir results
    echo "Diretório results criado."
fi

# Arquivo de log dos resultados
RESULTS_FILE="results/performance_$(date +%Y%m%d_%H%M%S).txt"

echo "Resultados salvos em: $RESULTS_FILE"
echo "Monte Carlo Pi - Resultados de Performance" > $RESULTS_FILE
echo "Executado em: $(date)" >> $RESULTS_FILE
echo "=========================================" >> $RESULTS_FILE

# Função para executar teste
run_test() {
    local np=$1
    local points=$2
    
    echo ""
    echo "Teste: $np processos, $points pontos"
    echo "-----------------------------------"
    echo "" >> $RESULTS_FILE
    echo "Teste: $np processos, $points pontos" >> $RESULTS_FILE
    echo "-----------------------------------" >> $RESULTS_FILE
    
    mpirun -np $np ./build/monte_carlo_pi $points | tee -a $RESULTS_FILE
}

# Testes com diferentes números de processos
echo "Iniciando testes sistemáticos..."

# Teste 1: Diferentes números de processos com 1M pontos
echo ""
echo "SÉRIE 1: Escalabilidade (1M pontos)"
echo "===================================="
run_test 1 1000000
run_test 2 1000000
run_test 4 1000000
run_test 8 1000000

# Teste 2: Diferentes números de pontos com 4 processos
echo ""
echo "SÉRIE 2: Precisão vs Performance (4 processos)"
echo "=============================================="
run_test 4 100000
run_test 4 1000000
run_test 4 10000000

# Teste 3: Teste de carga pesada (se desejado)
echo ""
echo "SÉRIE 3: Teste de Carga (opcional - pode ser lento)"
echo "=================================================="
read -p "Executar teste de carga com 10B pontos? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    run_test 4 10000000000
    run_test 8 10000000000
else
    echo "Teste de carga pulado."
fi

echo ""
echo "========================================"
echo "Todos os testes concluídos!"
echo "Resultados salvos em: $RESULTS_FILE"
echo "========================================"

# Mostrar um resumo dos resultados
echo ""
echo "RESUMO DOS RESULTADOS:"
echo "====================="
grep -A1 "Pi estimado:" $RESULTS_FILE | head -20 