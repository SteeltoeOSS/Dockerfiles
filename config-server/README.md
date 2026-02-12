# steeltoe.azurecr.io/config-server

Image for SteeltoeOSS local development with [Spring Cloud Config Server](https://docs.spring.io/spring-cloud-config/docs/current/reference/html/).

## Running

Default configuration:

```shell
docker run --publish 8888:8888 steeltoe.azurecr.io/config-server
```

Custom git repo configuration:

```shell
docker run --publish 8888:8888 steeltoe.azurecr.io/config-server \
    --spring.cloud.config.server.git.uri=https://github.com/myorg/myrepo.git
```

Local file system configuration:

```shell
docker run --publish 8888:8888 --volume /path/to/my/config:/config steeltoe.azurecr.io/config-server \
    --spring.profiles.active=native \
    --spring.cloud.config.server.native.searchLocations=file:///config
```

With basic auth:

```shell
docker run --publish 8888:8888 steeltoe.azurecr.io/config-server \
    --auth.enabled=true \
    --auth.username=myCustomUser \
    --auth.password=myCustomPassword
```

## Resources

| Path | Description |
| ---- | ----------- |
| /_{app}_/_{profile}_ | Configuration data for app in Spring profile |
| /_{app}_/_{profile}_/_{label}_ | Add a git label |
| /_{app}_/_{profiles}/{label}_/_{path}_ | Environment-specific plain text config file at _{path}_ |

_Example:_ <http://localhost:8888/foo/bar>
