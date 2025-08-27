# -----------------------------------------------------------------------------
# UAA Server Build
# -----------------------------------------------------------------------------

FROM cfidentity/uaa:v78.3.0
COPY uaa.yml /uaa/uaa.yml
COPY log4j2.properties /uaa/log4j2.properties
ENV CLOUDFOUNDRY_CONFIG_PATH=/uaa
ENV SPRING_CONFIG_ACTIVATE_ON-PROFILE=hsql,default
EXPOSE 8080
