FROM openjdk:8-jre
ARG JAR_FILE
ADD target/${JAR_FILE} eurekaserver.jar
EXPOSE 8761
ENTRYPOINT ["java","-Djava.security.egd=file:/dev/./urandom", "-jar","eurekaserver.jar"]
