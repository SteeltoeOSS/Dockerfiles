# -----------------------------------------------------------------------------
# Spring Boot Admin Server build
# -----------------------------------------------------------------------------

FROM bellsoft/liberica-openjdk-alpine:8u252 as build
ENV IMAGE_VERSION 2.2.3
ENV GRADLE_OPTS -Dorg.gradle.daemon=false
WORKDIR /scratch
COPY files .
RUN ./gradlew build
RUN ln -s build/libs/springbootadmin-${IMAGE_VERSION}.jar springbootadmin.jar

# -----------------------------------------------------------------------------
# Spring Boot Admin Server image
# -----------------------------------------------------------------------------

FROM bellsoft/liberica-openjre-alpine:8u252
WORKDIR /spring-boot-admin
COPY --from=build /scratch .
EXPOSE 8080
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "springbootadmin.jar"]
