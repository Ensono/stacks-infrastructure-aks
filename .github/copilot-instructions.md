# Ensono Stacks AKS Infrastructure - AI Coding Agent Instructions

## Project Overview

This is an enterprise Terraform-based Azure Kubernetes Service (AKS) infrastructure deployment repository using the Ensono Stacks pattern. It deploys production-ready AKS clusters with associated Azure resources (ACR, DNS, Key Vault, networking) across multiple environments.

## Architecture & Key Components

### Core Infrastructure Stack

- **Terraform modules**: Located in `deploy/terraform/` - uses the `ensono-stacks-foundation-azure` naming module for consistent resource naming
- **AKS Bootstrap**: `deploy/terraform/aks.tf` - primary AKS cluster deployment using external Ensono Stacks modules
- **Multi-environment support**: Single codebase deploys to dev/test/prod via environment variables and Terraform workspaces

### Build & Deployment System

- **EIR (Ensono Independent Runner)**: Uses `eirctl.yaml` for pipeline orchestration with task dependencies
- **Azure DevOps**: Primary CI/CD via `build/azDevOps/azure/deploy-infrastructure.yml` with environment-specific stages
- **Helm deployments**: `deploy/helm/k8s_apps.yaml` defines Kubernetes applications (nginx-ingress, kured, external-dns, etc.)

### Critical Workflow Commands

```bash
# Local development pipeline execution
taskctl lint                    # YAML + Terraform linting
taskctl infrastructure          # Full infra deployment: setup → init → plan → apply
taskctl tests                   # InSpec compliance testing
taskctl docs                    # Generate documentation

# Environment setup (PowerShell)
. ./local/envvar-azure-<stage>.ps1  # Load required TF_VAR_* environment variables
```

## Development Patterns & Conventions

### Naming Convention

- All resources use the pattern: `{company}-{project}-{stage}-{component}`
- Storage accounts use: `{company}{project}{stage}{component}` (alphanumeric only)
- Implemented via `modules/ensono-stacks-foundation-azure/naming.tf`

### Environment Variables Pattern

- **All Terraform vars prefixed with `TF_VAR_`** - automatically converted to terraform.tfvars by `build/scripts/Set-TFVars.ps1`
- **Required vars**: See `docs/getting_started.adoc` table - includes company, project, stage, location, DNS zones, etc.
- **Environment files**: `build/config/stage_envvars.yml` defines per-stage variable templates

### File Organization Logic

- `deploy/terraform/` - Infrastructure as Code
- `deploy/helm/` - Kubernetes application definitions
- `build/eirctl/` - Pipeline task definitions (contexts.yaml, tasks.yaml)
- `build/azDevOps/azure/` - Azure DevOps pipeline templates
- `deploy/tests/controls/` - InSpec compliance tests for deployed resources

### Integration Points

- **External module dependencies**: References `git::https://github.com/Ensono/stacks-terraform` modules
- **Azure DevOps variable groups**: `deploy/terraform/ado_variable_group.tf` manages pipeline variables
- **DNS integration**: Supports both public DNS zones and private internal zones
- **Certificate management**: SSL/TLS via Key Vault and Application Gateway

## Testing & Validation

- **InSpec tests**: `deploy/tests/controls/` - validates deployed Azure resources (AKS cluster, networking, etc.)
- **Terraform validation**: Built into lint pipeline via eirctl tasks
- **Multi-stage deployment**: NonProd → Prod promotion based on git branch (feature → master)

## Key Files for Context

- `eirctl.yaml` - Pipeline orchestration and task dependencies
- `deploy/terraform/main.tf` - Core Terraform entry point using naming module
- `deploy/terraform/aks.tf` - AKS cluster configuration with all Azure integrations
- `build/azDevOps/azure/deploy-infrastructure.yml` - Complete CI/CD pipeline definition
- `docs/getting_started.adoc` - Complete environment variable reference table
