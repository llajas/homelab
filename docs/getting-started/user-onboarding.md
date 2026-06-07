# User onboarding

=== "For user"

    ## Create user

    Ask an admin to create your account, provide the following information:

    - [ ] Full name (John Doe)
    - [ ] Select a username (`johndoe`)
    - [ ] Email address (`johndoe@example.com`)

    ## Install companion apps

    For all users:

    - [ ] [Password manager](#recommended-password-managers)
    - [ ] [Matrix chat client](https://matrix.org/clients) (optional, you can use the web version)

    For technical users:

    - [ ] [Docker](https://docs.docker.com/engine/install)
    - [ ] [Lens](https://k8slens.dev) (optional, you can use the included `kubectl` or `k9s` command in the tools container)

=== "For admin"

    ## Create a new account

    The supported onboarding flow today is Kanidm-first.

    1. Make sure you have local access to the repo and cluster kubeconfig.
    2. Run the onboarding script:

        ```sh
        ./scripts/onboard-user johndoe "John Doe" johndoe@example.com
        ```

        This will:

        - create the Kanidm account
        - set the user's email address
        - add the user to the `editor` group by default
        - print a credential reset token or recovery link for first login

    3. To assign non-default groups during onboarding, pass them after the email:

        ```sh
        ./scripts/onboard-user johndoe "John Doe" johndoe@example.com editor grafana_editors planka_admins
        ```

    4. If a user loses access before they complete first login, generate a recovery credential as needed:

        ```sh
        ./scripts/kanidm-reset-password johndoe
        ```

    Kanidm is the source of truth for users and groups. Dex is only the application-facing OIDC broker in front of Kanidm.

    During staged Kanidm upgrades, keep Dex and the downstream application issuer settings unchanged until the Kanidm hop is validated.

    ## Group assignment

    Group membership determines which applications a user can access and what role they receive after login.

    Common examples in this repo:

    - `editor` - default baseline access used by current automation
    - `grafana_editors@auth.lajas.tech` / `grafana_admins@auth.lajas.tech` - Grafana roles
    - `planka_admins` / `planka_admins@auth.lajas.tech` - Planka admin roles

    Before assigning a new application group, verify that the target app and its OIDC role mapping are already configured in Git.

    ## Send the initial login link or token

    Choose one of the methods listed below to send the initial credential-reset link or token to the user:

    - Share via password manager (if supported)
    - Encrypt the token or link and send it via email or chat
    - Write or print the token or link on a piece of paper

    On the first login, the user will be required to set or update their credentials.

    There is currently no full Kanidm admin web UI workflow documented in this repo for creating users or groups. Administration is done through the Kanidm CLI and the helper scripts above.

## Appendix

### Recommended password managers

- [Bitwarden](https://bitwarden.com/download) (easy to use, but requires an online account)
- [KeePassXC](https://keepassxc.org) (completely offline, but you'll need to sync manually)
