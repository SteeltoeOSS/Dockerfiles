# -----------------------------------------------------------------------------
# Spring Config Server Windows Image
# -----------------------------------------------------------------------------

FROM openjdk:8u171-jdk-nanoserver
ENV IMAGE_VERSION 2.0.1
ENV GRADLE_OPTS -Dorg.gradle.daemon=false
WORKDIR /config-server
COPY files .
RUN ./gradlew build
RUN New-Item -ItemType SymbolicLink -Path config-server.jar -Value build\libs\config-server-${Env:image_version}.jar
EXPOSE 8888
ENTRYPOINT ["java.exe", "-jar", "config-server.jar"]
