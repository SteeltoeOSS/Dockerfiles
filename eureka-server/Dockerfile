# -----------------------------------------------------------------------------
# Netflix Eureka Server Build
# -----------------------------------------------------------------------------

FROM bellsoft/liberica-openjdk-alpine:8u252 as build
ENV IMAGE_VERSION 2.1.3
ENV IMAGE_REVISION r1
ENV GRADLE_OPTS -Dorg.gradle.daemon=false
WORKDIR /scratch
COPY files .
RUN ./gradlew build
RUN ln -s build/libs/eureka-server-${IMAGE_VERSION}.jar eureka-server.jar

# -----------------------------------------------------------------------------
# Netflix Eureka Server Linux Image
# -----------------------------------------------------------------------------

FROM bellsoft/liberica-openjre-alpine:8u252
WORKDIR /eureka-server
COPY --from=build /scratch .
EXPOSE 8761
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "eureka-server.jar"]
