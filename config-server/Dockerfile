# -----------------------------------------------------------------------------
# Spring Config Server Build
# -----------------------------------------------------------------------------
ARG JVM=21

FROM eclipse-temurin:$JVM-alpine AS build
ARG JVM
WORKDIR /scratch
RUN apk update && apk add ca-certificates && apk add curl && apk add patch
RUN curl --get https://start.spring.io/starter.zip \
        -d type=gradle-project \
        -d bootVersion=3.4.1 \
        -d javaVersion=$JVM \
        -d groupId=io.steeltoe.docker \
        -d artifactId=configserver \
        -d applicationName=ConfigServer \
        -d language=java \
        -d dependencies=cloud-config-server,actuator,cloud-eureka \
        -d version=4.2.0 \
        --output configserver.zip
RUN mkdir configserver && unzip -d configserver configserver.zip
COPY metadata metadata
COPY patches patches
RUN for patch in patches/*.patch; do \
        echo "applying patch $(basename $patch)"; \
        cd configserver; \
        patch -p1 < ../$patch; \
        cd ..; \
        done
RUN configserver/gradlew bootJar --project-dir configserver --no-daemon
RUN mkdir output && \
    cp "configserver/build/libs/configserver-$(cat metadata/IMAGE_VERSION).jar" output/configserver.jar && \
    cp configserver/src/main/resources/application.properties output/application.properties

# -----------------------------------------------------------------------------
# Spring Config Server Linux Image
# -----------------------------------------------------------------------------

FROM eclipse-temurin:$JVM-alpine
WORKDIR /config-server
COPY --from=build /scratch/output .
EXPOSE 8888
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-Dspring.config.location=/config-server/application.properties", "-jar", "configserver.jar"]
