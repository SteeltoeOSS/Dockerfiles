# -----------------------------------------------------------------------------
# Spring Config Server build
# -----------------------------------------------------------------------------

FROM openjdk:8u171-jdk-alpine as build
ENV IMAGE_VERSION 2.0.1
ENV GRADLE_OPTS -Dorg.gradle.daemon=false
WORKDIR /scratch
COPY files .
RUN ./gradlew build
RUN ln -s build/libs/config-server-${IMAGE_VERSION}.jar config-server.jar

# -----------------------------------------------------------------------------
# Spring Config Server image
# -----------------------------------------------------------------------------

FROM openjdk:8u171-jre-alpine
WORKDIR /config-server
COPY --from=build /scratch .
EXPOSE 8888
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "config-server.jar"]
