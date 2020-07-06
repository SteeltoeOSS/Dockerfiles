# -----------------------------------------------------------------------------
# Spring Boot Admin Server build
# -----------------------------------------------------------------------------

FROM openjdk:8u171-jdk-alpine as build
ENV IMAGE_VERSION 2.2.3
ENV GRADLE_OPTS -Dorg.gradle.daemon=false
WORKDIR /scratch
COPY files .
RUN ./gradlew build
RUN ln -s build/libs/springbootadmin-${IMAGE_VERSION}.jar springbootadmin.jar

# -----------------------------------------------------------------------------
# Spring Boot Admin Server image
# -----------------------------------------------------------------------------

FROM openjdk:8u171-jre-alpine
WORKDIR /spring-boot-admin
COPY --from=build /scratch .
EXPOSE 8080
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "springbootadmin.jar"]
