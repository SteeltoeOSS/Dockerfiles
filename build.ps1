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

    .PARAMETER DirectoryName
    Name of directory holding files that define the image. Defaults to the same value used for "Name".
#>

# -----------------------------------------------------------------------------
# args
# -----------------------------------------------------------------------------

param (
   [Switch] $Help,
   [Switch] $List,
   [String] $Name,
   [String] $Tag,
   [String] $Registry,
   [String] $DirectoryName
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
    Get-Childitem -Path $ImagesDirectory -Directory | Where-Object { !$_.Name.StartsWith(".") } | Select-Object Name
    return
}

if (!$Name)
{
    throw "Name not specified; run with -Help for help"
}

if (!$DirectoryName)
{
    $DirectoryName = $Name
}

$ImageDirectory = Join-Path $ImagesDirectory $DirectoryName
if (!(Test-Path $ImageDirectory))
{
    throw "Unknown image $DirectoryName; run with -List to list available images"
}

if (!(Get-Command "docker" -ErrorAction SilentlyContinue))
{
    throw "'docker' command not found"
}

$Dockerfile = Join-Path $ImageDirectory Dockerfile
if (!(Test-Path $Dockerfile))
{
    throw "No Dockerfile for $DirectoryName (expected $Dockerfile)"
}

if (!$Tag)
{
    if (Test-Path "$ImageDirectory/metadata")
    {
        $Tag = "-t $DockerOrg/$Name"
        $Version = Get-Content "$ImageDirectory/metadata/IMAGE_VERSION"
        $Tag += ":$Version"
        $Revision = Get-Content "$ImageDirectory/metadata/IMAGE_REVISION"
        if ($Revision)
        {
            $Tag += "-$Revision"
        }
        $Tag += " $(Get-Content $ImageDirectory/metadata/ADDITIONAL_TAGS | ForEach-Object { $_.replace("$DirectoryName","$DockerOrg/$Name") })"
    }
    else
    {
        throw "No metadata found for $DirectoryName"
    }
}

$docker_command = "docker build $Tag $ImageDirectory"
Write-host $docker_command
Invoke-Expression $docker_command
