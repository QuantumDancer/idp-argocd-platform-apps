# Platform Applications

For the main idea, see [IDP.md](./IDP.md).

## Bootstrapping

- Create a GitLab Deploy Token for this repo: https://docs.gitlab.com/user/project/deploy_tokens/#create-a-deploy-token
- Create `./bootstrap/repo.yaml` (use `./bootstrap/repo.yaml.example` as template)
- Run `./bootstrap/bootstrap.sh`

Follow the printed instructions how to set up port forwarding and how to retrieve the admin secret.
