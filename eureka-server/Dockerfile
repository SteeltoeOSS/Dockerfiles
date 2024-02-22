# -----------------------------------------------------------------------------
# Netflix Eureka Server Build
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
        artifactId==eurekaserver \
        applicationName==EurekaServer \
        language==java \
        dependencies==cloud-eureka-server,actuator \
        --output eurekaserver.zip
RUN mkdir eurekaserver && unzip -d eurekaserver eurekaserver.zip
COPY patches patches
RUN for patch in patches/*.patch; do \
        echo "applying patch $(basename $patch)"; \
        cd eurekaserver; \
        patch -p1 < ../$patch; \
        cd ..; \
        done
RUN eurekaserver/gradlew bootJar --project-dir eurekaserver --no-daemon

# -----------------------------------------------------------------------------
# Netflix Eureka Server Linux Image
# -----------------------------------------------------------------------------

FROM eclipse-temurin:21-alpine
ENV IMAGE_VERSION 4.1.0
# ENV IMAGE_REVISION r1
WORKDIR /eureka-server
COPY --from=build /scratch/eurekaserver/build/libs .
EXPOSE 8761
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "eurekaserver-4.1.0.jar"]
