FROM apache/superset:3.1.3
USER root
RUN pip install psycopg2-binary prophet duckdb==1.3.1 duckdb-engine==0.17.0 && \
    apt-get update && \
    apt-get install -y postgresql-client && \
    rm -rf /var/lib/apt/lists/*
RUN mkdir -p /usr/local/share/superset
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY history_live_routes.sql /usr/local/share/superset/history_live_routes.sql
COPY superset-public-permissions.json /app/superset-public-permissions.json
RUN chmod +x /usr/local/bin/entrypoint.sh
USER superset
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
