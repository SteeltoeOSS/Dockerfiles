# -----------------------------------------------------------------------------
# UAA Server Build
# -----------------------------------------------------------------------------

FROM cloudfoundry/uaa:77.20.0
COPY uaa.yml /uaa/uaa.yml
COPY log4j2.properties /uaa/log4j2.properties
ENV CLOUDFOUNDRY_CONFIG_PATH=/uaa
ENV SPRING_PROFILES=hsql,default
EXPOSE 8080
