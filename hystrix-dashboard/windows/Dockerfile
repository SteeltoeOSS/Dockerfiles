# -----------------------------------------------------------------------------
# Netflix Hystrix Dashboard Windows Image
# -----------------------------------------------------------------------------

FROM openjdk:8u171-jdk-nanoserver
ENV IMAGE_VERSION 1.4.5
ENV GRADLE_OPTS -Dorg.gradle.daemon=false
WORKDIR /hystrix-dashboard
COPY files .
RUN ./gradlew build
RUN New-Item -ItemType SymbolicLink -Path hystrix-dashboard.jar -Value build\libs\hystrix-dashboard-${Env:image_version}.jar
EXPOSE 7979
ENTRYPOINT ["java.exe", "-jar", "hystrix-dashboard.jar"]
