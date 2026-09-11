# steeltoe.azurecr.io/uaa-server

This directory contains resources for building a [CloudFoundry User Account and Authentication (UAA)](https://github.com/cloudfoundry/uaa) Docker image that is customized to work with [Steeltoe Samples](https://github.com/SteeltoeOSS/Samples).

## Running Local

To run this image locally:

```shell
docker run -it -p 8080:8080 --name steeltoe-uaa steeltoe.azurecr.io/uaa-server
```

To run this image locally, overwriting the included `uaa.yml` file:

```shell
docker run -it -p 8080:8080 --name steeltoe-uaa -v $pwd/uaa.yml:/uaa/uaa.yml steeltoe.azurecr.io/uaa-server
```

## Customizing for your Cloud Foundry environment

These instructions will help you deploy this image to use as an identity provider for Tanzu [Single Sign-On](https://techdocs.broadcom.com/us/en/vmware-tanzu/platform/single-sign-on/1-17/sso/index.html):

1. (Operator task) Create an [identity zone](https://techdocs.broadcom.com/us/en/vmware-tanzu/platform/elastic-application-runtime/10-4/eart/t-uaa-uaa-concepts.html#iz)
1. Deploy the image, then set the `ssotile` client's `redirect-uri` to match your identity zone using the `UAA_CONFIG_YAML` environment variable (UAA merges this YAML on top of the file-based config at startup, so no rebuild is needed):
   * `cf push steeltoe-uaa --docker-image steeltoe.azurecr.io/uaa-server --no-start`
   * `cf set-env steeltoe-uaa UAA_CONFIG_YAML "oauth:\n  clients:\n    ssotile:\n      redirect-uri: https://<sso-plan>.login.<your-system-domain>/**"`
   * `cf start steeltoe-uaa`
1. (Operator task) [Add the new identity provider with OpenID Connect](https://techdocs.broadcom.com/us/en/vmware-tanzu/platform/single-sign-on/1-17/sso/configure-external-id.html#config-ext-prov)
   * Use the `ssotile` credentials from uaa.yml

If you need to customize anything beyond `redirect-uri`, edit [uaa.yml](uaa.yml) and build your own image with `.\build.ps1 uaa-server`.
