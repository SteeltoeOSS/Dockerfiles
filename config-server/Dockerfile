# -----------------------------------------------------------------------------
# Spring Config Server Build
# -----------------------------------------------------------------------------

FROM eclipse-temurin:21-alpine as build
WORKDIR /scratch
RUN apk add httpie && apk add patch
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
COPY metadata metadata
COPY patches patches
RUN sed -i "s/<VERSION>/$(cat metadata/IMAGE_VERSION)/g" patches/version.patch
RUN for patch in patches/*.patch; do \
        echo "applying patch $(basename $patch)"; \
        cd configserver; \
        patch -p1 < ../$patch; \
        cd ..; \
        done
RUN configserver/gradlew bootJar --project-dir configserver --no-daemon
RUN mkdir output && \
    cp "configserver/build/libs/configserver-$(cat metadata/IMAGE_VERSION).jar" output/configserver.jar

# -----------------------------------------------------------------------------
# Spring Config Server Linux Image
# -----------------------------------------------------------------------------

FROM eclipse-temurin:21
WORKDIR /config-server
COPY --from=build /scratch/output .
EXPOSE 8888
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "configserver.jar"]
