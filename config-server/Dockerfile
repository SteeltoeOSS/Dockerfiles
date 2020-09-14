# -----------------------------------------------------------------------------
# Spring Config Server Build
# -----------------------------------------------------------------------------

FROM bellsoft/liberica-openjdk-alpine:11 as build
WORKDIR /scratch
RUN apk add httpie
RUN http https://start.spring.io/starter.zip \
        type==gradle-project \
        platformVersion==2.3.3.RELEASE \
        jvmVersion==11 \
        groupId==io.steeltoe.docker \
        artifactId==configserver \
        applicationName==ConfigServer \
        dependencies==cloud-config-server \
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

# -----------------------------------------------------------------------------
# Spring Config Server Linux Image
# -----------------------------------------------------------------------------

FROM bellsoft/liberica-openjdk-alpine:11
ENV IMAGE_VERSION 2.2.5
# ENV IMAGE_REVISION r1
WORKDIR /config-server
COPY --from=build /scratch/configserver/build/libs .
EXPOSE 8888
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "configserver-2.2.5.jar"]
