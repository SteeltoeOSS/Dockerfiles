# -----------------------------------------------------------------------------
# Spring Boot Admin Server Build
# -----------------------------------------------------------------------------
ARG JVM=21
ARG BOOT_VERSION=3.5.6
# When changing, make sure this aligns with metadata/IMAGE_VERSION
ARG SERVER_VERSION=3.5.5

FROM eclipse-temurin:$JVM-alpine AS build
ARG JVM
ARG BOOT_VERSION
ARG SERVER_VERSION
WORKDIR /scratch
RUN apk update && apk add ca-certificates && apk add curl && apk add patch
RUN curl https://start.spring.io/starter.zip \
    -d type=gradle-project \
    -d bootVersion=$BOOT_VERSION \
    -d javaVersion=$JVM \
    -d groupId=io.steeltoe.docker \
    -d artifactId=springbootadmin \
    -d applicationName=SpringBootAdmin \
    -d language=java \
    -d dependencies=codecentric-spring-boot-admin-server \
    -d version=$SERVER_VERSION \
    --output springbootadmin.zip
RUN mkdir springbootadmin && unzip -d springbootadmin springbootadmin.zip
COPY metadata metadata
COPY patches patches
RUN for patch in patches/*.patch; do \
        echo "applying patch $(basename $patch)"; \
        cd springbootadmin; \
        patch -p1 < ../$patch; \
        cd ..; \
        done
RUN springbootadmin/gradlew bootJar --project-dir springbootadmin --no-daemon
RUN mkdir output && \
    cp "springbootadmin/build/libs/springbootadmin-$SERVER_VERSION.jar" output/springbootadmin.jar

# -----------------------------------------------------------------------------
# Spring Boot Admin Server Linux Image
# -----------------------------------------------------------------------------
FROM eclipse-temurin:$JVM-alpine
WORKDIR /springbootadmin
COPY --from=build /scratch/output .
EXPOSE 9099
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "springbootadmin.jar"]
