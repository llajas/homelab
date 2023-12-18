# ArgoCD

## Sync Window

You may need to set a sync window in order to effectively "pause" syncing. This can be done in a few ways.

### GUI Sync Window

Open 'Settings' > 'Projects' > 'default' > 'ADD SYNC WINDOW'

For 'Kind' set `deny`. Set `duration` to 24h and check the box for `Enable manual sync`. Towards the bottom, set the name of the application(s) or the namespace(s) you want to hold sync jobs for. This is extremely useful for testing, or for reverting to using GitHub as the source of truth while modifying or changing aspects of Gitea.

### CLI Sync Window

You can also create sync windows directly from the CLI. Observe the below for more context:

```sh
❯ argocd login argocd.lajas.tech --grpc-web
Username: admin
Password:
'admin:login' logged in successfully
Context 'argocd.lajas.tech' updated
❯ argocd proj windows add default -k deny --schedule "* * * * *" --duration 24h --namespaces unbound --manual-sync
❯ argocd proj windows update default 0 --applications vault
❯ argocd proj windows list default
ID  STATUS  KIND  SCHEDULE   DURATION  APPLICATIONS  NAMESPACES  CLUSTERS  MANUALSYNC
0   Active  deny  * * * * *  1h        vault         -           -         Enabled
1   Active  deny  * * * * *  24h       -             unbound     -         Enabled
```
See the [ArgoCD Documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd_proj_windows/) for further guidance and options.
