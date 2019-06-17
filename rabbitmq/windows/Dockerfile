# escape=`
# -----------------------------------------------------------------------------
# RabbitMQ Windows Image
# -----------------------------------------------------------------------------

FROM mcr.microsoft.com/windows/servercore:ltsc2019
ENV IMAGE_VERSION 3.7.15
ENV RABBITMQ_SERVER=C:\RabbitMQ-Server `
    RABBITMQ_BASE=C:\RabbitMQ-Data `
    ERLANG_HOME="C:\Program Files\erl10.3"
ADD http://erlang.org/download/otp_win64_21.3.exe erlang-installer.exe
ADD https://github.com/rabbitmq/rabbitmq-server/releases/download/v${IMAGE_VERSION}/rabbitmq-server-windows-${IMAGE_VERSION}.zip rabbitmq-server.zip
RUN powershell `
    Start-Process -FilePath erlang-installer.exe -ArgumentList '/S' -Wait; `
    Remove-Item -Path erlang-installer.exe -Force; `
    Expand-Archive rabbitmq-server.zip C:\Scratch ; `
    Remove-Item -Force rabbitmq-server.zip; `
    Move-Item `
        -Path C:\Scratch\rabbitmq_server-${Env:image_version} `
        -Destination ${Env:rabbitmq_server}; `
    Remove-Item -Path C:\Scratch -Force; `
    [System.Environment]::SetEnvironmentVariable('PATH', ${Env:rabbitmq_server} + '\sbin', [System.EnvironmentVariableTarget]::User)
EXPOSE 5672
ENTRYPOINT ["rabbitmq-server.bat"]
