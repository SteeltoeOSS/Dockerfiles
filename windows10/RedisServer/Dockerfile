FROM microsoft/nanoserver

LABEL Description="Redis - Windows Nano Server" Vendor="MSOpenTech" Version="2.8"
ENV REDIS_DOWNLOAD_URL "https://github.com/MSOpenTech/redis/releases/download/win-2.8.2400/Redis-x64-2.8.2400.zip"

RUN powershell.exe -Command ; \
	$handler = New-Object System.Net.Http.HttpClientHandler ; \
	$client = New-Object System.Net.Http.HttpClient($handler) ; \
	$client.Timeout = New-Object System.TimeSpan(0, 30, 0) ; \
	$cancelTokenSource = [System.Threading.CancellationTokenSource]::new() ; \
	$responseMsg = $client.GetAsync([System.Uri]::new('%REDIS_DOWNLOAD_URL%'), $cancelTokenSource.Token) ; \
	$responseMsg.Wait() ; \
	$downloadedFileStream = [System.IO.FileStream]::new('c:\redis.zip', [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write) ; \
	$response = $responseMsg.Result ; \
	$copyStreamOp = $response.Content.CopyToAsync($downloadedFileStream) ; \
	$copyStreamOp.Wait() ; \
	$downloadedFileStream.Close() ; \
	[System.IO.Compression.ZipFile]::ExtractToDirectory('c:\redis.zip','c:\redis') ; \
	Remove-Item c:\redis.zip -Force

WORKDIR /redis

CMD redis-server.exe