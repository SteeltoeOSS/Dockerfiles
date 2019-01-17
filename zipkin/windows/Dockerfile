# -----------------------------------------------------------------------------
# Zipkin Server Windows Image
# -----------------------------------------------------------------------------

FROM openjdk:8u171-jdk-nanoserver
ENV IMAGE_VERSION 2.11.6
WORKDIR /zipkin
ADD https://search.maven.org/remote_content?g=io.zipkin.java&a=zipkin-server&v=${IMAGE_VERSION}&c=exec zipkin-server-${IMAGE_VERSION}.jar
RUN New-Item -ItemType SymbolicLink -Path zipkin-server.jar -Value zipkin-server-${Env:image_version}.jar
EXPOSE 9411
ENTRYPOINT ["java.exe", "-jar", "zipkin-server.jar"]
