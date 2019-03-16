FROM windowsservercore
LABEL Description="Java JDK - Windows Server Core"
RUN powershell -Command \
	$ErrorActionPreference = 'Stop'; \
	Invoke-WebRequest -Method Get -Uri https://cdn.azul.com/zulu/bin/zulu8.15.0.1-jdk8.0.92-win_x64.zip -OutFile c:\jdk.zip ; \
	Expand-Archive -Path c:\jdk.zip -DestinationPath c:\openjdk ; \
	Remove-Item c:\jdk.zip -Force
RUN SETX /M JDK_HOME C:\openjdk\zulu8.15.0.1-jdk8.0.92-win_x64
RUN SETX /M PATH %PATH%;C:\openjdk\zulu8.15.0.1-jdk8.0.92-win_x64\bin
CMD [ "cmd" ]