FROM openjdk:8-jre
ADD eurekaserver.jar .
EXPOSE 8761
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "eurekaserver.jar"]
