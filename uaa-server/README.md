# UAA Server for Steeltoe Samples

This directory contains resources for building a [CloudFoundry User Account and Authentication (UAA)](https://github.com/cloudfoundry/uaa) Docker image that is customized to work with [Steeltoe Samples](https://github.com/SteeltoeOSS/Samples).

## Running Local

To run this image locally:

```shell
docker run -it -p 8080:8080 --name steeltoe-uaa steeltoe.azurecr.io/uaa-server:77.10
```

## Customizing for your environment

These instructions will help you build and deploy a custom image to use as an identity provider for [Single Sign-On for VMware Tanzu Application Service](https://docs.vmware.com/en/Single-Sign-On-for-VMware-Tanzu-Application-Service/index.html):

1. Clone this repository.
1. (Operator task) Create an [identity zone](https://docs.vmware.com/en/VMware-Tanzu-Application-Service/6.0/tas-for-vms/uaa-concepts.html#identity-zones-0)
1. Change the `redirect-uri` entry for `ssotile` in [uaa.yml](uaa.yml#132) to match your identity zone.
1. (OPTIONAL) Customize the name of the image you're about to build by renaming the `uaa-server` directory
1. .\build.ps1 .\uaa-server.
1. Push the image to an image repository accessible from your Cloud Foundry environment.
1. Deploy the image with a command similar to this:
   * `cf push steeltoe-uaa --docker-image steeltoe.azurecr.io/uaa-server:77.10`
1. (Operator task) [Add the new identity provider with OpenID Connect](https://docs.vmware.com/en/Single-Sign-On-for-VMware-Tanzu-Application-Service/1.14/sso/GUID-configure-external-id.html#config-ext-oidc)
   * Use the `ssotile` credentials from uaa.yml
