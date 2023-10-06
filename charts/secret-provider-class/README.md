# Secret Provider Class Helm Chart

The following provides a method to create secrets needed by public HelmCharts in a GitOps-ish
manner. The `secrets-provider` HelmChart will allow us to create a `SecretProviderClass`
object containing all of the secret references we want to populate before deploying a public
Helm Chart. This should prevent us from forking Helm Charts.

Ideally, this chart can be deprecated once/if Flux CD is introduced to our ecosystem;
the Kustomization operator will allow us to create ad-hoc objects of any type to
extend the functionality of Helm Chart in a pure GitOps manner.

## Installation

```bash
$ helm upgrade --install -f your-values-file.yaml secret-provider-class . --namespace target_namespace
```
