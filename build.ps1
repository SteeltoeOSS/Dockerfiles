#!/usr/bin/env pwsh

# =============================================================================
# build.ps1: build script for SteeltoeOSS Docker images
# =============================================================================

# -----------------------------------------------------------------------------
# help
# -----------------------------------------------------------------------------

<#
    .SYNOPSIS
    Build Steeltoe Docker images

    .DESCRIPTION
    Builds a specified Steeltoe Docker image.

    By default, the image will be tagged using the name '<image>:[<version>[-<rev>]]' where:
      image      the specified Image name
      version    the value of 'IMAGE_VERSION' if specified in Dockerfile
      rev        the value of 'IMAGE_REVISION' if specified in Dockerfile

    .PARAMETER Help
    Print this message.

    .PARAMETER List
    List available images.

    .PARAMETER Name
    Docker image name.

    .PARAMETER Tag
    Override the image tag.

    .PARAMETER Registry
    Set the container registry. Defaults to dockerhub under steeltoeoss.
#>

# -----------------------------------------------------------------------------
# args
# -----------------------------------------------------------------------------

param (
   [Switch] $Help,
   [Switch] $List,
   [String] $Name,
   [String] $Tag,
   [String] $Registry
)

# -----------------------------------------------------------------------------
# impl
# -----------------------------------------------------------------------------

if ($Registry)
{
    $DockerOrg = $Registry
}
else
{
    $DockerOrg = "steeltoeoss"
}

if ($Help)
{
    Get-Help $PSCommandPath -Detailed
    return
}

if ($Name -And $List)
{
    throw "-Name and -List are mutually exclusive"
}

$ImagesDirectory = Split-Path -Parent $PSCommandPath

if ($List)
{
    Get-ChildItem -Path $ImagesDirectory -Directory | Where-Object { !$_.Name.StartsWith(".") -And $_.Name -NE "workspace" } | Select-Object Name
    return
}

if (!$Name)
{
    throw "Name not specified; run with -Help for help"
}

$ImageDirectory = Join-Path $ImagesDirectory $Name
if (!(Test-Path $ImageDirectory))
{
    throw "Unknown image $Name; run with -List to list available images"
}

if (!(Get-Command "docker" -ErrorAction SilentlyContinue))
{
    if (Get-Command "podman" -ErrorAction SilentlyContinue)
    {
        Write-Host "Adding docker alias for podman"
        Set-Alias "docker" "podman"
    }
    else
    {
        throw "'docker' command not found"
    }
}

if (Test-Path (Join-Path $ImageDirectory "metadata"))
{
    $Version = Get-Content (Join-Path $ImageDirectory "metadata" "IMAGE_VERSION")
}
else
{
    throw "No metadata found for $Name"
}

if (!$Tag)
{
    if ($env:GITHUB_ACTIONS -eq "true")
    {
        $Tag = "$DockerOrg/${Name}:$Version"
        $Revision = Get-Content (Join-Path $ImageDirectory "metadata" "IMAGE_REVISION")
        if ($Revision)
        {
            $Tag += "-$Revision"
        }
        $AdditionalTags = "$(Get-Content (Join-Path $ImageDirectory "metadata" "ADDITIONAL_TAGS") | ForEach-Object { $_.replace("$Name","$DockerOrg/$Name") })"
        Write-Host "If pushed, the image will be available as: $Tag $AdditionalTags"
    }
    else
    {
        $Tag = "$DockerOrg/${Name}:dev"
        $AdditionalTags = ""
        Write-Host "The image will be locally runnable as: $Tag"
    }
}
else
{
    Write-Host "Tag value set by script parameter: $Tag"
    $AdditionalTags = ""
}

if ($Name -eq "uaa-server")
{
    $Dockerfile = Join-Path $ImageDirectory Dockerfile
    if (!(Test-Path $Dockerfile))
    {
        throw "No Dockerfile for $Name (expected $Dockerfile)"
    }

    $docker_command = "docker build -t $Tag $AdditionalTags $ImageDirectory --build-arg SERVER_VERSION=$Version"
    Write-Host $docker_command
    Invoke-Expression $docker_command
}
else
{
    if (!(Get-Command "patch" -ErrorAction SilentlyContinue))
    {
        if (Test-Path "$Env:ProgramFiles\Git\usr\bin\patch.exe")
        {
            Write-Host "'patch' command not found, but Git is installed; adding Git usr\bin to PATH"
            $env:Path += ";$Env:ProgramFiles\Git\usr\bin"
        }
        else
        {
            throw "'patch' command not found"
        }
    }

    switch ($Name)
    {
        "config-server"
        {
            $appName = "ConfigServer"
            $dependencies = "cloud-config-server,actuator,cloud-eureka,security"
        }
        "eureka-server"
        {
            $appName = "EurekaServer"
            $dependencies = "cloud-eureka-server,actuator"
        }
        "spring-boot-admin"
        {
            $appName = "SpringBootAdmin"
            $dependencies = "codecentric-spring-boot-admin-server,native"
        }
        Default
        {
            Write-Host "$Name is not currently supported by this script"
            exit 2
        }
    }

    $AllowCachedDownload = $true
    $workPath = "workspace"
    if (!(Test-Path $workPath))
    {
        New-Item -ItemType Directory -Path $workPath | Out-Null
    }
    Push-Location $workPath

    $serverName = $Name -replace '-', ''
    $JVM = "21"
    $bootVersion = Get-Content (Join-path $ImageDirectory "metadata" "SPRING_BOOT_VERSION")
    $serverVersion = Get-Content (Join-Path $ImageDirectory "metadata" "IMAGE_VERSION")

    Write-Host "Building server: $Name@$serverVersion on Spring Boot $bootVersion with primary tag: $Tag"
    Write-Host "Using source files in: $ImageDirectory | Working directory:" $PWD

    # Ensure clean workspace
    Remove-Item -Recurse -Force $serverName -ErrorAction Ignore

    if (!$AllowCachedDownload -Or !(Test-Path "$serverName.zip"))
    {
        Invoke-WebRequest `
            -Uri "https://start.spring.io/starter.zip" `
            -Method Post `
            -Body @{
                type            = "gradle-project"
                bootVersion     = $bootVersion
                javaVersion     = $JVM
                groupId         = "io.steeltoe.docker"
                artifactId      = $serverName
                name            = $appName
                applicationName = $appName
                description     = "$appName for local development with Steeltoe"
                language        = "java"
                dependencies    = $dependencies
                version         = $serverVersion
            } `
            -OutFile "$serverName.zip"
            }
    else
    {
        Write-Host "Using cached Spring Boot project download"
    }

            New-Item -ItemType Directory -Path $serverName | Out-Null
            Expand-Archive -Path "$serverName.zip" -DestinationPath $serverName -Force

            if (!$AllowCachedDownload) {
        Remove-Item "$serverName.zip"
    }

    # Apply patches
    foreach ($patch in Get-ChildItem -Path (Join-Path $ImageDirectory patches) -Filter "*.patch")
    {
        Write-Host "applying patch $($patch.Name)"
        Push-Location $serverName
        Get-Content $patch | & patch -p1
        if ($LASTEXITCODE -ne 0)
        {
            Write-Error "Patch failed with exit code $LASTEXITCODE"
            exit 1
        }
        Pop-Location
    }

    # Build the image
    Push-Location $serverName
    $gradleArgs = @("bootBuildImage", "--imageName=$Tag")

    if ($env:GITHUB_ACTIONS -eq "true") {
        $gradleArgs += "--no-daemon"
    }

    ./gradlew @gradleArgs
    Pop-Location

    foreach ($AdditionalTag in $AdditionalTags.Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries))
    {
        Write-Host "running 'docker tag $Tag $AdditionalTag'"
        docker tag $Tag $AdditionalTag
    }

    Pop-Location
}
