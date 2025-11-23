#!/usr/bin/env python3
"""
Producer (servidor) para publicar mensagens no exchange 'bolsa' (tipo topic).
Lê a URL AMQP da variável de ambiente `AMQP_URL` ou `CLOUDAMQP_URL`.
"""
import os
import json
import time
import random
import argparse
import sys

try:
    import pika
except Exception:
    print(
        "Erro ao importar pika. Instale dependências: pip install -r requirements.txt"
    )
    raise


def conectar_rabbitmq(amqp_url: str):
    params = pika.URLParameters(amqp_url)
    params.socket_timeout = 5
    connection = pika.BlockingConnection(params)
    channel = connection.channel()

    # Declarar exchange topic 'bolsa'
    channel.exchange_declare(exchange="bolsa", exchange_type="topic", durable=True)

    return connection, channel


def publicar_mensagem(channel, routing_key: str, mensagem: dict):
    channel.basic_publish(
        exchange="bolsa",
        routing_key=routing_key,
        body=json.dumps(mensagem),
        properties=pika.BasicProperties(
            delivery_mode=2, content_type="application/json"
        ),
    )
    print(f"Mensagem enviada: {routing_key} - {mensagem}")


def simular_bolsa(amqp_url: str, count: int = 20, interval: float = 1.0):
    connection, channel = conectar_rabbitmq(amqp_url)

    acoes = ["PETR4", "VALE3", "ITUB4", "BBDC4", "ABEV3"]

    try:
        for i in range(count):
            acao = random.choice(acoes)
            valor = round(random.uniform(10, 100), 2)
            variacao = round(random.uniform(-5, 5), 2)

            mensagem_cotacao = {
                "acao": acao,
                "valor": valor,
                "variacao": variacao,
                "timestamp": time.time(),
            }

            routing_key = f"bolsa.cotacoes.acoes.{acao.lower()}"
            publicar_mensagem(channel, routing_key, mensagem_cotacao)

            # Ocasionalmente simular uma negociação
            if random.random() > 0.7:
                quantidade = random.randint(100, 10000)
                tipo = random.choice(["compra", "venda"])

                mensagem_negociacao = {
                    "acao": acao,
                    "quantidade": quantidade,
                    "valor_total": round(quantidade * valor, 2),
                    "tipo": tipo,
                    "timestamp": time.time(),
                }

                routing_key = f"bolsa.negociacoes.{tipo}.{acao.lower()}"
                publicar_mensagem(channel, routing_key, mensagem_negociacao)

            time.sleep(interval)

    finally:
        connection.close()
        print("Conexão fechada")


def main():
    parser = argparse.ArgumentParser(
        description="Producer RabbitMQ - simula mensagens da bolsa"
    )
    parser.add_argument(
        "--count", type=int, default=20, help="Quantidade de mensagens (iterações)"
    )
    parser.add_argument(
        "--interval",
        type=float,
        default=1.0,
        help="Intervalo (segundos) entre mensagens",
    )
    parser.add_argument(
        "--url", type=str, help="AMQP URL (ex: amqp://user:pass@host/vhost)"
    )

    args = parser.parse_args()

    amqp_url = (
        args.url
        or os.getenv("AMQP_URL")
        or os.getenv("CLOUDAMQP_URL")
        or "amqp://guest:guest@localhost:5672/"
    )

    try:
        simular_bolsa(amqp_url, count=args.count, interval=args.interval)
    except Exception as e:
        print(f"Erro ao executar produtor: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
