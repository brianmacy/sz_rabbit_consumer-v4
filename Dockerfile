# docker build -t brian/sz_rabbit_consumer .
# docker run --user $UID -it -v $PWD:/data -e SENZING_ENGINE_CONFIGURATION_JSON brian/sz_rabbit_consumer

ARG BASE_IMAGE=senzing/senzingsdk-runtime:latest
FROM ${BASE_IMAGE}

LABEL Name="brain/sz_rabbit_consumer" \
      Maintainer="brianmacy@gmail.com" \
      Version="DEV"

RUN apt-get update \
 && apt-get -y install python3 python3-pip python3-pika python3-psycopg2 \
 && python3 -mpip install --break-system-packages orjson \
 && apt-get -y remove build-essential python3-pip \
 && apt-get -y autoremove \
 && apt-get -y clean

COPY sz_rabbit_consumer.py /app/

ENV PYTHONPATH=/opt/senzing/er/sdk/python:/app

USER 1001

WORKDIR /app
ENTRYPOINT ["/app/sz_rabbit_consumer.py"]

