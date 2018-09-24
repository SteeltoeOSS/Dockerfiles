FROM microsoft/windowsservercore
RUN powershell -Command \
    $ErrorActionPreference = 'Stop'; \
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; \
    Invoke-WebRequest -Method Get -Uri https://github.com/MicrosoftArchive/redis/releases/download/win-3.0.504/Redis-x64-3.0.504.zip -OutFile c:\redis.zip ; \
    Expand-Archive -Path c:\redis.zip -DestinationPath c:\redis ; \
    Remove-Item c:\redis.zip -Force
WORKDIR /redis
ENTRYPOINT ["redis-server.exe"]

# https://github.com/MicrosoftArchive/redis/releases/download/win-2.8.2400/Redis-x64-2.8.2400.zip