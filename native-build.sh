#!/bin/bash

# This script essentially does what ./build.ps1 + the dockerfiles do, but without building container images.
# Use this script if you need to troubleshoot or do something new with the servers that get embedded in the images

if [ "$#" -eq 0 ]
then
    echo "You must specify the server to build. Supported options include config-server, eureka-server and spring-boot-admin."
    exit 1
fi

JVM="21"
bootVersion="3.5.6"

if [ "$1" == "config-server" ]; then
    appName="ConfigServer"
    serverVersion="4.3.0"
    dependencies="cloud-config-server,actuator,cloud-eureka,security"
elif [ "$1" == "eureka-server" ]; then
    appName="EurekaServer"
    serverVersion="4.3.0"
    dependencies="cloud-eureka-server,actuator"
elif [ "$1" == "spring-boot-admin" ]; then
    appName="SpringBootAdmin"
    serverVersion="3.5.5"
    dependencies="codecentric-spring-boot-admin-server"
else
    echo "$1 is not currently supported by this script"
    exit 2
fi
sourceDirectory=$1
serverName=${sourceDirectory//-/}
tempDir="$serverName-temp"

echo "Source: $sourceDirectory | Server: $serverName | TempDir: $tempDir"
rm -rf $tempDir
mkdir $tempDir
cd $tempDir

curl https://start.spring.io/starter.zip \
        -d type=gradle-project \
        -d bootVersion=$bootVersion \
        -d javaVersion=$JVM \
        -d groupId=io.steeltoe.docker \
        -d artifactId=$serverName \
        -d applicationName=$appName \
        -d language=java \
        -d dependencies=$dependencies \
        -d version=$serverVersion \
        --output $serverName.zip

mkdir $serverName
unzip -d $serverName $serverName.zip

cp ../$sourceDirectory/metadata ./metadata -r
cp ../$sourceDirectory/patches ./patches -r
for patch in patches/*.patch; do \
        echo "applying patch $(basename $patch)"; \
        cd $serverName; \
        patch -p1 < ../$patch; \
        cd ..; \
        done

$serverName/gradlew bootJar --project-dir $serverName
mkdir output
cp $serverName/build/libs/$serverName-$(cat metadata/IMAGE_VERSION).jar output/$serverName.jar

cd ..
