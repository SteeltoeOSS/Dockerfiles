# -----------------------------------------------------------------------------
# Zipkin Server Download
# -----------------------------------------------------------------------------

FROM alpine as download
ENV IMAGE_VERSION 2.11.6
ENV IMAGE_REVISION r1
WORKDIR /scratch
RUN wget \
    -O zipkin-server-exec-${IMAGE_VERSION}.jar \
    "https://search.maven.org/remote_content?g=io.zipkin.java&a=zipkin-server&v=${IMAGE_VERSION}&c=exec"
RUN ln -s zipkin-server-exec-${IMAGE_VERSION}.jar zipkin-server.jar

# -----------------------------------------------------------------------------
# Zipkin Server Linux Image
# -----------------------------------------------------------------------------

FROM bellsoft/liberica-openjre-alpine:8u252
WORKDIR /zipkin
COPY --from=download /scratch .
EXPOSE 9411
ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "zipkin-server.jar"]
