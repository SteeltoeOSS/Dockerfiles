# -----------------------------------------------------------------------------
# MySQL Windows Image
# -----------------------------------------------------------------------------

FROM microsoft/nanoserver:sac2016
ENV IMAGE_VERSION 5.7.24
ADD https://dev.mysql.com/get/Downloads/MySQL-5.7/mysql-${IMAGE_VERSION}-winx64.zip mysql.zip
RUN powershell -Command \
    Expand-Archive mysql.zip scratch ; \
    Remove-Item -Force mysql.zip  ; \
    Move-Item scratch\* C:\MySQL ; \
RUN C:\MySQL\bin\mysqld.exe --initialize-insecure --console --explicit_defaults_for_timestamp
EXPOSE 3306
ENTRYPOINT ["C:\\MySQL\\bin\\mysqld.exe", "--console"]
