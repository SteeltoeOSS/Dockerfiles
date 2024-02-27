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
    Get-Childitem -Path $ImagesDirectory -Directory | Where-Object { !$_.Name.StartsWith(".") } | Select-Object Name
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

$Name = Split-Path -Leaf $ImageDirectory   # this removes stuff like ".\" prefix

if (!(Get-Command "docker" -ErrorAction SilentlyContinue))
{
    throw "'docker' command not found"
}

$Dockerfile = Join-Path $ImageDirectory Dockerfile
if (!(Test-Path $Dockerfile))
{
    throw "No Dockerfile for $Name (expected $Dockerfile)"
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
        $Tag += " $(Get-Content $ImageDirectory/metadata/ADDITIONAL_TAGS | ForEach { $_.replace("$Name","$DockerOrg/$Name") })"
    }
    else
    {
        $DockerArch = "amd64"
        $DockerOs = "linux"
        $Tag = "-t $DockerOrg/$Name-$DockerArch-$DockerOS"
        $VersionMatcher = Select-String -Path $Dockerfile -Pattern '^ENV\s+IMAGE_VERSION\s*=?\s*(.+)$'
        if ($VersionMatcher)
        {
            $Version = $VersionMatcher.Matches.Groups[1]
            $Tag += ":$Version"
            $RevisionMatcher = Select-String -Path $Dockerfile -Pattern '^ENV\s+IMAGE_REVISION\s*=?\s*(.+)$'
            if ($RevisionMatcher)
            {
                $Revision = $RevisionMatcher.Matches.Groups[1]
                $Tag += "-$Revision"
            }
        }
    }
}

$docker_command = "docker build $Tag $ImageDirectory"
Write-host $docker_command
Invoke-Expression $docker_command
