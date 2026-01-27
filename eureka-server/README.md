# steeltoe.azurecr.io/eureka-server

Image for SteeltoeOSS local development with [Spring Cloud Eureka Server](https://cloud.spring.io/spring-cloud-netflix/reference/html).

## Running

```shell
docker run --rm -it --pull=always -p 8761:8761 --name steeltoe-eureka steeltoe.azurecr.io/eureka-server:4
```

## Resources

| Path | Description |
| ---- | ----------- |
| / | Service registration listing |
| /eureka/apps | Registration metadata |
| /actuator/health | Health check |
