# -----------------------------------------------------------------------------
# Spring Boot Admin Server Build
# -----------------------------------------------------------------------------

FROM eclipse-temurin:21-alpine AS build
WORKDIR /scratch
RUN apk update && apk add ca-certificates && apk add curl && apk add patch
RUN curl --get https://start.spring.io/starter.zip \
        -d "type=gradle-project" \
        -d "platformVersion=3.3.4" \
        -d "jvmVersion=21" \
        -d "groupId=io.steeltoe.docker" \
        -d "artifactId=springbootadmin" \
        -d "applicationName=SpringBootAdmin" \
        -d "language=java" \
        -d "dependencies=codecentric-spring-boot-admin-server" \
        --output springbootadmin.zip
RUN mkdir springbootadmin && unzip -d springbootadmin springbootadmin.zip
COPY metadata metadata
COPY patches patches
RUN sed -i "s/<VERSION>/$(cat metadata/IMAGE_VERSION)/g" patches/version.patch
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

FROM eclipse-temurin:21-alpine
WORKDIR /springbootadmin
COPY --from=build /scratch/output .
EXPOSE 9090
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "springbootadmin.jar"]
