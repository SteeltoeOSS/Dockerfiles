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

These instructions will help you deploy this image to use as an identity provider for [Single Sign-On for VMware Tanzu Application Service](https://techdocs.broadcom.com/us/en/vmware-tanzu/platform-services/single-sign-on-for-tanzu/1-16/sso-tanzu/index.html):

1. (Operator task) Create an [identity zone](https://techdocs.broadcom.com/us/en/vmware-tanzu/platform/tanzu-platform-for-cloud-foundry/10-3/tpcf/t-uaa-uaa-concepts.html)
1. Deploy the image, setting the `SSOTILE_REDIRECT_URI` environment variable to match your identity zone:
   * `cf push steeltoe-uaa --docker-image steeltoe.azurecr.io/uaa-server -e SSOTILE_REDIRECT_URI=https://<sso-plan>.login.<your-system-domain>/**`
1. (Operator task) [Add the new identity provider with OpenID Connect](https://techdocs.broadcom.com/us/en/vmware-tanzu/platform/single-sign-on/1-16/sso/configure-external-id.html#config-ext-prov)
   * Use the `ssotile` credentials from uaa.yml

If you need to customize anything beyond `redirect-uri`, edit [uaa.yml](uaa.yml) and build your own image with `.\build.ps1 uaa-server`.
