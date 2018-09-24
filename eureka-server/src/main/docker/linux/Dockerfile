FROM openjdk:8u171-jre-alpine
ADD eureka-server.jar .
EXPOSE 8761
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "eureka-server.jar"]
