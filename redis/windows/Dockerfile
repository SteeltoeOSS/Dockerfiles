# -----------------------------------------------------------------------------
# Redis Windows Image
# -----------------------------------------------------------------------------

FROM microsoft/nanoserver:sac2016
ENV IMAGE_VERSION 3.0.504
ADD https://github.com/MicrosoftArchive/redis/releases/download/win-3.0.504/Redis-x64-${IMAGE_VERSION}.zip redis.zip
RUN powershell -Command \
    Expand-Archive redis.zip C:\Redis ; \
    Remove-Item -Force redis.zip
EXPOSE 6379
ENTRYPOINT ["C:\\Redis\\redis-server.exe"]
