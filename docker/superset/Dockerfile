FROM apache/superset:3.1.3
USER root
RUN pip install psycopg2-binary prophet duckdb==1.3.1 duckdb-engine==0.17.0 && \
    apt-get update && \
    apt-get install -y postgresql-client && \
    rm -rf /var/lib/apt/lists/*
USER superset
ADD superset-public-permissions.json .
ENTRYPOINT ["entrypoint.sh"]
