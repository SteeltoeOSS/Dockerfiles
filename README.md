# SteeltoeOSS Docker Images

GitHub repo for server images to use for local development with SteeltoeOSS.

## Building

### Pre-Requisites

The following tools are required to build any image in this repository:

1. PowerShell or pwsh
1. Docker or Podman

#### Config Server, Eureka and Spring Boot Admin

These images use committed source generated from [start.spring.io](https://start.spring.io).
Building uses [the Gradle Plugin](https://docs.spring.io/spring-boot/gradle-plugin/packaging-oci-image.html) against the committed source — no internet access to start.spring.io is required.
To build these images you must have:

1. JDK 25
1. Internet access (to download the Gradle distribution and Maven dependencies on first build)

To **update** the committed source to a newer Spring Boot or dependency version, you will additionally need:

1. Access to start.spring.io
1. `patch` available in the path or installed with Git for Windows

If you do not already have a JDK installed, consider using [Scoop](https://scoop.sh/):

```shell
# Permit executing remote-signed scripts
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
# Install Scoop
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
# Add the Java bucket
scoop bucket add java
# Install the JDK
scoop install java/openjdk25
```

### Build a specific image

```shell
./build.ps1 config-server
```

## Running

### List the created images

```shell
docker images
```

See [Common Tasks](https://github.com/SteeltoeOSS/Samples/blob/main/CommonTasks.md/) for instructions on how to run the various docker images.

## Images

| Name | Description |
| ---- | ----------- |
| [steeltoe.azurecr.io/config-server](config-server/) | Spring Cloud Config Server |
| [steeltoe.azurecr.io/eureka-server](eureka-server/) | Netflix Eureka Server |
| [steeltoe.azurecr.io/spring-boot-admin](spring-boot-admin/) | Spring Boot Admin |
| [steeltoe.azurecr.io/uaa-server](uaa-server/) | Cloud Foundry UAA Server |

## Debug Image Building

### Inspect Container Contents

Via [StackOverflow](https://stackoverflow.com/questions/32353055/how-to-start-a-stopped-docker-container-with-a-different-command/39329138#39329138), here are the commands to list files in a stopped container.

1. Find the id of the stopped container
   * `docker ps -a`
1. Commit the stopped container to a new image: test_image.
   * `docker commit $CONTAINER_ID test_image`
1. Run the new image in a new container with a shell.
   * `docker run -ti --entrypoint=sh test_image`
