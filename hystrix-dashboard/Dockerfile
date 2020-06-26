# -----------------------------------------------------------------------------
# Netflix Hystrix Dashboard Build
# -----------------------------------------------------------------------------

FROM openjdk:8u171-jdk-alpine as build
ENV IMAGE_VERSION 1.4.5
ENV GRADLE_OPTS -Dorg.gradle.daemon=false
WORKDIR /scratch
COPY files .
RUN ./gradlew build
RUN ln -s build/libs/hystrix-dashboard-${IMAGE_VERSION}.jar hystrix-dashboard.jar

# -----------------------------------------------------------------------------
# Netflix Hystrix Dashboard Linux Image
# -----------------------------------------------------------------------------

FROM openjdk:8u171-jre-alpine
WORKDIR /hystrix-dashboard
COPY --from=build /scratch .
EXPOSE 7979
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "hystrix-dashboard.jar"]
