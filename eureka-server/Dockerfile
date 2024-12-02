# -----------------------------------------------------------------------------
# Netflix Eureka Server Build
# -----------------------------------------------------------------------------

FROM eclipse-temurin:21-alpine AS build
WORKDIR /scratch
RUN apk update && apk add ca-certificates && apk add curl && apk add patch
RUN curl --get https://start.spring.io/starter.zip \
        -d "type=gradle-project" \
        -d "platformVersion=3.3.6" \
        -d "jvmVersion=21" \
        -d "groupId=io.steeltoe.docker" \
        -d "artifactId=eurekaserver" \
        -d "applicationName=EurekaServer" \
        -d "language=java" \
        -d "dependencies=cloud-eureka-server,actuator" \
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
