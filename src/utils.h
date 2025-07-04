#ifndef UTILS_H
#define UTILS_H

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>

// Função para executar simulação Monte Carlo
long long monte_carlo_simulation(long long num_points, int seed_offset) {
    long long points_inside = 0;
    double x, y, distance_squared;
    
    // Inicializar gerador de números aleatórios com seed único para cada processo
    srand(time(NULL) + seed_offset * 1000);
    
    for (long long i = 0; i < num_points; i++) {
        // Gerar coordenadas aleatórias no intervalo [-1, 1]
        x = (double)rand() / RAND_MAX * 2.0 - 1.0;
        y = (double)rand() / RAND_MAX * 2.0 - 1.0;
        
        // Calcular distância ao quadrado do centro (0,0)
        distance_squared = x * x + y * y;
        
        // Verificar se o ponto está dentro do círculo unitário
        if (distance_squared <= 1.0) {
            points_inside++;
        }
    }
    
    return points_inside;
}

// Função para validar entrada
int validate_input(long long total_points, int num_processes) {
    if (total_points <= 0) {
        printf("Erro: Número de pontos deve ser positivo\n");
        return 0;
    }
    
    if (total_points < num_processes) {
        printf("Aviso: Número de pontos menor que número de processos\n");
        printf("Alguns processos não terão trabalho para fazer\n");
    }
    
    return 1;
}

// Função para gerar números aleatórios de melhor qualidade (alternativa)
double random_double() {
    return (double)rand() / RAND_MAX;
}

// Função para imprimir informações do sistema MPI
void print_mpi_info(int rank, int size) {
    printf("Processo %d de %d inicializado\n", rank, size);
}

#endif // UTILS_H 