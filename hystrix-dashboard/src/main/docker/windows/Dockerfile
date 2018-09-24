FROM openjdk:8u171-jdk-nanoserver
ADD hystrix-dashboard.jar .
EXPOSE 8761
ENTRYPOINT ["java", "-jar", "hystrix-dashboard.jar"]
