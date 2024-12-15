FROM apache/superset:3.1.3
USER root
RUN pip install psycopg2-binary prophet
USER superset
ADD superset-public-permissions.json .
