FROM steeltoe:openjdk-nano
ADD target/configserver-0.0.1-SNAPSHOT.jar app.jar
VOLUME c:\\steeltoe\\config-repo
EXPOSE 8888
ENTRYPOINT ["java","-jar","/app.jar"]