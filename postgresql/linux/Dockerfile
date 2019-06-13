# -----------------------------------------------------------------------------
# Postgres Linux Image
# -----------------------------------------------------------------------------

FROM postgres:10.8-alpine
ENV IMAGE_VERSION 10.8
COPY configure-logging.sh docker-entrypoint-initdb.d/
EXPOSE 5432
