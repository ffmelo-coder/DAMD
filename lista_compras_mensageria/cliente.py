#!/usr/bin/env python3
"""
Consumer (cliente) para receber mensagens das filas `cotacoes` ou `negociacoes`.
Lê a URL AMQP da variável de ambiente `AMQP_URL` ou `CLOUDAMQP_URL`.
Use: python cliente.py cotacoes
"""
import os
import json
import time
import argparse
import sys

try:
    import pika
except Exception:
    print(
        "Erro ao importar pika. Instale dependências: pip install -r requirements.txt"
    )
    raise


def conectar_rabbitmq(amqp_url: str, queue_name: str, binding_key: str):
    params = pika.URLParameters(amqp_url)
    connection = pika.BlockingConnection(params)
    channel = connection.channel()

    # Declarar exchange e fila
    channel.exchange_declare(exchange="bolsa", exchange_type="topic", durable=True)
    channel.queue_declare(queue=queue_name, durable=True)
    channel.queue_bind(exchange="bolsa", queue=queue_name, routing_key=binding_key)

    return connection, channel


def processar_mensagem(ch, method, properties, body):
    try:
        mensagem = json.loads(body)
        routing_key = method.routing_key

        print(f"\nRecebida mensagem com routing key: {routing_key}")
        print(f"Conteúdo: {mensagem}")

        # Simulação de processamento
        print("Processando mensagem...")
        time.sleep(0.5)

        if "cotacoes" in routing_key:
            acao = mensagem.get("acao")
            valor = mensagem.get("valor")
            variacao = mensagem.get("variacao")
            print(f"Cotação de {acao}: R$ {valor} (variação: {variacao}%)")
            if variacao is not None:
                if variacao > 2:
                    print(f"ALERTA: {acao} em alta expressiva!")
                elif variacao < -2:
                    print(f"ALERTA: {acao} em queda expressiva!")

        elif "negociacoes" in routing_key:
            acao = mensagem.get("acao")
            quantidade = mensagem.get("quantidade")
            valor_total = mensagem.get("valor_total")
            tipo = mensagem.get("tipo")
            print(
                f"Negociação de {acao}: {tipo} de {quantidade} ações por R$ {valor_total:.2f}"
            )

        ch.basic_ack(delivery_tag=method.delivery_tag)
        print("Mensagem processada com sucesso!")

    except Exception as e:
        print(f"Erro ao processar mensagem: {e}")
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)


def iniciar_consumer(tipo_consumer: str, amqp_url: str):
    if tipo_consumer == "cotacoes":
        queue_name = "cotacoes"
        binding_key = "bolsa.cotacoes.#"
        print("Iniciando consumer de COTAÇÕES...")
    elif tipo_consumer == "negociacoes":
        queue_name = "negociacoes"
        binding_key = "bolsa.negociacoes.#"
        print("Iniciando consumer de NEGOCIAÇÕES...")
    else:
        raise ValueError(f"Tipo de consumer inválido: {tipo_consumer}")

    connection, channel = conectar_rabbitmq(amqp_url, queue_name, binding_key)

    channel.basic_qos(prefetch_count=1)
    channel.basic_consume(queue=queue_name, on_message_callback=processar_mensagem)

    print(f"Consumer {tipo_consumer} aguardando mensagens...")

    try:
        channel.start_consuming()
    except KeyboardInterrupt:
        print("Consumer interrompido pelo usuário")
    finally:
        print("Fechando conexão...")
        try:
            channel.stop_consuming()
        except Exception:
            pass
        connection.close()


def main():
    parser = argparse.ArgumentParser(
        description="Consumer RabbitMQ - cotacoes | negociacoes"
    )
    parser.add_argument(
        "tipo", choices=["cotacoes", "negociacoes"], help="Tipo de consumer a iniciar"
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
        iniciar_consumer(args.tipo, amqp_url)
    except Exception as e:
        print(f"Erro ao executar consumer: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
