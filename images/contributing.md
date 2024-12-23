# Using Github Packages - Container Registry

Reference [Github's documentation](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry) as needed.


## Pipeline Build and Publish Core Images
We now have a GHA pipeline to build and publish these base images to the GHCR.

#### On Pull Requests
[build_images](../.github/workflows/build_images.yml) - runs on Pull Requests to test the image build only.

#### On Merge to Main
[build_and_publish_images](../.github/workflows/build_and_publish_images.yml) - runs on Merge to Main. This workflow will build and publish the images to Github Container Registry (GHCR).

> **NOTE** The `build_and_publish_images` workflow is also scheduled to run weekly every Sunday at 5 AM to help keep the base images up-to-date with the latest security patches and such.

#### Core Image tagging
We now add a unique tag to each published set of images that are included in the `build_and_publish_images` workflow.
Tagging is using github builtin property `github.run_attempt` and appended to the image tag.

Example image with new tag format: `ghcr.io/cfpb/regtech/sbl/python-alpine:3.12_xx`

This will allow applications to pin to specific builds in the event a new change is introduced to latest that doesn't play nice with the application.
The standard build image tag is still available to support apps pinning to the latest.

---

## Local Machine build and push core images (old depracated method)

#### Authenticating with GHCR

Generate a classic PAT token with the `read:packages`, `write:packages`, and `delete:packages` permissions.

```bash
export CR_PAT=TOKEN

$ echo $CR_PAT | docker login ghcr.io -u USERNAME --password-stdin
> Login Succeeded
```

#### Build and push to GCR

```bash
$ docker build -t ghcr.io/cfpb/regtech/sbl/alpine:3.18 -f Dockerfile-alpine .
$ docker push ghcr.io/cfpb/regtech/sbl/alpine:3.18
```

