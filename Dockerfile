# Estágio 1: Build
FROM alpine:3.19 AS builder

RUN apk add --no-cache \
    openmpi-dev \
    gcc \
    g++ \
    make \
    libc-dev

# Copiar e compilar código
COPY src/monte_carlo_pi.c /tmp/
COPY src/utils.h /tmp/
RUN mpicc /tmp/monte_carlo_pi.c -o /tmp/monte_carlo_pi -lm

# Estágio 2: Runtime (imagem final)
FROM alpine:3.19

# Instalar apenas dependências de runtime
RUN apk add --no-cache \
    openmpi \
    openssh-server \
    openssh-client \
    bash \
    su-exec && \
    # Configurar SSH
    ssh-keygen -A && \
    mkdir -p /var/run/sshd && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Criar usuário mpiuser
RUN adduser -D -s /bin/bash mpiuser && \
    echo "mpiuser:mpiuser" | chpasswd

# Configurar SSH sem senha para mpiuser
RUN mkdir -p /home/mpiuser/.ssh && \
    ssh-keygen -t rsa -N "" -f /home/mpiuser/.ssh/id_rsa && \
    cat /home/mpiuser/.ssh/id_rsa.pub >> /home/mpiuser/.ssh/authorized_keys && \
    chown -R mpiuser:mpiuser /home/mpiuser/.ssh && \
    chmod 700 /home/mpiuser/.ssh && \
    chmod 600 /home/mpiuser/.ssh/authorized_keys

# Copiar binário compilado do estágio de build
COPY --from=builder /tmp/monte_carlo_pi /home/mpiuser/monte_carlo_pi
RUN chown mpiuser:mpiuser /home/mpiuser/monte_carlo_pi && \
    chmod +x /home/mpiuser/monte_carlo_pi

WORKDIR /home/mpiuser

# Expor porta SSH
EXPOSE 22

# Script de inicialização otimizado
RUN echo '#!/bin/bash' > /start.sh && \
    echo 'exec /usr/sbin/sshd -D' >> /start.sh && \
    chmod +x /start.sh

CMD ["/start.sh"]
