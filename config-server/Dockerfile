# -----------------------------------------------------------------------------
# Spring Config Server Build
# -----------------------------------------------------------------------------

FROM bellsoft/liberica-openjdk-alpine:8u252 as build
ENV IMAGE_VERSION 2.0.1
ENV IMAGE_REVISION r1
ENV GRADLE_OPTS -Dorg.gradle.daemon=false
WORKDIR /scratch
COPY files .
RUN ./gradlew build
RUN ln -s build/libs/config-server-${IMAGE_VERSION}.jar config-server.jar

# -----------------------------------------------------------------------------
# Spring Config Server Linux Image
# -----------------------------------------------------------------------------

FROM bellsoft/liberica-openjre-alpine:8u252
WORKDIR /config-server
COPY --from=build /scratch .
EXPOSE 8888
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "config-server.jar"]
