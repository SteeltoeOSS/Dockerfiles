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

1. (Operator task) Create an [identity zone](https://techdocs.broadcom.com/us/en/vmware-tanzu/platform/elastic-application-runtime/10-4/eart/t-uaa-uaa-concepts.html#iz) and note its auth domain (e.g. `https://<sso-plan>.login.<your-system-domain>`)
   * Pick an all-lowercase, dash-separated identity provider name for this connection (e.g. `steeltoe-uaa`) — you'll use this same value in both of the next two steps
1. Deploy the image, setting the `ssotile` client's `redirect-uri` to `<auth domain>/login/callback/<identity provider name>`. UAA always uses this fixed path for external OAuth/OIDC providers, and (as of UAA 78.15.0+) matches redirect URIs exactly, so wildcards like a trailing `/**` won't match:
   * `cf push steeltoe-uaa --docker-image steeltoe.azurecr.io/uaa-server --no-start`
   * `cf set-env steeltoe-uaa UAA_CONFIG_YAML '{oauth: {clients: {ssotile: {redirect-uri: "https://<sso-plan>.login.<your-system-domain>/login/callback/steeltoe-uaa"}}}}'`
   * `cf start steeltoe-uaa`
1. (Operator task) [Add the new identity provider with OpenID Connect](https://techdocs.broadcom.com/us/en/vmware-tanzu/platform/single-sign-on/1-17/sso/configure-external-id.html#config-ext-prov), using the same name from step 2 for **Identity Provider Name**
   * Use the `ssotile` credentials from uaa.yml

If you need to customize anything beyond `redirect-uri`, edit [uaa.yml](uaa.yml) and build your own image with `.\build.ps1 uaa-server`.
