---
description: Instructions for using the eirctl command-line tool.
applyTo: "/build/**, /deploy/**"
---

# eirctl Instructions

## CRITICAL RULES

1. **NEVER run `terraform` commands directly.** All Terraform operations MUST go through `eirctl` tasks (e.g.
`eirctl run infra:init`, `eirctl run infra:plan`). The `Invoke-Terraform` wrapper inside eirctl handles pathing,
workspace selection, backend configuration, and runs inside the correct container context.
2. **NEVER set `TF_CLI_ARGS` (the global variant).** It applies to ALL terraform subcommands (init, plan,
workspace, etc.) and will break workspace selection. Use the subcommand-specific form instead, e.g.
`TF_CLI_ARGS_init`, `TF_CLI_ARGS_plan`.
3. **Always source the environment file before running eirctl.** The tasks depend on environment variables for
backend config, credentials, and Terraform variables.

## Architecture Overview

eirctl is the Ensono Independent Runner CLI. It orchestrates tasks defined in YAML inside containers. The
configuration is split across three files:

| File                         | Purpose                                                                                                   |
| ---------------------------- | --------------------------------------------------------------------------------------------------------- |
| `eirctl.yaml`                | Root config — imports task/context files and defines pipelines (ordered task sequences with dependencies) |
| `build/eirctl/tasks.yaml`    | Individual task definitions — each specifies a context, description, and PowerShell commands              |
| `build/eirctl/contexts.yaml` | Container definitions — each context maps to a Docker image with a shell (pwsh)                           |

All tasks run inside Docker containers. The workspace is mounted at `/eirctl/` inside the container, so paths like
`$env:TF_FILE_LOCATION` are container-relative (e.g. `/eirctl/deploy/terraform`).

## Environment Setup

Before running any eirctl commands, source the environment variables:

```bash
source .eirctl/envvar-azure-stacks-aks.sh
```

This file is gitignored and sets:

- `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID` — Azure SPN credentials
- `TF_FILE_LOCATION` — path to Terraform templates (container-relative: `/eirctl/deploy/terraform`)
- `TF_BACKEND_INIT` — comma-separated backend config for `terraform init`
- `TF_BACKEND_PLAN` — arguments for `terraform plan`
- `TF_VAR_*` — all Terraform input variables (company, project, stage, location, DNS, AKS, ACR, etc.)
- `CLOUD_PLATFORM` — set to `azure`

Required variables are validated by `eirctl run setup:environment` and defined in `build/config/stage_envvars.yml`.

## Available Pipelines

Pipelines are ordered sequences of tasks with dependencies. Run them with `eirctl run <pipeline>`.

| Pipeline                 | Purpose                                                 | Tasks (in order)                                                                                           |
| ------------------------ | ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `lint`                   | Lint YAML and Terraform (format + validate)             | `lint:yaml` → `lint:terraform:format` → `lint:terraform:validate`                                          |
| `infrastructure`         | Full deploy: env check → init → plan → apply            | `setup:environment` → `setup:validate:azdo:pat` → `infra:init` → `infra:plan` → `infra:apply`              |
| `infrastructure:upgrade` | Same as `infrastructure` but upgrades modules/providers | Same but uses `infra:init:upgrade` instead of `infra:init`                                                 |
| `infrastructure_destroy` | Tear down: init → destroy plan → destroy apply          | `setup:environment` → `infra:init` → `infra:destroy:plan` → `infra:destroy:apply`                          |
| `tests`                  | Run InSpec compliance tests against deployed resources  | `setup:environment` → `tests:infra:init` → `tests:infra:vendor` → `tests:infra:inputs` → `tests:infra:run` |
| `docs`                   | Build AsciiDoc documentation                            | `build:number` → `_docs`                                                                                   |
| `release`                | Publish a GitHub release                                | `_release`                                                                                                 |

## Available Tasks

Tasks can be run individually with `eirctl run <task>`.

### Terraform Lifecycle

| Task                     | Description                                                                                                                                 |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `infra:init`             | Run `terraform init` with backend config and select/create the workspace from `$TF_VAR_stage`                                               |
| `infra:init:upgrade`     | Same as `infra:init` but passes `-upgrade` to pull latest allowed module/provider versions                                                  |
| `infra:vars`             | Generate `terraform.tfvars` from `TF_VAR_*` environment variables via `Get-TFVars`                                                          |
| `infra:plan`             | Run `terraform plan` outputting to `deploy.tfplan`. Uses `$TF_BACKEND_PLAN` if set, otherwise defaults to `-input=false -out=deploy.tfplan` |
| `infra:apply`            | Run `terraform apply` using the `deploy.tfplan` file created by `infra:plan`                                                                |
| `infra:destroy:plan`     | Run `terraform plan -destroy` outputting to `destroy.tfplan`                                                                                |
| `infra:destroy:apply`    | Run `terraform apply` using `destroy.tfplan`                                                                                                |
| `infra:output`           | Run `terraform output` and write JSON to `.eirctl/output.json`                                                                              |
| `infra:state:lock:clear` | Clear a stuck Terraform state lock from Azure Storage                                                                                       |

### Linting

| Task                      | Description                                               |
| ------------------------- | --------------------------------------------------------- |
| `lint:yaml`               | Run YAML linter via `Invoke-YamlLint`                     |
| `lint:terraform:format`   | Run `terraform fmt -check` via `Invoke-Terraform -Format` |
| `lint:terraform:validate` | Run `terraform validate` via `Invoke-Terraform -Validate` |

### Setup & Validation

| Task                      | Description                                                                                           |
| ------------------------- | ----------------------------------------------------------------------------------------------------- |
| `setup:environment`       | Validate all required environment variables are set (checks against `build/config/stage_envvars.yml`) |
| `setup:validate:azdo:pat` | Validate the Azure DevOps PAT has required scopes                                                     |
| `setup:dev`               | Generate a shell env config script from `build/config/stage_envvars.yml`                              |

### Infrastructure Testing

| Task                 | Description                                                      |
| -------------------- | ---------------------------------------------------------------- |
| `tests:infra:init`   | Initialise the InSpec test profile                               |
| `tests:infra:vendor` | Install InSpec plugins and providers                             |
| `tests:infra:inputs` | Generate the InSpec inputs file from Terraform output            |
| `tests:infra:run`    | Execute InSpec compliance tests against deployed Azure resources |

### Helm & Kubernetes

| Task               | Description                                                                     |
| ------------------ | ------------------------------------------------------------------------------- |
| `infra:helm:apply` | Deploy Helm charts to AKS cluster using config from `deploy/helm/k8s_apps.yaml` |

### Documentation & Release

| Task           | Description                  |
| -------------- | ---------------------------- |
| `_docs`        | Build AsciiDoc documentation |
| `_release`     | Publish a GitHub release     |
| `build:number` | Update the build number      |

## Common Workflows

### Deploy infrastructure locally

```bash
source .eirctl/envvar-azure-stacks-aks.sh
eirctl run infrastructure
```

### Upgrade module/provider versions after changing a source ref

```bash
source .eirctl/envvar-azure-stacks-aks.sh
eirctl run infra:init:upgrade
```

Or use the full pipeline:

```bash
eirctl run infrastructure:upgrade
```

### Validate Terraform without deploying

```bash
source .eirctl/envvar-azure-stacks-aks.sh
eirctl run lint
```

### Run compliance tests after deployment

```bash
source .eirctl/envvar-azure-stacks-aks.sh
eirctl run tests
```

### Destroy infrastructure

```bash
source .eirctl/envvar-azure-stacks-aks.sh
eirctl run infrastructure_destroy
```

## Container Contexts

All tasks run in Docker containers defined in `build/eirctl/contexts.yaml`:

| Context      | Image                       | Used By                              |
| ------------ | --------------------------- | ------------------------------------ |
| `powershell` | `ensono/eir-infrastructure` | All Terraform, setup, and Helm tasks |
| `infratests` | `ensono/eir-inspec`         | InSpec compliance tests              |
| `docs`       | `ensono/eir-asciidoctor`    | Documentation build                  |

Environment variables from the host are automatically forwarded into the container (with exclusion filters for sensitive CI/CD variables).

## Key Environment Variables Reference

| Variable              | Required | Description                                                                                                       |
| --------------------- | -------- | ----------------------------------------------------------------------------------------------------------------- |
| `TF_FILE_LOCATION`    | Yes      | Container-relative path to Terraform files (`/eirctl/deploy/terraform`)                                           |
| `TF_BACKEND_INIT`     | Yes      | Comma-separated backend init args (`key=...,storage_account_name=...,resource_group_name=...,container_name=...`) |
| `TF_BACKEND_PLAN`     | No       | Space-separated plan args; defaults to `-input=false -out=deploy.tfplan`                                          |
| `TF_VAR_stage`        | Yes      | Terraform workspace / deployment stage name (e.g. `dev`, `test`, `prod`)                                          |
| `TF_VAR_company`      | Yes      | Company name for resource naming convention                                                                       |
| `TF_VAR_project`      | Yes      | Project name for resource naming convention                                                                       |
| `TF_VAR_component`    | Yes      | Component name for resource naming convention                                                                     |
| `TF_VAR_location`     | Yes      | Azure region (e.g. `uksouth`)                                                                                     |
| `CLOUD_PLATFORM`      | Yes      | Cloud provider (`azure`)                                                                                          |
| `ARM_CLIENT_ID`       | Yes      | Azure SPN Application (Client) ID                                                                                 |
| `ARM_CLIENT_SECRET`   | Yes      | Azure SPN Client Secret                                                                                           |
| `ARM_SUBSCRIPTION_ID` | Yes      | Azure Subscription ID                                                                                             |
| `ARM_TENANT_ID`       | Yes      | Azure Tenant ID                                                                                                   |

See `build/config/stage_envvars.yml` for the full list of required and optional variables per stage.
