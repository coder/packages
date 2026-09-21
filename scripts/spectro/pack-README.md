# Coder

Coder provides self-hosted cloud development environments that run on your own public or private cloud infrastructure. Workspaces are defined with Terraform, connected through a secure high-speed tunnel, and automatically shut down when idle to save on costs. Developers connect to their workspaces with the tools they already use, including VS Code Remote, JetBrains Gateway, SSH, and web IDEs such as JupyterLab, code-server, and RStudio, while source code and credentials stay inside your infrastructure.

## Prerequisites

Review the Coder [Kubernetes installation guide](https://coder.com/docs/install/kubernetes) for the authoritative list of requirements. At a minimum, you need the following.

- A Kubernetes cluster running version **1.19** or later. This is the `kubeVersion` constraint declared by the chart.
- An external PostgreSQL database that is reachable from the cluster. The chart does not ship a database. You must supply the connection string through the `CODER_PG_CONNECTION_URL` environment variable, ideally sourced from a Kubernetes secret.
- A resolvable access URL for the Coder deployment, set through the `CODER_ACCESS_URL` environment variable, and either an Ingress controller or a LoadBalancer service so that users and workspace agents can reach that URL.
- A namespace to deploy into. The pack defaults to the `coder` namespace.
- Cluster permissions to create the service account, Role, and RoleBinding that allow Coder to manage workspace pods and persistent volume claims.

## Parameters

The table below lists the most commonly used parameters. Paths are expressed relative to the Coder chart. In the pack's `values.yaml` these keys live under `charts.coder.`, so the chart parameter `coder.env` is set as `charts.coder.coder.env`.

| **Parameter** | **Description** | **Type** | **Default Value** | **Required** |
|---|---|---|---|---|
| `coder.env` | Environment variables passed to `coder server`. Use this to set `CODER_ACCESS_URL` and `CODER_PG_CONNECTION_URL`. Each entry supports `value` or `valueFrom`. | List | `[]` | Yes |
| `coder.envFrom` | ConfigMaps or secrets to import wholesale as environment variables. If you set `CODER_ACCESS_URL` here, you must also set `coder.envUseClusterAccessURL` to `false`. | List | `[]` | No |
| `coder.image.repo` | The repository of the Coder image. | String | `ghcr.io/coder/coder` | No |
| `coder.image.tag` | The image tag. When empty, the chart `appVersion` is used, which is `__VERSION__` for this pack version. | String | `""` | No |
| `coder.image.pullPolicy` | The image pull policy for the Coder container. | String | `IfNotPresent` | No |
| `coder.replicaCount` | The number of deployment replicas. Only increase this when High Availability is licensed and enabled. | Int | `1` | No |
| `coder.resources` | CPU and memory requests and limits for the Coder container. Unset by default, so no requests or limits are applied. | Object | empty | No |
| `coder.service.type` | The type of Service to create for Coder. | String | `LoadBalancer` | No |
| `coder.service.loadBalancerIP` | A static IP address for the LoadBalancer. When empty, a new address is allocated each time the load balancer is recreated. | String | `""` | No |
| `coder.ingress.enable` | Whether to create an Ingress object for Coder. | Bool | `false` | No |
| `coder.ingress.className` | The name of the Ingress class to use. | String | `""` | No |
| `coder.ingress.host` | The hostname the Ingress matches on. Set `CODER_ACCESS_URL` in `coder.env` to the same host. | String | `""` | No |
| `coder.ingress.tls.enable` | Whether to enable TLS on the Ingress. | Bool | `false` | No |
| `coder.ingress.tls.secretName` | The name of the TLS secret used by the Ingress host. A separate `coder.ingress.tls.wildcardSecretName` covers the wildcard host. | String | `""` | No |
| `coder.tls.secretNames` | TLS server certificate secrets of type `kubernetes.io/tls` mounted into the Coder pod for TLS termination by Coder itself. Leave empty when an Ingress terminates TLS. | List | `[]` | No |
| `coder.serviceAccount.workspacePerms` | Whether to grant the Coder service account permission to manage workspace pods and persistent volume claims in the deployment namespace. Keep this enabled when using Kubernetes workspace templates. | Bool | `true` | No |
| `coder.serviceAccount.workspaceNamespaces` | Additional namespaces where Roles and RoleBindings are created so Coder can manage workspaces there without cluster-wide permissions. | List | `[]` | No |
| `coder.readinessProbe.enabled` | Whether to enable the readiness probe on the Coder container. | Bool | `true` | No |
| `coder.livenessProbe.enabled` | Whether to enable the liveness probe on the Coder container. | Bool | `false` | No |
| `coder.podSecurityContext` | Pod-level security context, commonly used to set `fsGroup` so mounted certificate secrets are readable by the Coder user. | Object | `{}` | No |
| `coder.priorityClassName` | The PriorityClass assigned to the Coder pod. The PriorityClass must already exist in the cluster. | String | `""` | No |

For the complete list of supported parameters, review the chart [values.yaml](https://github.com/coder/coder/blob/main/helm/coder/values.yaml).

## Upgrade

> [!CAUTION]
> Overrides now take effect. In pack version 2.23.3 and earlier, the chart values in the pack's `values.yaml` were nested one level too shallow, so Palette overrides were silently ignored and the deployment always ran with chart defaults. This pack version corrects the nesting to `charts.coder.coder.*`. If you previously set values in Palette, review every one of them before upgrading, because they will now be applied to the deployment for the first time.

> [!IMPORTANT]
> `coder.livenessProbe.enabled` now defaults to `false`. In the chart shipped by earlier pack versions the liveness probe was applied unconditionally. If you rely on the liveness probe, set `coder.livenessProbe.enabled` to `true` explicitly.

Additional upgrade notes:

- If you are upgrading from pack version 2.23.3, note that it shipped upstream chart content from version 2.21.3, so the upgrade spans upstream releases 2.21.3 to __VERSION__. Read the Coder [releases and support policy](https://coder.com/docs/install/releases) before planning the change.
- Follow the Coder [Helm upgrade steps](https://coder.com/docs/install/kubernetes#upgrading-coder-via-helm) and back up the PostgreSQL database first. The database holds all deployment state, so a verified backup is the rollback path if you need to return to the previous version.
- New opt-in Gateway API templates are available through `coder.httproute` and `coder.listenerset`. Both default to disabled. Enabling them requires Gateway API v1.5.0 or later CRDs, a Gateway controller that supports ListenerSet, and a parent Gateway with `allowedListeners` configured.
- After the upgrade, confirm the rollout completes and the deployment is healthy:

```bash
kubectl rollout status deployment/coder -n coder
kubectl get pods -n coder
```

## Usage

Add the Coder pack to an add-on cluster profile, then override the default pack configuration. All chart values sit under `charts.coder.coder` in the pack's `values.yaml`.

### 1. Create the PostgreSQL secret

Coder requires an external PostgreSQL database. Create the secret in the same namespace as the deployment before adding the pack, or add it as a manifest layer in the cluster profile. Never inline the database password in the pack values.

```bash
kubectl create namespace coder
kubectl create secret generic coder-db-url \
  --namespace coder \
  --from-literal=url="postgres://coder:PASSWORD@postgres.example.com:5432/coder?sslmode=require"
```

### 2. Set the access URL and database connection

Set `CODER_ACCESS_URL` to the URL users will open in their browser, and read the database DSN from the secret with `valueFrom.secretKeyRef`.

```yaml
charts:
  coder:
    coder:
      env:
        - name: CODER_ACCESS_URL
          value: "https://coder.example.com"
        - name: CODER_PG_CONNECTION_URL
          valueFrom:
            secretKeyRef:
              name: coder-db-url
              key: url
```

### 3. Expose Coder

Use an Ingress when the cluster already has an Ingress controller and you want the controller to terminate TLS. Leave `coder.tls.secretNames` empty in this case.

```yaml
charts:
  coder:
    coder:
      service:
        type: ClusterIP
      ingress:
        enable: true
        className: nginx
        host: coder.example.com
        tls:
          enable: true
          secretName: coder-tls
```

Use the default LoadBalancer service when no Ingress controller is available. Set a static address with `coder.service.loadBalancerIP` in production so the access URL does not change when the load balancer is recreated.

```yaml
charts:
  coder:
    coder:
      service:
        type: LoadBalancer
        loadBalancerIP: "203.0.113.10"
      ingress:
        enable: false
```

If you serve workspace applications over subdomains, also set `coder.ingress.wildcardHost` and the `CODER_WILDCARD_ACCESS_URL` environment variable.

### 4. Create the first administrator

After the deployment becomes ready, open the access URL in a browser and create the first administrator account. Follow the Coder [first login steps](https://coder.com/docs/install/kubernetes#5-log-in-to-coder-) to complete setup, then create a workspace template to let developers provision workspaces.

```bash
kubectl get pods -n coder
kubectl get svc coder -n coder
```

## References

- [Coder documentation](https://coder.com/docs)
- [Install Coder on Kubernetes](https://coder.com/docs/install/kubernetes)
- [Coder Helm chart values.yaml](https://github.com/coder/coder/blob/main/helm/coder/values.yaml)
- [Coder releases and support policy](https://coder.com/docs/install/releases)
- [Coder quickstart](https://coder.com/docs/tutorials/quickstart)
- [Coder Discord community](https://discord.gg/coder)
