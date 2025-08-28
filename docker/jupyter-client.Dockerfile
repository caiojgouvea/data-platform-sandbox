# Usa a MESMA imagem do cluster
ARG SPARK_IMAGE
FROM ${SPARK_IMAGE}

USER root
# O Bitnami Spark já traz um Python em /opt/bitnami/python
# Instalamos o Jupyter nesse Python para manter compatibilidade
RUN /opt/bitnami/python/bin/pip install --no-cache-dir jupyterlab ipykernel

WORKDIR /opt/notebooks
