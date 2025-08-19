FROM apache/superset:3.1.3
USER root
RUN pip install psycopg2-binary prophet duckdb==1.3.1 duckdb-engine==0.17.0
USER superset
ADD superset-public-permissions.json .
