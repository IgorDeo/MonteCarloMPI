#!/bin/bash

# Script de compilação para o projeto Monte Carlo Pi com MPI
# Autor: Igor Deo Alves e Roger Castellar
# Data: $(date)

echo "========================================"
echo "Compilando Monte Carlo Pi com MPI"
echo "========================================"

# Verificar se mpicc está disponível
if ! command -v mpicc &> /dev/null; then
    echo "Erro: mpicc não encontrado. Instale OpenMPI ou MPICH."
    echo "Ubuntu/Debian: sudo apt-get install libopenmpi-dev"
    echo "macOS: brew install open-mpi"
    exit 1
fi

# Criar diretório de build se não existir
if [ ! -d "build" ]; then
    mkdir build
    echo "Diretório build criado."
fi

# Compilar o programa
echo "Compilando src/monte_carlo_pi.c..."
mpicc -o build/monte_carlo_pi src/monte_carlo_pi.c -lm -O3 -Wall

# Verificar se a compilação foi bem-sucedida
if [ $? -eq 0 ]; then
    echo "✓ Compilação bem-sucedida!"
    echo "Executável criado: build/monte_carlo_pi"
    echo ""
    echo "Para executar:"
    echo "mpirun -np <num_processos> ./build/monte_carlo_pi <num_pontos>"
    echo ""
    echo "Exemplo:"
    echo "mpirun -np 4 ./build/monte_carlo_pi 1000000"
else
    echo "✗ Erro na compilação!"
    exit 1
fi

echo "========================================" 