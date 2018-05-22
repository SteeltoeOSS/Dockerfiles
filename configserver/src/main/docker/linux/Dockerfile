FROM openjdk:8u171-jre
ADD configserver.jar .
EXPOSE 8888
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "configserver.jar"]
