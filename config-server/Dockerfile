# -----------------------------------------------------------------------------
# Spring Config Server Build
# -----------------------------------------------------------------------------

FROM eclipse-temurin:21-alpine as build
WORKDIR /scratch
RUN apk add httpie
RUN apk add patch
RUN http https://start.spring.io/starter.zip \
        type==gradle-project \
        platformVersion==3.2.2 \
        jvmVersion==21 \
        groupId==io.steeltoe.docker \
        artifactId==configserver \
        applicationName==ConfigServer \
        language==java \
        dependencies==cloud-config-server,actuator \
        --output configserver.zip
RUN mkdir configserver && unzip -d configserver configserver.zip
COPY patches patches
RUN for patch in patches/*.patch; do \
        echo "applying patch $(basename $patch)"; \
        cd configserver; \
        patch -p1 < ../$patch; \
        cd ..; \
        done
RUN configserver/gradlew bootJar --project-dir configserver --no-daemon
COPY metadata metadata

# -----------------------------------------------------------------------------
# Spring Config Server Linux Image
# -----------------------------------------------------------------------------

FROM eclipse-temurin:21
RUN export IMAGE_VERSION=$(cat metadata/IMAGE_VERSION)
RUN export IMAGE_REVISION=$(cat metadata/IMAGE_REVISION)
RUN export JAR_FILE="configserver-$IMAGE_VERSION.jar"
ENV SERVER_PORT=8888
WORKDIR /config-server
COPY --from=build /scratch/configserver/build/libs .
EXPOSE 8888
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", $JAR_FILE]
