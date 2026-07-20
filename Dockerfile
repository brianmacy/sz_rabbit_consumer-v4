# docker build -t brian/sz_rabbit_consumer .
# docker run --user $UID -it -v $PWD:/data -e SENZING_ENGINE_CONFIGURATION_JSON brian/sz_rabbit_consumer

ARG BASE_IMAGE=senzing/senzingsdk-runtime:4.3.3
FROM ${BASE_IMAGE}

LABEL Name="brain/sz_rabbit_consumer" \
      Maintainer="brianmacy@gmail.com" \
      Version="DEV"

# Backend selection (build-time). Default = both on. PostgreSQL only: --build-arg WITH_MSSQL=0.
# MSSQL only: --build-arg WITH_POSTGRES=0. At least one backend is required (the build errors out
# if both are disabled).
#
# The Senzing engine uses per-backend plugins: libpostgresqlplugin.so reaches PostgreSQL via the
# system libpq (libpq5), and libmssqlplugin.so reaches SQL Server via the ODBC driver. So the real
# per-backend dependency is libpq5 (PG) vs the Microsoft ODBC stack (MSSQL) — NOT psycopg2, which
# the consumer never imports (it only uses the SDK + pika). libpq5 is preinstalled by the base
# image; nothing Senzing depends on it, so WITH_POSTGRES=0 purges it for a leaner MSSQL-only image.
ARG WITH_POSTGRES=1
ARG WITH_MSSQL=1

# The base senzingsdk-runtime image already ships everything needed to process records: libSz.so,
# all backend plugins (postgresql/mssql/oracle/mysql/sqlite/aurora), and the resources/templates +
# support data under /opt/senzing. So the only build-time additions are python3 + pika + orjson to
# run this script and, for MSSQL, the Microsoft ODBC driver.
#
# Do NOT add senzingsdk-setup here. An earlier version did, to "fix" a SENZ0087 at process time, but
# that was a misdiagnosis: the real cause was a 4.4 engine config run against a 4.3 runtime image,
# whose config referenced feature plugins absent in 4.3. Keep the engine config and runtime image
# on the same Senzing version; there are no separate feature-creator .so files to install in v4.
# MSSQL path: msodbcsql18 (ODBC Driver 18) via packages-microsoft-prod.deb (registers the MS apt
# repo + key for Debian 13 / trixie) + an /etc/odbc.ini [MSSQL] DSN with AutoTranslate=No (prevents UTF-8
# corruption; Server/Database/port come from the engine connection string, setupenv.sh). Debian's
# own unixODBC is built WITH --enable-fastvalidate, so we keep it; do NOT substitute Microsoft's
# Ubuntu unixODBC build (~10x slower). The FAQ's 2.3.6-0.1build1 pins are Ubuntu version strings
# and do not exist on the Debian 13 (trixie) senzingsdk-runtime base.
# NOTE: use the debian/13 MS repo, not debian/12 — trixie's apt (Sequoia/sqv) rejects the
# older repo key's SHA-1 self-signature ("repository is not signed"); the debian/13 repo
# ships a trixie-compatible key.
RUN apt-get update \
 && apt-get -y install \
      ca-certificates curl gnupg apt-transport-https \
      python3 python3-pip python3-pika \
 && python3 -mpip install --break-system-packages orjson \
 && if [ "$WITH_POSTGRES" != 1 ] && [ "$WITH_MSSQL" != 1 ]; then \
        echo "ERROR: enable at least one of WITH_POSTGRES / WITH_MSSQL" >&2; exit 1; fi \
 && if [ "$WITH_POSTGRES" != 1 ]; then apt-get -y purge libpq5; fi \
 && if [ "$WITH_MSSQL" = 1 ]; then \
        curl -sSL -o /tmp/packages-microsoft-prod.deb https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb \
     && dpkg -i /tmp/packages-microsoft-prod.deb \
     && rm -f /tmp/packages-microsoft-prod.deb \
     && apt-get update \
     && ACCEPT_EULA=Y apt-get -y install msodbcsql18 unixodbc \
     && printf '[MSSQL]\nDriver = ODBC Driver 18 for SQL Server\nAutoTranslate = No\n' > /etc/odbc.ini ; fi \
 && apt-get -y remove build-essential python3-pip \
 && apt-get -y autoremove \
 && apt-get -y clean \
 && rm -rf /var/lib/apt/lists/*

COPY sz_rabbit_consumer.py /app/

ENV PYTHONPATH=/opt/senzing/er/sdk/python:/app

USER 1001

WORKDIR /app
ENTRYPOINT ["/app/sz_rabbit_consumer.py"]

