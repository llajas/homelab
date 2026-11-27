# User onboarding

=== "For user"

    ## Request an account

    Submit an access request at the [homelab registration portal](https://register.lajas.tech). Provide a username, display name, email address, and optionally a legal name. Select at least one of the application roles or groups offered by the form.

    The portal submits a request for review; it does not create an account or grant access. It does not ask for a password or other credentials. An owner reviews the request and follows up using the email address you provide. No access is granted before approval.

    ## Complete account setup

    If approved, an administrator will privately send you a temporary Kanidm enrollment link and sign-in instructions. Use the link to complete the credential setup flow. Treat the link as a password: anyone who has it may be able to activate the account. The link expires after 24 hours; contact the administrator if it has expired.

    After setup, sign in to the approved applications with your Kanidm account. The request portal is not a login or self-service password-reset page.

    ## Install companion apps

    For all users:

    - [ ] [Password manager](#recommended-password-managers)
    - [ ] [Matrix chat client](https://matrix.org/clients) (optional, you can use the web version)

    For technical users:

    - [ ] [Docker](https://docs.docker.com/engine/install)
    - [ ] [Lens](https://k8slens.dev) (optional, you can use the included `kubectl` or `k9s` command in the tools container)

=== "For admin"

    ## Review and provision an account

    The public portal turns an access request into a pull request in the private identity repository. A request is only a proposal: the person is not provisioned and receives no access until the change is reviewed, merged, and applied.

    1. Review the pull request in [`homelab-identity`](https://git.lajas.tech/ops/homelab-identity). Check the username, identity details, requested application roles, and group memberships against the request and the current catalog. The portal creates the user record with the `request-only` preset and `onboarding: true`; review any access changes before approving it.

    2. If creating a user without the portal, use `make add-user` in a trusted checkout of `homelab-identity`. Do not use this repository's legacy `scripts/onboard-user`; it creates Kanidm accounts directly and bypasses the identity repository's review and Terraform workflow.

    3. Merge one user change at a time. The protected-main Woodpecker workflow validates the change, creates a fresh Terraform plan, and applies that plan. Pull-request checks validate the change but do not run a live plan or provision the account.

    4. After the apply, retrieve the user's temporary enrollment link from the authenticated [identity admin portal](https://portal-admin.lajas.tech). The main-branch workflow hands off active onboarding links to this separate admin service; the public request portal never receives them. Share the link privately and promptly. It expires after 24 hours. If it expires, follow the identity repository's documented Kanidm reset procedure; rerunning Terraform does not generate a replacement link.

    5. After the user completes enrollment, change their `onboarding` field to `false` in `homelab-identity` and merge the follow-up change.

    The request portal offers only the roles and groups exposed by the identity repository's catalog. For full user, group, OAuth client, approval, and Terraform details, refer to [`homelab-identity`](https://git.lajas.tech/ops/homelab-identity) and [`homelab-identity-portal`](https://git.lajas.tech/ops/homelab-identity-portal).

    ## Identity and application access

    Kanidm is the identity provider. Applications use their configured Kanidm OIDC clients directly; Dex is not part of the current onboarding or sign-in flow. User and group desired state is managed in `homelab-identity`, not in this repository.

    Review the catalog before assigning access. Application roles resolve into the groups used by each application's OIDC policy, while explicit group memberships provide additional access. The two identity repositories are the source of truth for current options and policy.

## Appendix

### Recommended password managers

- [Bitwarden](https://bitwarden.com/download) (easy to use, but requires an online account)
- [KeePassXC](https://keepassxc.org) (completely offline, but you'll need to sync manually)
