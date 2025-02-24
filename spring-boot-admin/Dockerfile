# -----------------------------------------------------------------------------
# Spring Boot Admin Server Build
# -----------------------------------------------------------------------------
ARG JVM=21

FROM eclipse-temurin:$JVM-alpine AS build
ARG JVM
WORKDIR /scratch
RUN apk update && apk add ca-certificates && apk add curl && apk add patch
RUN curl https://start.spring.io/starter.zip \
        -d type=gradle-project \
        -d bootVersion=3.4.3 \
        -d javaVersion=$JVM \
        -d groupId=io.steeltoe.docker \
        -d artifactId=springbootadmin \
        -d applicationName=SpringBootAdmin \
        -d language=java \
        -d dependencies=codecentric-spring-boot-admin-server \
        -d version=3.4.3 \
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
    cp "springbootadmin/build/libs/springbootadmin-$(cat metadata/IMAGE_VERSION).jar" output/springbootadmin.jar

# -----------------------------------------------------------------------------
# Spring Boot Admin Server Linux Image
# -----------------------------------------------------------------------------

FROM eclipse-temurin:$JVM-alpine
WORKDIR /springbootadmin
COPY --from=build /scratch/output .
EXPOSE 9099
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "springbootadmin.jar"]
