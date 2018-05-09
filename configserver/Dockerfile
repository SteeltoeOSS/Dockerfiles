FROM openjdk:8-jre
ARG JAR_FILE
ADD target/${JAR_FILE} configserver.jar
EXPOSE 8888
ENTRYPOINT ["java","-jar","configserver.jar"]
