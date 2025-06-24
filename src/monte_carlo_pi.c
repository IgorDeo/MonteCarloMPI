#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#include "utils.h"

int main(int argc, char *argv[]) {
    int rank, size;
    long long total_points, points_per_process, local_points_inside;
    long long global_points_inside = 0;
    double pi_estimate, error_percentage;
    double start_time, end_time, execution_time;
    
    // Inicializar MPI
    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);
    
    // Verificar argumentos da linha de comando
    if (argc != 2) {
        if (rank == 0) {
            printf("Uso: mpirun -np <num_processos> %s <total_pontos>\n", argv[0]);
            printf("Exemplo: mpirun -np 4 %s 1000000\n", argv[0]);
        }
        MPI_Finalize();
        return 1;
    }
    
    total_points = atoll(argv[1]);
    points_per_process = total_points / size;
    
    // Ajustar para garantir que todos os pontos sejam processados
    if (rank == size - 1) {
        points_per_process += total_points % size;
    }
    
    if (rank == 0) {
        printf("==========================================\n");
        printf("Calculando Pi usando Monte Carlo com MPI\n");
        printf("==========================================\n");
        printf("Número de processos: %d\n", size);
        printf("Total de pontos: %lld\n", total_points);
        printf("Pontos por processo: %lld\n", points_per_process);
        printf("------------------------------------------\n");
    }
    
    // Sincronizar todos os processos antes de começar a medição
    MPI_Barrier(MPI_COMM_WORLD);
    start_time = MPI_Wtime();
    
    // Cada processo executa simulação Monte Carlo
    local_points_inside = monte_carlo_simulation(points_per_process, rank);
    
    // Sincronizar antes de finalizar a medição
    MPI_Barrier(MPI_COMM_WORLD);
    end_time = MPI_Wtime();
    execution_time = end_time - start_time;
    
    // Exibir resultados locais de cada processo
    printf("Processo %d: %lld pontos dentro do círculo (de %lld pontos)\n", 
           rank, local_points_inside, points_per_process);
    
    // Usar MPI_Reduce para somar todos os pontos dentro do círculo
    MPI_Reduce(&local_points_inside, &global_points_inside, 1, MPI_LONG_LONG, 
               MPI_SUM, 0, MPI_COMM_WORLD);
    
    // Processo master calcula e exibe resultados finais
    if (rank == 0) {
        pi_estimate = 4.0 * global_points_inside / total_points;
        error_percentage = fabs(pi_estimate - M_PI) / M_PI * 100.0;
        
        printf("------------------------------------------\n");
        printf("RESULTADOS FINAIS:\n");
        printf("Total de pontos dentro do círculo: %lld\n", global_points_inside);
        printf("Pi estimado: %.6f\n", pi_estimate);
        printf("Pi real: %.6f\n", M_PI);
        printf("Erro absoluto: %.6f\n", fabs(pi_estimate - M_PI));
        printf("Erro percentual: %.3f%%\n", error_percentage);
        printf("Tempo de execução: %.6f segundos\n", execution_time);
        
        // Calcular e exibir métricas de performance
        calculate_performance_metrics(execution_time, size);
        
        printf("==========================================\n");
    }
    
    MPI_Finalize();
    return 0;
} 