# escape=`
# -----------------------------------------------------------------------------
# Postgres Windows Image
# -----------------------------------------------------------------------------

FROM mcr.microsoft.com/windows/servercore:ltsc2019
ENV IMAGE_VERSION 10.8
ENV PGDATA C:\PgData
ADD https://get.enterprisedb.com/postgresql/postgresql-10.8-4-windows-x64.exe postgres-installer.exe
RUN powershell `
    Start-Process -FilePath postgres-installer.exe `
    -ArgumentList @( `
    '--mode',  'unattended', `
    '--unattendedmodeui', 'none', `
    '--servicename', 'postgres', `
    '--superaccount', 'postgres', `
    '--superpassword', 'postgres', `
    '--datadir', ${Env:pgdata} `
    ) `
    -Wait; `
    Remove-Item -Force postgres-installer.exe; `
    Set-Content -Path ${Env:pgdata}\pg_hba.conf -Value 'host all all 0.0.0.0/0 trust'; `
    Add-Content -Path ${Env:pgdata}\postgresql.conf -Value 'log_destination = ''stderr'''; `
    Add-Content -Path ${Env:pgdata}\postgresql.conf -Value 'logging_collector = on'; `
    Add-Content -Path ${Env:pgdata}\postgresql.conf -Value 'log_directory = ''C:\\'''; `
    Add-Content -Path ${Env:pgdata}\postgresql.conf -Value 'log_filename = ''Pg.log'''; `
    Add-Content -Path ${Env:pgdata}\postgresql.conf -Value 'log_rotation_age = 0'; `
    Add-Content -Path ${Env:pgdata}\postgresql.conf -Value 'log_statement = ''all'''; `
    Add-Content -Path ${Env:pgdata}\postgresql.conf -Value 'log_connections = on'; `
    Add-Content -Path ${Env:pgdata}\postgresql.conf -Value 'log_disconnections = on'; `
    [System.Environment]::SetEnvironmentVariable('PATH', 'C:\Program Files\PostgreSQL\10\bin', [System.EnvironmentVariableTarget]::User)
EXPOSE 5432
ENTRYPOINT ["powershell", "Get-Content", "-Path", "C:\\Pg.log", "-Tail", "10", "-Wait"]
