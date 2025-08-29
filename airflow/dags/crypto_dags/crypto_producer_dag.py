from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta
from dps.producers.crypto_producer import CryptoProducer

def produce_crypto_prices():
    producer = CryptoProducer()
    producer.run_once()

default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=1),
    "max_active_runs": 1,
}


with DAG(
    dag_id="crypto_producer_dag",
    default_args=default_args,
    description="Producer de preços de criptos via CoinGecko",
    schedule_interval="*/10 * * * *",  # a cada 10 minutos
    start_date=datetime(2025, 8, 28),
    catchup=False,
    tags=["kafka", "crypto"],
) as dag:

    produce_task = PythonOperator(
        task_id="produce_crypto_prices",
        python_callable=produce_crypto_prices,
    )
