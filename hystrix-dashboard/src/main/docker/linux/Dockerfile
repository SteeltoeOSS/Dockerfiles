FROM openjdk:8u171-jre-alpine
ADD hystrix-dashboard.jar .
EXPOSE 7979
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "hystrix-dashboard.jar"]
