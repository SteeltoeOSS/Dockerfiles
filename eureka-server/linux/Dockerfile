# -----------------------------------------------------------------------------
# Netflix Eureka Server Build
# -----------------------------------------------------------------------------

FROM openjdk:8u171-jdk-alpine as build
ENV IMAGE_VERSION 2.0.1
ENV GRADLE_OPTS -Dorg.gradle.daemon=false
WORKDIR /scratch
COPY files .
RUN ./gradlew build
RUN ln -s build/libs/eureka-server-${IMAGE_VERSION}.jar eureka-server.jar

# -----------------------------------------------------------------------------
# Netflix Eureka Server Linux Image
# -----------------------------------------------------------------------------

FROM openjdk:8u171-jre-alpine
WORKDIR /eureka-server
COPY --from=build /scratch .
EXPOSE 8761
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "eureka-server.jar"]
