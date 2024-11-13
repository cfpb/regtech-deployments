# Using Github Packages - Container Registry

Reference [Github's documentation](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry) as needed.

## Authenticating with GHCR

Generate a classic PAT token with the `read:packages`, `write:packages`, and `delete:packages` permissions.

```bash
export CR_PAT=TOKEN

$ echo $CR_PAT | docker login ghcr.io -u USERNAME --password-stdin
> Login Succeeded
```

## Build and push to GCR

```bash
$ docker build -t ghcr.io/cfpb/regtech/sbl/alpine:3.18 -f Dockerfile-alpine .
$ docker push ghcr.io/cfpb/regtech/sbl/alpine:3.18
```

