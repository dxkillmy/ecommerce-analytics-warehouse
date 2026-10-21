from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.bash import BashOperator

PROJECT = "/opt/airflow/project"
PY = "/opt/airflow/pipeline-venv/bin/python"
DBT = "/opt/airflow/pipeline-venv/bin/dbt"

default_args = {
    "retries": 2,
    "retry_delay": timedelta(minutes=1),
}

with DAG(
    dag_id="retail_pipeline",
    start_date=datetime(2026, 1, 1),
    schedule="@daily",
    catchup=False,
    default_args=default_args,
) as dag:

    load_raw = BashOperator(
        task_id="load_raw",
        bash_command=f"cd {PROJECT} && {PY} ingestion/load_raw.py",
    )

    clean = BashOperator(
        task_id="clean",
        bash_command=f"cd {PROJECT} && {PY} ingestion/clean.py",
    )

    dbt_run = BashOperator(
        task_id="dbt_run",
        bash_command=f"cd {PROJECT}/retail_dbt && {DBT} run",
    )

    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command=f"cd {PROJECT}/retail_dbt && {DBT} test",
    )

    load_raw >> clean >> dbt_run >> dbt_test