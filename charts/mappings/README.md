# Mappings Helm Chart

The following provides a method to create mappings needed by public HelmCharts in a GitOps-ish
manner. The `mappings` HelmChart will allow us to create one or many `Mapping`
objects, allowing us to actively use public charts that do not support the Mapping type.

Ideally, this chart can be deprecated once/if Flux CD is introduced to our ecosystem;
the Kustomization operator will allow us to create ad-hoc objects of any type to
extend the functionality of Helm Chart in a pure GitOps manner.

## Installation

```bash
$ helm upgrade --install -f your-values-file.yaml mappings . --namespace target_namespace
```
