import os
import json
import time
import requests
from confluent_kafka import Producer


def delivery_report(err, msg):
    if err is not None:
        print(f"Falha ao entregar mensagem: {err}")
    else:
        print(f"Mensagem entregue: topic={msg.topic()} partition={msg.partition()} offset={msg.offset()}")


class CryptoProducer:
    def __init__(self):
        self.kafka_broker = os.getenv("KAFKA_BROKER", "kafka:29092")
        self.topic = os.getenv("TOPIC", "crypto_prices")
        self.producer = Producer({"bootstrap.servers": self.kafka_broker})

    def fetch_prices(self):
        url = "https://api.coingecko.com/api/v3/simple/price"
        params = {"ids": "bitcoin,ethereum", "vs_currencies": "usd"}
        resp = requests.get(url, params=params)
        resp.raise_for_status()
        return resp.json()

    def run_once(self):
        data = self.fetch_prices()
        event = {
            "timestamp": int(time.time()),
            "prices": data,
        }
        msg = json.dumps(event)
        self.producer.produce(
            self.topic,
            key="crypto",  # chave opcional
            value=msg.encode("utf-8"),
            callback=delivery_report,
        )
        self.producer.poll(0)  # processa callbacks de entrega
        self.producer.flush()  # garante envio antes de encerrar
        print("Enviado:", msg)
