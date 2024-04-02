# -----------------------------------------------------------------------------
# Netflix Eureka Server Build
# -----------------------------------------------------------------------------

FROM eclipse-temurin:21-alpine as build
WORKDIR /scratch
RUN apk add httpie && apk add patch
RUN http https://start.spring.io/starter.zip \
        type==gradle-project \
        platformVersion==3.2.4 \
        jvmVersion==21 \
        groupId==io.steeltoe.docker \
        artifactId==eurekaserver \
        applicationName==EurekaServer \
        language==java \
        dependencies==cloud-eureka-server,actuator \
        --output eurekaserver.zip
RUN mkdir eurekaserver && unzip -d eurekaserver eurekaserver.zip
COPY metadata metadata
COPY patches patches
RUN sed -i "s/<VERSION>/$(cat metadata/IMAGE_VERSION)/g" patches/version.patch
RUN for patch in patches/*.patch; do \
        echo "applying patch $(basename $patch)"; \
        cd eurekaserver; \
        patch -p1 < ../$patch; \
        cd ..; \
        done
RUN eurekaserver/gradlew bootJar --project-dir eurekaserver --no-daemon
RUN mkdir output && \
    cp "eurekaserver/build/libs/eurekaserver-$(cat metadata/IMAGE_VERSION).jar" output/eurekaserver.jar

# -----------------------------------------------------------------------------
# Netflix Eureka Server Linux Image
# -----------------------------------------------------------------------------

FROM eclipse-temurin:21-alpine
WORKDIR /eureka-server
COPY --from=build /scratch/output .
EXPOSE 8761
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "eurekaserver.jar"]
