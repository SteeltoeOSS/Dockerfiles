# -----------------------------------------------------------------------------
# Netflix Eureka Server Windows Image
# -----------------------------------------------------------------------------

FROM openjdk:8u171-jdk-nanoserver
ENV IMAGE_VERSION 2.0.1
ENV GRADLE_OPTS -Dorg.gradle.daemon=false
WORKDIR /eureka-server
COPY files .
RUN ./gradlew build
RUN New-Item -ItemType SymbolicLink -Path eureka-server.jar -Value build\libs\eureka-server-${Env:image_version}.jar
EXPOSE 8761
ENTRYPOINT ["java.exe", "-jar", "eureka-server.jar"]
