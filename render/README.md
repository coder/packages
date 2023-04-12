[Coder](https://coder.com) enables organizations to set up development environments in the cloud. Environments are defined with Terraform, connected through a secure high-speed Wireguard® tunnel, and are automatically shut down when not in use to save on costs. Coder gives engineering teams the flexibility to use the cloud for workloads that are most beneficial to them.

- Define development environments in Terraform
  - EC2 VMs, Kubernetes Pods, Docker Containers, etc.
- Automatically shutdown idle resources to save on costs
- Onboard developers in seconds instead of days

## Quickstart

### 1. Fill the environment variables

The current version of the template allows you to set an optional environment variable, `CODER_WILDCARD_ACCESS_URL` which will allow you to forward ports from your workspace to a custom wildcard subdomain of the URL you provide. This is useful if you want to access a service running in your workspace from a browser. For example, if you set `CODER_WILDCARD_ACCESS_URL` to `*.coder.example.com`, you can access a service running on port 8080 in your workspace by visiting `8080--app-name-workspace-name-.coder.example.com` in your browser.

> Note: This is an optional step. If you do not set this variable, you cannot access services running in your workspace from a browser. You must use a custom domain with Render and cannot use Render's built-in domain for this wildcard.

> Note: You can set environment variables by going to _Dashboard &gt; Coder (Service) &gt; Settings &gt; Environment Variables_. See our [docs](https://coder.com/docs/v2/latest/cli/server) for more information on environment variables that can be set.

### 2. Attach a custom domain

Your Coder deployment will always be accessible at `https://app-name.up.railway.app`. If you want to use a custom domain, you can go to Dashboard &gt; Coder (Service) &gt; Settings &gt; Custom Domains and add your domain and optionally a wildcard subdomain if you specified `CODER_WILDCARD_ACCESS_URL` in the previous step.

### 3. Create your first user

Create your first user by going to `https://app-name.onrender.com` or your custom domain.

![Welcome to Coder](https://raw.githubusercontent.com/coder/blogs/main/posts/coder-on-railway/static/coder_setup.png)

### 3. Create your first template

[**Templates**](https://coder.com/docs/v2/latest/templates): Templates are written in Terraform and describe the infrastructure for workspaces. Coder provides a set of starter templates to help you get started.

Choose a template to set up your first workspace. You can also [create your own templates](https://coder.com/docs/v2/latest/templates) to define your custom infrastructure with your preferred cloud provider.
![starter templates](https://raw.githubusercontent.com/coder/blogs/main/posts/coder-on-railway/static/starter_templates_welcome.png)

### 4. Create your first workspace

[**Workspaces**](https://coder.com/docs/v2/latest/workspaces): Workspaces contain the IDEs, dependencies, and configuration information needed for software development. You can create workspaces from templates. Here wea are showing the workspaces created from the Fly.io starter template in action.
![fly.io workspace](https://raw.githubusercontent.com/coder/blogs/main/posts/coder-on-railway/static/fly_workspace.png)

- [**Coder on GitHub**](https://github.com/coder/coder)
- [**Coder docs**](https://coder.com/docs/v2)
- [**VS Code Extension**](https://marketplace.visualstudio.com/items?itemName=coder.coder-remote): Open any Coder workspace in VS Code with a single click
- [**JetBrains Gateway Extension**](https://plugins.jetbrains.com/plugin/19620-coder): Open any Coder workspace in JetBrains Gateway with a single click

- [**Coder GitHub Action**](https://github.com/marketplace/actions/update-coder-template): A GitHub Action that updates Coder templates
- [**Various Templates**](https://github.com/coder/coder/examples/templates/community-templates.md): Hetzner Cloud, Docker in Docker, and other templates the community has built.
- [![Coder discord](https://img.shields.io/discord/747933592273027093?label=discord)](https://discord.gg/coder)
