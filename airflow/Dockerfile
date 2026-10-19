FROM apache/airflow:2.10.5

COPY requirements.txt /tmp/requirements.txt
RUN python -m venv /opt/airflow/pipeline-venv \
 && /opt/airflow/pipeline-venv/bin/pip install --no-cache-dir -r /tmp/requirements.txt