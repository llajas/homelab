# Gitea

## Changing the `gitea_admin` password

!!! tip
    Spawn a shell into the Gitea pod, on the `gitea` container specifically such as thus:
    ```sh
    ❯ kc -n gitea exec -it gitea-7ccf4c587f-72tr2 -- /bin/sh
    Defaulted container "gitea" out of: gitea, init-directories (init), init-app-ini (init), configure-gitea (init)
    /var/lib/gitea $ gitea admin user change-password -u gitea_admin -p 'yourNewPassword'
    /var/lib/gitea $
    ```

## Gitea Doctor (Redis DB)

!!! tip
    As before, spawn a shell int the Gitea pod.
    ```sh
    ❯ kc -n gitea exec -it gitea-7ccf4c587f-72tr2 -- /bin/sh
    Defaulted container "gitea" out of: gitea, init-directories (init), init-app-ini (init), configure-gitea (init)
    /var/lib/gitea $ gitea doctor check

    [1] Check paths and basic configuration
     - [I] Configuration File Path:    "/data/gitea/conf/app.ini"
     - [I] Repository Root Path:       "/data/git/gitea-repositories"
     - [I] Data Root Path:             "/data"
     - [I] Custom File Root Path:      "/data/gitea"
     - [I] Work directory:             "/data"
     - [I] Log Root Path:              "/data/log"
    OK

    [2] Check Database Version
     - [I] Expected database version: 280
    OK

    [3] Check if user with wrong type exist
    OK

    [4] Check if OpenSSH authorized_keys file is up-to-date
    OK

    [5] Synchronize repo HEADs
     - [I] All 1 repos have their HEADs in the correct state
    OK

    All done.
    /var/lib/gitea $
    ```
### Gitea Redis Database Requirements

!!! tip
    Versions of Gitea after `5.0.9` require that there be 6 redis pods running for the app to function. Attempting to drop this number will result in issues with the app. For running newew versions of the app, it's recommended to have the equivalent or more nodes.
