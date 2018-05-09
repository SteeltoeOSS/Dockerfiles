FROM microsoft/nanoserver
LABEL Description="Java JDK - Windows Nano Server"

ENV OPENJDK_DOWNLOAD_URL "http://cdn.azul.com/zulu/bin/zulu8.15.0.1-jdk8.0.92-win_x64.zip"

RUN powershell.exe -Command ; \
	$handler = New-Object System.Net.Http.HttpClientHandler ; \
	$client = New-Object System.Net.Http.HttpClient($handler) ; \
	$client.Timeout = New-Object System.TimeSpan(0, 30, 0) ; \
	$cancelTokenSource = [System.Threading.CancellationTokenSource]::new() ; \
	$responseMsg = $client.GetAsync([System.Uri]::new('%OPENJDK_DOWNLOAD_URL%'), $cancelTokenSource.Token) ; \
	$responseMsg.Wait() ; \
	$downloadedFileStream = [System.IO.FileStream]::new('c:\openjdk.zip', [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write) ; \
	$response = $responseMsg.Result ; \
	$copyStreamOp = $response.Content.CopyToAsync($downloadedFileStream) ; \
	$copyStreamOp.Wait() ; \
	$downloadedFileStream.Close() ; \
	[System.IO.Compression.ZipFile]::ExtractToDirectory('c:\openjdk.zip','c:\') ; \
	Remove-Item c:\openjdk.zip -Force
RUN powershell.exe -Command $path = $env:path + ';C:\zulu8.15.0.1-jdk8.0.92-win_x64\bin'; Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment\' -Name Path -Value $path
RUN powershell.exe -Command $javaHome = 'C:\zulu8.15.0.1-jdk8.0.92-win_x64'; Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment\' -Name JAVA_HOME -Value $javaHome

CMD [ "cmd" ]