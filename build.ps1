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

    .PARAMETER DisableCache
    Disable caching of projects from start.spring.io.

    .PARAMETER Name
    Docker image name.

    .PARAMETER Tag
    Override the image tag.

    .PARAMETER Registry
    Set the container registry. Defaults to steeltoe.azurecr.io.
#>

# -----------------------------------------------------------------------------
# args
# -----------------------------------------------------------------------------

param (
    [Switch] $Help,
    [Switch] $List,
    [Switch] $DisableCache,
    [String] $Name,
    [String] $Tag,
    [String] $Registry
)

$ErrorActionPreference = 'Stop'

try {

    # -----------------------------------------------------------------------------
    # impl
    # -----------------------------------------------------------------------------

    if ($Registry) {
        $DockerOrg = $Registry
    }
    else {
        $DockerOrg = "steeltoe.azurecr.io"
    }

    if ($Help) {
        Get-Help $PSCommandPath -Detailed
        return
    }

    if ($Name -And $List) {
        throw "-Name and -List are mutually exclusive"
    }

    $ImagesDirectory = Split-Path -Parent $PSCommandPath

    if ($List) {
        Get-ChildItem -Path $ImagesDirectory -Directory | Where-Object { !$_.Name.StartsWith(".") -And $_.Name -NE "workspace" } | Select-Object Name
        return
    }

    if (!$Name) {
        throw "Name not specified; run with -Help for help"
    }

    $ImageDirectory = Join-Path $ImagesDirectory $Name
    if (!(Test-Path $ImageDirectory)) {
        throw "Unknown image $Name; run with -List to list available images"
    }

    if (!(Get-Command "docker" -ErrorAction SilentlyContinue)) {
        if (Get-Command "podman" -ErrorAction SilentlyContinue) {
            Write-Host "Adding docker alias for podman"
            Set-Alias "docker" "podman"
        }
        else {
            throw "'docker' command not found"
        }
    }

    if (Test-Path (Join-Path $ImageDirectory "metadata")) {
        $Version = Get-Content (Join-Path $ImageDirectory "metadata" "IMAGE_VERSION")
    }
    else {
        throw "No metadata found for $Name"
    }

    if (!$Tag) {
        if ($env:GITHUB_ACTIONS -eq "true") {
            $ImageNameWithTag = "$DockerOrg/${Name}:$Version"
            $Revision = (Get-Content (Join-Path $ImageDirectory "metadata" "IMAGE_REVISION") -ErrorAction SilentlyContinue | ForEach-Object { $_.Trim() }) -join ""
            if ($Revision -and $Revision -ne "") {
                $ImageNameWithTag += "-$Revision"
            }
            $AdditionalTags = "$(Get-Content (Join-Path $ImageDirectory "metadata" "ADDITIONAL_TAGS") -ErrorAction SilentlyContinue | ForEach-Object { $_.replace("$Name","$DockerOrg/$Name") })"
        }
        else {
            $ImageNameWithTag = "$DockerOrg/${Name}:dev"
            $AdditionalTags = ""
        }
    }
    else {
        $ImageNameWithTag = "$DockerOrg/${Name}:$Tag"
        $AdditionalTags = ""
    }

    Write-Host "This image will be available as: $ImageNameWithTag $AdditionalTags"

    if ($Name -eq "uaa-server") {
        $Dockerfile = Join-Path $ImageDirectory Dockerfile
        if (!(Test-Path $Dockerfile)) {
            throw "No Dockerfile for $Name (expected $Dockerfile)"
        }

        if ($DisableCache) {
            Write-Host "Disabling Docker build cache"
            $NoCacheArg = "--no-cache"
        }
        else {
            $NoCacheArg = ""
        }

        $docker_command = "docker build $NoCacheArg -t $ImageNameWithTag $AdditionalTags $ImageDirectory --build-arg SERVER_VERSION=$Version"
        Write-Host $docker_command
        Invoke-Expression $docker_command
    }
    else {
        $supportedImages = @("config-server", "eureka-server", "spring-boot-admin")
        if ($Name -notin $supportedImages) {
            Write-Host "$Name is not currently supported by this script"
            exit 2
        }

        $workPath = "workspace"
        if (!(Test-Path $workPath)) {
            New-Item -ItemType Directory -Path $workPath | Out-Null
        }
        Push-Location $workPath
        try {
            $serverName = $Name -replace '-', ''
            $Version = Get-Content (Join-Path $ImageDirectory "metadata" "IMAGE_VERSION")

            Write-Host "Building server: $Name@$Version"
            Write-Host "Source files: $ImageDirectory/source"
            Write-Host "Working directory: $PWD"

            # Ensure clean workspace
            Remove-Item -Recurse -Force $serverName -ErrorAction Ignore
            if (Test-Path $serverName) {
                throw "Failed to remove existing workspace $serverName"
            }

            # Copy source from committed directory
            $sourceDir = Join-Path $ImageDirectory "source"
            if (!(Test-Path $sourceDir)) {
                throw "Source directory not found at $sourceDir. Run update-project.ps1 first."
            }

            Copy-Item -Path $sourceDir -Destination $serverName -Recurse -Force

            Push-Location $serverName
            try {
                # Build the image
                $gradleArgs = @("bootBuildImage", "--imageName=$ImageNameWithTag")
                if ($env:GITHUB_ACTIONS -eq "true") {
                    $gradleArgs += "--no-daemon"
                }

                ./gradlew @gradleArgs
            }
            finally {
                Pop-Location
            }

            foreach ($AdditionalTag in $AdditionalTags.Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)) {
                Write-Host "Running 'docker tag $ImageNameWithTag $AdditionalTag'"
                docker tag $ImageNameWithTag $AdditionalTag
            }
        }
        finally {
            Pop-Location  # workspace
        }
    }
}
catch {
    Write-Error "Build failed: $_"
    exit 1
}

