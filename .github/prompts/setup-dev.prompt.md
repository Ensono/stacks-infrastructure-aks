---
agent: agent
name: setup-dev
description: Run eirctl setup:dev and populate the environment variables file with all available information.
model: Auto (copilot)
---

You are an experienced DevOps/Platform engineer helping to configure the local development environment for this Stacks AKS infrastructure project.

Follow this EXACT workflow:

## 1. GENERATE – Create the environment variables template

Run the setup:dev task to generate the environment variables shell script:

```bash
eirctl run setup:dev
```

This command creates or updates the file at `./local/envvar-azure-stacks-aks.sh` with all required environment variables.

## 2. POPULATE – Fill in known values from the repository

After generating the template, populate the environment variables file using values from the repository configuration files:

### Values available from pipeline-vars.yml (#file:../../build/azDevOps/azure/pipeline-vars.yml):

| Variable                      | Source Value                                                           |
| ----------------------------- | ---------------------------------------------------------------------- |
| `CLOUD_PLATFORM`              | `azure`                                                                |
| `TF_FILE_LOCATION`            | `/eirctl/deploy/terraform`                                             |
| `TF_VAR_company`              | `ed` (from `company`)                                                  |
| `TF_VAR_project`              | `stacks` (from `project`)                                              |
| `TF_VAR_component`            | `core` (from `domain`)                                                 |
| `TF_VAR_environment`          | `dev` (or your target environment)                                     |
| `TF_VAR_stage`                | `dev` (or your target environment)                                     |
| `TF_VAR_location`             | `uksouth` (from `region`)                                              |
| `TF_VAR_dns_zone`             | `nonprod.stacks.ensono.com` (from `base_domain_nonprod`)               |
| `TF_VAR_internal_dns_zone`    | `nonprod.stacks.ensono.internal` (from `base_domain_internal_nonprod`) |
| `TF_VAR_dns_resource_group`   | `stacks-dns-zones`                                                     |
| `TF_VAR_create_dns_zone`      | `false`                                                                |
| `TF_VAR_create_aksvnet`       | `true`                                                                 |
| `TF_VAR_cluster_version`      | `1.34.1` (from `aks_cluster_version`)                                  |
| `TF_VAR_create_acr`           | `false`                                                                |
| `TF_VAR_acr_resource_group`   | `stacks-dns-zones`                                                     |
| `TF_VAR_acr_name`             | `ensonouks`                                                            |
| `TF_VAR_is_cluster_private`   | `true` (from `private_cluster`)                                        |
| `TF_VAR_acme_email`           | `stacks@ensono.com`                                                    |
| `TF_VAR_create_user_identity` | `true`                                                                 |
| `TF_VAR_pfx_password`         | `Password1` (development only - use a secure password for production)  |

### Terraform Backend Configuration:

```bash
TF_BACKEND_INIT="key=core,container_name=tfstate,storage_account_name=stacksstatehjfis,resource_group_name=stacks-terraform-state"
TF_BACKEND_PLAN='-input=false,-out="deploy.tfplan"'
```

## 3. REPORT – Identify unknown variables requiring user input

After populating the file, clearly inform the user about values that MUST be obtained manually:

### Azure Service Principal Credentials (REQUIRED)

These credentials are sensitive and must be obtained from Azure:

| Variable              | How to Obtain                                                                                                 |
| --------------------- | ------------------------------------------------------------------------------------------------------------- |
| `ARM_CLIENT_ID`       | Azure Portal → Microsoft Entra ID → App registrations → Your app → Application (client) ID                    |
| `ARM_CLIENT_SECRET`   | Azure Portal → Microsoft Entra ID → App registrations → Your app → Certificates & secrets → New client secret |
| `ARM_SUBSCRIPTION_ID` | Azure Portal → Subscriptions → Your subscription → Subscription ID                                            |
| `ARM_TENANT_ID`       | Azure Portal → Microsoft Entra ID → Overview → Tenant ID                                                      |

**Alternative**: Use Azure CLI to retrieve these values:

```bash
# Login to Azure
az login

# Get subscription and tenant ID
az account show --query "{subscriptionId:id, tenantId:tenantId}" -o table

# Create a service principal (if needed) and get credentials
az ad sp create-for-rbac --name "stacks-aks-dev" --role contributor \
  --scopes /subscriptions/<subscription-id> \
  --query "{clientId:appId, clientSecret:password, tenantId:tenant}" -o table
```

### Optional Variables

| Variable                | Description                  | Default Behavior                |
| ----------------------- | ---------------------------- | ------------------------------- |
| `TF_VAR_attributes`     | Additional naming attributes | Defaults to empty array         |
| `TF_VAR_tags`           | Additional resource tags     | Defaults to empty map           |
| `TF_VAR_key_vault_name` | Custom Key Vault name        | Auto-generated if not specified |

## 4. UPDATE – Apply the populated values

Update the `./local/envvar-azure-stacks-aks.sh` file with all known values, leaving placeholders for credentials:

```bash
# The Cloud platform for which these variables are being set
export CLOUD_PLATFORM="azure"

# Azure credentials - OBTAIN FROM AZURE PORTAL OR CLI
export ARM_CLIENT_ID="<your-service-principal-client-id>"
export ARM_CLIENT_SECRET="<your-service-principal-client-secret>"
export ARM_SUBSCRIPTION_ID="<your-azure-subscription-id>"
export ARM_TENANT_ID="<your-azure-tenant-id>"

# Terraform configuration
export TF_FILE_LOCATION="/eirctl/deploy/terraform"
export TF_BACKEND_INIT="key=core,container_name=tfstate,storage_account_name=stacksstatehjfis,resource_group_name=stacks-terraform-state"
export TF_BACKEND_PLAN='-input=false,-out="deploy.tfplan"'

# Naming convention variables
export TF_VAR_company="ed"
export TF_VAR_project="stacks"
export TF_VAR_component="core"
export TF_VAR_environment="dev"
export TF_VAR_stage="dev"

# Azure location
export TF_VAR_location="uksouth"

# DNS configuration
export TF_VAR_dns_zone="nonprod.stacks.ensono.com"
export TF_VAR_internal_dns_zone="nonprod.stacks.ensono.internal"
export TF_VAR_dns_resource_group="stacks-dns-zones"
export TF_VAR_create_dns_zone="false"

# AKS configuration
export TF_VAR_create_aksvnet="true"
export TF_VAR_cluster_version="1.34.1"
export TF_VAR_is_cluster_private="true"
export TF_VAR_create_user_identity="true"

# Container registry
export TF_VAR_create_acr="false"
export TF_VAR_acr_resource_group="stacks-dns-zones"
export TF_VAR_acr_name="ensonoeuw"

# Certificate configuration
export TF_VAR_pfx_password="Password1"
export TF_VAR_acme_email="stacks@ensono.com"
```

## 5. VERIFY – Confirm setup is complete

After updating the file, remind the user to:

1. **Source the environment file** before running infrastructure commands:

   ```bash
   source ./local/envvar-azure-stacks-aks.sh
   ```

2. **Verify the environment** using the setup:environment task:

   ```bash
   eirctl run setup:environment
   ```

3. **Never commit credentials** - ensure `./local/` is in `.gitignore`

## 6. NEXT STEPS – Run the initial workflow

After verification, run the standard local flow (requires Azure creds to be set):

```bash
# ensure env is loaded in the current shell
source ./local/envvar-azure-stacks-aks.sh

# sanity-check required variables
eirctl run setup:environment

# terraform init/plan
eirctl run infra:init
eirctl run infra:plan

# apply infrastructure then charts
eirctl run infrastructure
eirctl run infra:helm:apply
```

## Summary

After completing this prompt, inform the user which values were populated automatically and which require manual input, presenting the credential variables prominently in the chat so they can easily see what still needs to be configured.
