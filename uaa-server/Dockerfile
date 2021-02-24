FROM adoptopenjdk/openjdk11 as source
RUN apt-get update && apt-get install -y git
RUN git clone -b v75.0.0 https://github.com/cloudfoundry/uaa.git
COPY uaa.yml /uaa/uaa/src/main/resources/uaa.yml
WORKDIR /uaa
RUN /uaa/gradlew

FROM source as run
WORKDIR /uaa
EXPOSE 8080
CMD ["/uaa/gradlew", "run"]