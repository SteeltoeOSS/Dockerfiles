FROM openjdk:8u171-jre-alpine
ADD eurekaserver.jar .
EXPOSE 8761
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "eurekaserver.jar"]
