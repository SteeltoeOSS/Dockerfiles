# -----------------------------------------------------------------------------
# UAA Server Build
# -----------------------------------------------------------------------------
ARG SERVER_VERSION
FROM cfidentity/uaa:v${SERVER_VERSION}
COPY uaa.yml /uaa/uaa.yml
COPY log4j2.properties /uaa/log4j2.properties
ENV CLOUDFOUNDRY_CONFIG_PATH=/uaa
ENV SPRING_CONFIG_ACTIVATE_ON-PROFILE=hsql,default
EXPOSE 8080
