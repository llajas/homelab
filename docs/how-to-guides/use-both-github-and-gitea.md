# Use both GitHub and Gitea

Even though we self-host Gitea, you may still want to use GitHub as a backup and for discovery.

Add both push URLs (replace my repositories with yours):

```sh
git remote set-url --add --push origin git@git.lajas.tech:ops/homelab
git remote set-url --add --push origin git@github.com:llajas/homelab
```
You'll also want to be sure to add your SSH key to your account within the Gitea instance. This can be the 'gitea_admin' account or any other account that has the proper access to the repository.

Now you can just run `git push` like usual and it will push to both GitHub and Gitea.
