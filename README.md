# SteeltoeOSS Docker Images

GitHub repo for server images to use for local development with SteeltoeOSS.

## Building

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
| [steeltoe.azurecr.io/uaa-server](uaa-server/) | CloudFoundry UAA Server |

## Debug Image Building

### Inspect Container Contents

Via [StackOverflow](https://stackoverflow.com/questions/32353055/how-to-start-a-stopped-docker-container-with-a-different-command/39329138#39329138), here are the commands to list files in a stopped container.

1. Find the id of the stopped container
   * `docker ps -a`
1. Commit the stopped container to a new image: test_image.
   * `docker commit $CONTAINER_ID test_image`
1. Run the new image in a new container with a shell.
   * `docker run -ti --entrypoint=sh test_image`
