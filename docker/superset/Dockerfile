FROM apache/superset
USER root
RUN pip install psycopg2-binary prophet
USER superset
ADD superset-public-permissions.json .
