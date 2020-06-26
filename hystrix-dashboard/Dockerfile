# -----------------------------------------------------------------------------
# Netflix Hystrix Dashboard Build
# -----------------------------------------------------------------------------

FROM bellsoft/liberica-openjdk-alpine:8u252 as build
ENV IMAGE_VERSION 1.4.5
ENV IMAGE_REVISION r1
ENV GRADLE_OPTS -Dorg.gradle.daemon=false
WORKDIR /scratch
COPY files .
RUN ./gradlew build
RUN ln -s build/libs/hystrix-dashboard-${IMAGE_VERSION}.jar hystrix-dashboard.jar

# -----------------------------------------------------------------------------
# Netflix Hystrix Dashboard Linux Image
# -----------------------------------------------------------------------------

FROM bellsoft/liberica-openjre-alpine:8u252
WORKDIR /hystrix-dashboard
COPY --from=build /scratch .
EXPOSE 7979
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "hystrix-dashboard.jar"]
