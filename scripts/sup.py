import paho.mqtt.client as mqtt
import ssl
import re

client = mqtt.Client()

MQTT_HOST = 'localhost'

client.tls_set('/etc/ssl/private/ca.crt',
               certfile='/etc/ssl/certs/localhost.crt',
               keyfile='/etc/ssl/private/localhost.ckey',
               cert_reqs=ssl.CERT_REQUIRED,
               tls_version=ssl.PROTOCOL_TLSv1)


def on_message(client, userdata, message):
    if re.match(r'^sup?', message.lower()):
        client.publish('not much.')


def on_connect(client, userdata, flags, rc):
    client.subscribe("#")
    client.publish('Hello mqtt')


client.on_connect = on_connect
client.on_message = on_message

client.connect(MQTT_HOST)
