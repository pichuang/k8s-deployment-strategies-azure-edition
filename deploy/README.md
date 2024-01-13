# AKS Deployment

- Updated on: 20240113

| Case No. | API Visibility | Data Plane Visibility | network-plugin (kubenet, azure, none) | network-dataplane (azure, cilium) | network-plugin-mode (overlay) | network-policy ("", calico, azure, cilium) | Tier | Support Plan |AGIC Support? |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| 1. Azure CNI Overlay        | Public | Public | azure | azure  | overlay | azure  | Premium         | `AKSLongTermSupport` | No. AGIC addon is not supported with network-plugin-mode=Overlay |
| 2. Azure CNI                | Public | Public | azure | azure  | N/A     | azure  | Premium         | `AKSLongTermSupport` | Yes |
| 3. Azure CNI Cilium         | Public | Public | azure | cilium | N/A     | cilium | Only `Standard` | Only `KubernetesOfficial`. AKSLongTermSupport does not support Cilium | Yes |
| 4. Azure CNI Cilium Overlay | Public | Public | azure | cilium | overlay | cilium | Only `Standard` | Only `KubernetesOfficial`. AKSLongTermSupport does not support Cilium | No. AGIC addon is not supported with network-plugin-mode=Overlay |
