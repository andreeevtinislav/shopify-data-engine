# Build from the REPO ROOT (not this folder) — it needs files from
# ingestion/ and dbt/ too:
#   docker build -f airflow/Dockerfile -t <ecr-repo>:<tag> .
FROM apache/airflow:2.10.4-python3.11

USER root
# EFS mount point (sqlite metadata DB) and the two private-key files the
# entrypoint writes at container start; created here so ownership is correct
# before the airflow user writes to them.
RUN mkdir -p /opt/airflow/data /opt/airflow/secrets && \
    chown -R airflow:root /opt/airflow/data /opt/airflow/secrets

USER airflow

# Install the ingestion package (for the `sync-orders` CLI) into the image's
# existing Airflow venv.
COPY --chown=airflow:root ingestion/pyproject.toml /tmp/ingestion/pyproject.toml
COPY --chown=airflow:root ingestion/src /tmp/ingestion/src
RUN pip install --no-cache-dir "/tmp/ingestion"

COPY --chown=airflow:root dbt/requirements.txt /tmp/dbt-requirements.txt
RUN pip install --no-cache-dir -r /tmp/dbt-requirements.txt

# dbt project itself (models, snapshots, dbt_project.yml) plus a profiles.yml
# generated entirely from env vars (see dbt/profiles.yml.example) — safe to
# bake into the image since it holds no literal credentials, only
# {{ env_var(...) }} references resolved at runtime from PIPELINE_ENV/DBT_ENV
# in dags/shopify_sync_dag.py.
COPY --chown=airflow:root dbt/dbt_project.yml /opt/airflow/dbt/dbt_project.yml
COPY --chown=airflow:root dbt/models /opt/airflow/dbt/models
COPY --chown=airflow:root dbt/snapshots /opt/airflow/dbt/snapshots
COPY --chown=airflow:root dbt/profiles.yml.example /opt/airflow/dbt/profiles.yml

COPY --chown=airflow:root airflow/dags /opt/airflow/dags

ENV AIRFLOW__CORE__EXECUTOR=SequentialExecutor \
    AIRFLOW__CORE__LOAD_EXAMPLES=False \
    AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=sqlite:////opt/airflow/data/airflow.db

USER root
COPY --chown=airflow:root airflow/entrypoint.sh /entrypoint-shopify.sh
RUN chmod +x /entrypoint-shopify.sh
USER airflow

ENTRYPOINT ["/entrypoint-shopify.sh"]
CMD ["standalone"]
