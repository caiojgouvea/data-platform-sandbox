#!/bin/bash
echo "Criando usuário spark..."
if ! id -u spark >/dev/null 2>&1; then
    deluser spark 2>/dev/null || true
    adduser --disabled-password --gecos "" --home /opt/bitnami/spark --shell /bin/bash --uid 1001 spark
    chown -R spark:spark /opt/bitnami/spark
else
    echo "Usuário spark já existe!"
fi