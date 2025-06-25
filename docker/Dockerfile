FROM ubuntu:22.04

# Instala dependências MPI, SSH e utilitários
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    mpich build-essential openssh-server iputils-ping && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Gera as chaves de host SSH para o sshd
RUN ssh-keygen -A

# Cria diretório para o sshd
RUN mkdir -p /var/run/sshd

# Permite login via senha no sshd
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Cria usuário mpiuser com senha
RUN useradd -ms /bin/bash mpiuser && echo "mpiuser:mpiuser" | chpasswd

# Configura SSH para login sem senha do mpiuser (chave pública autorizada)
RUN mkdir -p /home/mpiuser/.ssh && \
    ssh-keygen -t rsa -N "" -f /home/mpiuser/.ssh/id_rsa && \
    cat /home/mpiuser/.ssh/id_rsa.pub >> /home/mpiuser/.ssh/authorized_keys && \
    chown -R mpiuser:mpiuser /home/mpiuser/.ssh && \
    chmod 700 /home/mpiuser/.ssh && \
    chmod 600 /home/mpiuser/.ssh/authorized_keys

# Copia código fonte
COPY src/monte_carlo_pi.c /home/mpiuser/
COPY src/utils.h /home/mpiuser/

# Compila o programa MPI
RUN mpicc /home/mpiuser/monte_carlo_pi.c -o /home/mpiuser/monte_carlo_pi -lm

WORKDIR /home/mpiuser

# Expõe porta SSH
EXPOSE 22

# Roda o servidor SSH em primeiro plano
CMD ["/usr/sbin/sshd", "-D"]
