# Deployment

## Hostnames aren't updating after deployment

!!! tip
    As you move through the setup (Namely the initial `make configure` step) several changes will be made to the local files that will make the configuration your own. These changes will need to be commited back to GitHub prior to running the overarching `make` command for deployment to work correctly. As a result, you will need to ensure that you clone the repo using a method that allows you to perform a `git push` after the changes are made. These methods are covered under the following URL: [About Remote Repositories](https://docs.github.com/en/get-started/getting-started-with-git/about-remote-repositories)

## Terraform errors, ie. `Resource already exists`

You'll need remove all of the external resources that were created by Terraform. This can be done by running the following from the `homelab/external` folder.
```bash
terraform plan -destroy -out=destroy.tfplan && terraform apply destroy.tfplan
```
!!! tip

    If you have issues with the above method, you can remove the resources manually by performing the following:

    - Delete any [Cloudflare API keys](https://dash.cloudflare.com/profile/api-tokens) that were created by the setup. These keys will be labeled as 'homelab_cert_manager'. It's not 100% necessary to remove these keys but will help with maintaining a cleaner setup as a new API key is generated upon each subsequent run.
    - Delete all DNS records from [cloudflare](https://dash.cloudflare.com/) that were created by `cert-manager` - See this [Medium](https://medium.com/@quentinrozados/how-to-remove-all-cloudflare-dns-bulk-remove-93bd2a0366ba) article on how to remove more than one record at a time via API using [Postman](https://www.postman.com/).
    - Delete any existing Cloudflare Tunnels via the [Zero Trust Dashboard](https://one.dash.cloudflare.com/) under 'Access>Tunnels'.
    - Delete any existing ZeroTier networks - Login to the [Dashboard](https://my.zerotier.com/network), click on any existing networks. The option to delete will be at the bottom of the page.
    - Recreate the [Terraform Workspace](https://app.terraform.io/app/) - Be sure that upon recreation you set the execution mode to 'local'.
