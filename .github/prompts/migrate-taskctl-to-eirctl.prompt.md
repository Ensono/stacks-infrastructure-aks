---
agent: agent
name: migrate-to-eirctl
description: Safely migrate the repository from taskctl to eirctl with full validation and testing.
model: Auto (copilot)
---

You are an experienced DevOps/Platform engineer specializing in build automation and CI/CD systems. Your goal for THIS RUN is to safely migrate this repository from taskctl to eirctl (the officially supported evolution of taskctl for Ensono Stacks projects).

**CRITICAL**: This is infrastructure automation - prioritize safety over speed. Every change must be validated before proceeding to the next phase.

Follow this EXACT workflow:

## 1. DISCOVER – Inventory current taskctl configuration

Before making ANY changes, thoroughly understand the current setup:

### 1.1 Verify eirctl Documentation Access

Fetch and review the official migration guide:

- Primary source: https://github.com/Ensono/eirctl/tree/docs/migration/docs
- Look for: migration guides, breaking changes, syntax conversion examples
- Verify you can access and understand the documentation

If documentation is unavailable or unclear, STOP and ask me for clarification.

### 1.1b Check for Latest Container Versions

Identify and document the latest versions of all containers in use:

```bash
# Check Ensono Stacks organization for release information
curl -s https://api.github.com/repos/Ensono/stacks/releases/latest | grep -E '"tag_name"|"body"' | head -5

# Check latest runner-pwsh on Docker Hub
curl -s https://registry.hub.docker.com/v2/repositories/amidostacks/runner-pwsh/tags/ 2>/dev/null | grep -o '"name":"[^"]*"' | head -10

# Check Ensono images on Docker Hub
curl -s https://registry.hub.docker.com/v2/repositories/ensono/eir-infrastructure/tags/ 2>/dev/null | grep -o '"name":"[^"]*"' | head -10
curl -s https://registry.hub.docker.com/v2/repositories/ensono/eir-inspec/tags/ 2>/dev/null | grep -o '"name":"[^"]*"' | head -10
curl -s https://registry.hub.docker.com/v2/repositories/ensono/eir-asciidoctor/tags/ 2>/dev/null | grep -o '"name":"[^"]*"' | head -10
```

Current versions in use:

- `ensono/eir-infrastructure` (powershell context)
- `ensono/eir-inspec` (infratests context)  
- `ensono/eir-asciidoctor` (docs context)

Note: Container image versions may be unpinned to use latest. Consider pinning to specific versions for production stability.

### 1.1c Check for GitHub Actions and GitLab CI

Search the repository for GitHub Actions workflows and GitLab CI/CD configurations:

```bash
# Check for GitHub Actions workflows
find .github/workflows -name "*.yml" -o -name "*.yaml" 2>/dev/null | head -20

# Check for GitLab CI
find . -name ".gitlab-ci.yml" -o -name ".gitlab" -type d 2>/dev/null

# Check dependabot configuration
cat .github/dependabot.yml 2>/dev/null || echo "No dependabot.yml found"
```

Expected findings:

- GitHub Actions: Check if taskctl is referenced in any workflows
- GitLab CI: Check if taskctl is referenced in .gitlab-ci.yml
- Dependabot: May need updates for new container image versions

Document any taskctl references for updating in Phase 4.

### 1.2 Inventory All taskctl Files

Create a complete inventory of files to migrate:

| File Type   | Current Location              | Target Location              | Purpose                                       |
| ----------- | ----------------------------- | ---------------------------- | --------------------------------------------- |
| Root config | `taskctl.yaml`                | `eirctl.yaml`                | Main configuration with imports and pipelines |
| Contexts    | `build/taskctl/contexts.yaml` | `build/eirctl/contexts.yaml` | Container/execution context definitions       |
| Tasks       | `build/taskctl/tasks.yaml`    | `build/eirctl/tasks.yaml`    | Task definitions and commands                 |

### 1.3 Analyze Current Configuration

Examine the following in detail:

1. **Contexts** (in [build/taskctl/contexts.yaml](../../build/taskctl/contexts.yaml)):
   - Count contexts: Expect 3 (powershell, infratests, docs)
   - Note container images and versions
   - Identify all paths using `/app/` prefix
   - Check for `-NoProfile` flags in PowerShell contexts (CRITICAL: must be removed)

2. **Tasks** (in [build/taskctl/tasks.yaml](../../build/taskctl/tasks.yaml)):

- Count tasks: Expect >1; use current tasks as examples (e.g., build:number, lint:yaml, lint:terraform:format, lint:terraform:validate, infra:init, infra:vars, infra:plan, infra:apply, infra:destroy:plan, infra:destroy:apply, infra:output, setup:dev, setup:environment, tests:infra:init, tests:infra:vendor, tests:infra:inputs, tests:infra:run, infra:helm:apply, \_docs, \_release)
- List all script paths (e.g., `/app/build/scripts/Set-TFVars.ps1`)
- Identify Terraform file location references (`/app/deploy/terraform`)
- Note environment variable dependencies

3. **Pipelines** (in [taskctl.yaml](../../taskctl.yaml)):
   - Count pipelines: Expect 6 (lint, tests, infrastructure, infrastructure_destroy, docs, release)
   - Document pipeline dependencies and execution order

4. **CI/CD Integration**:
   - Scan [build/azDevOps/azure/deploy-infrastructure.yml](../../build/azDevOps/azure/deploy-infrastructure.yml) for `taskctl` references
   - Check [build/azDevOps/azure/agent-config-vars.yml](../../build/azDevOps/azure/agent-config-vars.yml) for version variable
   - Look for setup template in [build/azDevOps/azure/templates/setup.yml](../../build/azDevOps/azure/templates/setup.yml)

### 1.4 Report Findings

Before proceeding, report:

- Total contexts, tasks, and pipelines found
- Number of files requiring updates
- Critical issues discovered (missing files, unexpected structure)
- Latest container image versions available
- Any GitHub Actions workflows or GitLab CI configurations that need updating
- Container versions to update to

**STOP HERE** and wait for my confirmation before proceeding to Phase 2.

---

## 2. MODERNIZE – Convert contexts to eirctl syntax

eirctl uses a container-first approach with significantly cleaner syntax. This phase converts all 4 contexts.

### 2.1 Understanding the Conversion

**Key Changes in eirctl Contexts:**

| taskctl Concept                                 | eirctl Equivalent                                             | Notes                                                                 |
| ----------------------------------------------- | ------------------------------------------------------------- | --------------------------------------------------------------------- |
| `executable.bin: docker` + verbose args         | `container.name: <image>`                                     | Auto-handles docker run, mounts, working dir                          |
| Working dir: `/app`                             | Working dir: `/eirctl`                                        | Default mount point changed                                           |
| `executable.args: [pwsh, -NoProfile, -Command]` | `container.shell: pwsh`<br>`container.shell_args: [-Command]` | **Remove `-NoProfile`** - eirctl requires profiles for module loading |
| Manual volume mounts in args                    | Automatic                                                     | eirctl auto-mounts workspace at `/eirctl`                             |
| Manual `--env-file` in args                     | `envfile:` config                                             | Simplified, supports in-file variable references                      |

### 2.2 Conversion Template

For each context, apply this transformation:

**Before (taskctl):**

```yaml
contexts:
  powershell:
    executable:
      bin: docker
      args:
        - run
        - --env-file
        - envfile
        - --rm
        - -v
        - ${PWD}:/app
        - -v
        - /var/run/docker.sock:/var/run/docker.sock
        - -e
        - PSModulePath=/modules
        - -w
        - /app
        - ensonostackseuweirdfmu.azurecr.io/ensono/eir-infrastructure:1.1.91
        - pwsh
        - -NoProfile
        - -Command
    quote: "'"
    envfile:
      generate: true
      exclude:
        - path
        - home
        - kubeconfig
```

**After (eirctl):**

```yaml
contexts:
  powershell:
    container:
      name: docker.io/ensono/eir-infrastructure:1.2.39
      shell: pwsh
      shell_args:
        - -Command
      volumes:
        - /var/run/docker.sock:/var/run/docker.sock
    quote: "'"
    envfile:
      exclude:
        - path
        - home
        - kubeconfig
    env:
      PSModulePath: /modules
```

**Critical changes:**

- ✅ Removed `executable.bin` and `executable.args`
- ✅ Added `container.name`, `container.shell`, `container.shell_args`
- ✅ **REMOVED `-NoProfile`** (eirctl requires profiles for PowerShell module imports)
- ✅ Moved `-e PSModulePath=/modules` to `env:` section
- ✅ Removed `envfile.generate: true` (automatic in eirctl)
- ✅ Removed manual Docker volume mounts (automatic in eirctl)

### 2.3 Convert All 3 Contexts

Apply the conversion to:

1. **powershell** - Primary context for Terraform, linting, Helm
2. **infratests** - InSpec testing context
3. **docs** - Documentation build context (uses eir-asciidoctor image)

**Note**: The `powershell-python` context has been removed. If Python functionality is needed, use the `powershell` context which has Python available.

For contexts that need Docker socket access, add volume mounting:

```yaml
container:
  name: <image>
  shell: pwsh
  shell_args:
    - -Command
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
```

Contexts needing Docker socket: powershell, infratests (not docs)

### 2.4 Verify Context Conversion

Check each converted context:

- [ ] All 3 contexts converted (powershell, infratests, docs)
- [ ] No `-NoProfile` flags remain
- [ ] Container images specified correctly
- [ ] Environment variables moved to `env:` section
- [ ] `envfile.exclude` lists preserved
- [ ] Quote character preserved if specified

**CHECKPOINT**: Show me the converted contexts before proceeding.

---

## 3. UPDATE – Migrate file structure and path references

Now update file locations, path references, and task definitions.

### 3.1 Rename Configuration Files

Execute the following commands to migrate the configuration:

```bash
# Rename files (no backup needed - git maintains history)
git mv taskctl.yaml eirctl.yaml
git mv build/taskctl build/eirctl
```

This clean migration approach removes the old taskctl configuration while git maintains full history for recovery if needed.

### 3.2 Update Import Statements

In the newly renamed `eirctl.yaml`, update import paths:

**Before:**

```yaml
import:
  - ./build/taskctl/contexts.yaml
  - ./build/taskctl/tasks.yaml
```

**After:**

```yaml
import:
  - ./build/eirctl/contexts.yaml
  - ./build/eirctl/tasks.yaml
```

### 3.3 Verify Path References in Tasks

**Path Convention:**

The containers mount the workspace at `/app`. All paths should use this absolute prefix for consistency with the container environment.

Verify these paths exist in `build/eirctl/tasks.yaml`:

| Path                                         | Purpose                           |
| -------------------------------------------- | --------------------------------- |
| `/app/build/scripts/Set-TFVars.ps1`          | Generate tfvars file              |
| `/app/build/scripts/Set-EnvironmentVars.ps1` | Set environment from TF outputs   |
| `/app/build/scripts/Deploy-HelmCharts.ps1`   | Deploy Helm charts                |
| `/app/deploy/terraform`                      | Terraform templates               |
| `/app/deploy/tests`                          | InSpec tests                      |
| `/app/outputs`                               | Build outputs                     |

**Environment variable defaults:**

- `TF_FILE_LOCATION` should be set to `/app/deploy/terraform`
- Verify all task commands use `/app/` prefix consistently

### 3.4 Update Specific Tasks

Review and verify these tasks in `build/eirctl/tasks.yaml` use correct paths:

**Task: `infra:vars`**

```yaml
# Command should use /app/ prefix:
command:
  - /app/build/scripts/Set-TFVars.ps1 | Out-File -Path "${env:TF_FILE_LOCATION}/terraform.tfvars"
```

**Task: `setup:dev`**

```yaml
# Command should use /app/ prefix:
command:
  - New-EnvConfig -Path /app/build/config/stage_envvars.yml -ScriptPath /app/local
```

**Task: `infra:helm:apply`**

```yaml
# Script path should use /app/ prefix:
command:
  - /app/build/scripts/Deploy-HelmCharts.ps1 -Path /app/deploy/helm/k8s_apps.yaml ...
```

**Task: `tests:infra:run`**

```yaml
# INSPEC_FILES should use /app/ prefix:
env:
  INSPEC_FILES: /app/deploy/tests
```

**Task: `_docs`**

```yaml
# Uses docs context (eir-asciidoctor) instead of powershell
# Command:
command: |
  /app/build/scripts/New-Glossary.ps1 -docpath /app/docs -path /app/tmp/glossary.adoc
  Invoke-AsciiDoc -PDF -basepath /app -config /app/docs.json -debug
```

**Task: `infra:apply` (CRITICAL PATH FIX)**

The `Invoke-Terraform -Apply` command with `-Path` sets the working directory to `TF_FILE_LOCATION`. If you also include `TF_FILE_LOCATION` in the plan file path, it creates a double-nested path that doesn't exist.

```yaml
# WRONG - causes "no such file or directory" error:
command:
  - Invoke-Terraform -Apply -Path "${env:TF_FILE_LOCATION}/deploy.tfplan"
# This looks for ./deploy/terraform/deploy/terraform/deploy.tfplan

# CORRECT - reference plan file relative to the working directory:
command:
  - Invoke-Terraform -Apply -Path $env:TF_FILE_LOCATION -Arguments "deploy.tfplan"
```

**Task: `infra:destroy:apply` (CRITICAL PATH FIX)**

Same issue applies to the destroy apply task:

```yaml
# WRONG:
command:
  - Invoke-Terraform -Apply -Path "${env:TF_FILE_LOCATION}/destroy.tfplan" -Arguments "-destroy" -debug

# CORRECT:
command:
  - Invoke-Terraform -Apply -Path $env:TF_FILE_LOCATION -Arguments "destroy.tfplan" -debug
```

**Verify these tasks are correctly configured:**

```bash
# Check for incorrect path patterns in apply tasks
grep -A2 "infra:apply\|infra:destroy:apply" build/eirctl/tasks.yaml | grep -E '\$\{?env:TF_FILE_LOCATION\}?.*\.tfplan'

# If matches found, the paths need fixing - plan files should be passed via -Arguments, not concatenated to -Path
```

### 3.5 Verify File Structure

After updates:

```bash
# Check new structure exists
ls -la eirctl.yaml
ls -la build/eirctl/

# Verify no references to old structure remain
grep -r "taskctl" build/eirctl/ || echo "✓ No taskctl references in build/eirctl/"

# Verify /app/ paths are used consistently
grep -r "/app/" build/eirctl/tasks.yaml && echo "✓ /app/ paths found in tasks"

# Verify old taskctl directory is removed (only in git, working directory may have backups)
ls -la build/taskctl 2>/dev/null && echo "Warning: taskctl directory still exists" || echo "✓ taskctl directory cleaned"
```

**CHECKPOINT**: Confirm file renames and path updates complete before proceeding.

---

## 4. INTEGRATE – Update CI/CD pipelines

Update Azure DevOps pipelines, GitHub Actions, and any other CI/CD systems to use eirctl instead of taskctl.

### 4.1 Determine Latest eirctl Version and Container Versions

Get the latest release versions:

```bash
# Get latest eirctl version
EIRCTL_VERSION=$(curl -s https://api.github.com/repos/ensono/eirctl/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
echo "Latest eirctl: $EIRCTL_VERSION"

# Check for latest container versions (documented from Phase 1.1b)
# Use the versions identified in the discovery phase
```

Expected format for eirctl: `v0.x.x` (e.g., `v0.9.7`)

### 4.1b Update Container Image Versions

Update all container image versions to the latest stable versions identified in Phase 1.1b:

```bash
# In build/eirctl/contexts.yaml, update:
# - eir-infrastructure (docker.io/ensono/eir-infrastructure) - used by powershell context
# - eir-inspec (docker.io/ensono/eir-inspec) - used by infratests context
# - eir-asciidoctor (docker.io/ensono/eir-asciidoctor) - used by docsenv context
# - runner-pwsh (amidostacks/runner-pwsh) - used by powershell-python context

# Example patterns to find and update:
# Old: docker.io/ensono/eir-infrastructure:1.2.39
# New: docker.io/ensono/eir-infrastructure:<NEW_VERSION>
```

### 4.1c Check GitHub Actions Workflows

Search for and update any GitHub Actions workflows that reference taskctl:

```bash
# Find GitHub Actions workflows
find .github/workflows -name "*.yml" -o -name "*.yaml" 2>/dev/null

# Search for taskctl references in workflows
grep -r "taskctl" .github/workflows/ 2>/dev/null || echo "✓ No taskctl references in GitHub Actions"

# Update any found references:
# Replace: taskctl <pipeline>
# With:    eirctl run <pipeline>
```

### 4.1d Check GitLab CI Configuration

If GitLab CI exists, search for and update taskctl references:

```bash
# Check for GitLab CI files
[ -f ".gitlab-ci.yml" ] && echo "Found .gitlab-ci.yml" || echo "No .gitlab-ci.yml"

# Search for taskctl references
grep -r "taskctl" .gitlab-ci.yml 2>/dev/null || echo "✓ No taskctl references in GitLab CI"

# Update any found references similar to GitHub Actions
```

### 4.2 Update Version Variable

In [build/azDevOps/azure/agent-config-vars.yml](../../build/azDevOps/azure/agent-config-vars.yml):

**Before:**

```yaml
variables:
  - name: TaskctlVersion
    value: 1.5.0
```

**After:**

```yaml
variables:
  - name: EirctlVersion
    value: <latest_version> # e.g., 1.2.3 (without 'v' prefix)
```

### 4.3 Update Setup Template

In [build/azDevOps/azure/templates/setup.yml](../../build/azDevOps/azure/templates/setup.yml):

**Update parameter name:**

```yaml
# Before:
parameters:
  - name: TaskctlVersion
    type: string
    default: $(TaskctlVersion)

# After:
parameters:
  - name: EirctlVersion
    type: string
    default: $(EirctlVersion)
```

**Update download and installation:**

```bash
# Before:
sudo wget https://github.com/Ensono/taskctl/releases/download/v${{ parameters.TaskctlVersion }}/taskctl-linux-amd64 -O /usr/local/bin/taskctl
sudo chmod +x /usr/local/bin/taskctl

# After:
set -euo pipefail

EIRCTL_URL="https://github.com/Ensono/eirctl/releases/download/${{ parameters.EirctlVersion }}/eirctl-linux-amd64"
EIRCTL_PATH="/usr/local/bin/eirctl"

echo "Downloading eirctl ${{ parameters.EirctlVersion }} from ${EIRCTL_URL}..."

if ! sudo wget --timeout=30 --tries=3 -q "${EIRCTL_URL}" -O "${EIRCTL_PATH}"; then
  echo "##[error]Failed to download eirctl from ${EIRCTL_URL}"
  echo "##[error]Please verify the version '${{ parameters.EirctlVersion }}' exists at https://github.com/Ensono/eirctl/releases"
  exit 1
fi

sudo chmod +x "${EIRCTL_PATH}"

if ! eirctl --version; then
  echo "##[error]eirctl installation verification failed"
  exit 1
fi

echo "eirctl installed successfully"
```

### 4.4 Update Template Parameter Usage

In [build/azDevOps/azure/templates/setup.yml](../../build/azDevOps/azure/templates/setup.yml), update the parameter reference:

**Before:**

```yaml
parameters:
  TaskctlVersion: ${{ variables.TaskctlVersion }}
```

**After:**

```yaml
parameters:
  EirctlVersion: ${{ variables.EirctlVersion }}
```

### 4.4b Add Docker Hub Login Step

To avoid Docker Hub rate limiting (which can cause extremely slow image pulls at ~1Kbps), add a Docker Hub login step to all jobs that run eirctl commands.

**Pre-requisite:** Create a Docker Hub service connection in Azure DevOps named `DockerHubServiceConnection`.

**Add this step after `setup.yml` template in each job:**

```yaml
# Login to Docker Hub to avoid rate limiting
- task: Docker@2
  displayName: Login to Docker Hub
  inputs:
    command: login
    containerRegistry: DockerHubServiceConnection
```

**Jobs requiring Docker Hub login:**

1. **Build stage** - Setup job (before lint and docs tasks)
2. **Infrastructure deployment** - InfraNonProd/InfraProd jobs
3. **Helm deployment** - K8sNonProd/K8sProd jobs
4. **Release stage** - CreateGitHubRelease job

**Example placement in deploy-infrastructure.yml:**

```yaml
steps:
  - template: templates/setup.yml
    parameters:
      EirctlVersion: ${{ variables.EirctlVersion }}

  # Login to Docker Hub to avoid rate limiting
  - task: Docker@2
    displayName: Login to Docker Hub
    inputs:
      command: login
      containerRegistry: DockerHubServiceConnection

  # Now eirctl commands will pull images with authenticated rate limits
  - task: Bash@3
    displayName: Lint
    inputs:
      targetType: inline
      script: |
        eirctl run lint
```

**Why this is needed:**

- Docker Hub limits anonymous pulls to 100 per 6 hours per IP
- Azure DevOps hosted agents share IPs with many other users
- Authenticated users get 200 pulls per 6 hours
- Without login, image pulls can be throttled to ~1Kbps

### 4.5 Update All Pipeline Task Invocations

In [build/azDevOps/azure/deploy-infrastructure.yml](../../build/azDevOps/azure/deploy-infrastructure.yml), find and replace ALL occurrences:

**Pattern to find:** `taskctl <pipeline_name>`
**Replace with:** `eirctl run <pipeline_name>`

Expected replacements - count taskctl references in all CI/CD files:

- `taskctl lint` → `eirctl run lint`
- `taskctl docs` → `eirctl run docs`
- `taskctl infra:vars` → `eirctl run infra:vars`
- `taskctl infrastructure` → `eirctl run infrastructure`
- `taskctl infrastructure_destroy` → `eirctl run infrastructure_destroy`
- `taskctl infra:init` → `eirctl run infra:init`
- `taskctl infra:plan` → `eirctl run infra:plan`
- `taskctl infra:helm:apply` → `eirctl run infra:helm:apply`
- `taskctl release` → `eirctl run release`

**Search systematically:**

```bash
# Count occurrences
grep -c "taskctl " build/azDevOps/azure/deploy-infrastructure.yml

# Show all occurrences with context
grep -n "taskctl " build/azDevOps/azure/deploy-infrastructure.yml
```

### 4.6 Verify `/app/` Paths in CI/CD Pipelines

The CI/CD pipeline files should contain environment variable definitions that use `/app/` paths. Verify these are correct:

**Files to check:**

- [build/azDevOps/azure/deploy-infrastructure.yml](../../build/azDevOps/azure/deploy-infrastructure.yml)
- [build/azDevOps/azure/templates/infra-tests.yml](../../build/azDevOps/azure/templates/infra-tests.yml)
- [build/azDevOps/azure/infrastructure-tests.yml](../../build/azDevOps/azure/infrastructure-tests.yml)

**Verify these paths in pipeline `env:` blocks:**

| Variable              | Expected Value               |
| --------------------- | ---------------------------- |
| `TF_FILE_LOCATION`    | `/app/deploy/terraform`      |
| `INSPEC_FILES`        | `/app/deploy/tests`          |
| `INSPEC_OUTPUT_PATH`  | `/app/outputs/tests`         |

**Verify /app/ paths exist:**

```bash
# Count /app/ references (should be > 0)
grep -r "/app/" build/azDevOps/ 2>/dev/null | wc -l
```

### 4.7 Verify CI/CD Updates

Check completeness:

```bash
# Should return 0 matches for taskctl in Azure DevOps
grep -r "taskctl" build/azDevOps/ 2>/dev/null | wc -l

# Should return > 0 matches for /app/ paths in Azure DevOps (paths should use /app/)
grep -r "/app/" build/azDevOps/ 2>/dev/null | wc -l

# Should return 0 matches in GitHub Actions (if present)
grep -r "taskctl" .github/workflows/ 2>/dev/null | wc -l

# Should return 0 matches in GitLab CI (if present)
grep -r "taskctl" .gitlab-ci.yml 2>/dev/null | wc -l

# Should find multiple "eirctl run" matches in Azure DevOps
grep -r "eirctl run" build/azDevOps/ 2>/dev/null | wc -l
```

**CHECKPOINT**: Verify all pipeline references updated before proceeding.

---

## 5. VERIFY – Test and validate the migration

Thorough testing is CRITICAL. This phase validates the migration before committing changes.

### 5.1 Install eirctl Locally

Before testing, install eirctl:

```bash
set -euo pipefail

# Get latest version
EIRCTL_VERSION=$(curl -sf https://api.github.com/repos/ensono/eirctl/releases/latest | grep '"tag_name"' | cut -d'"' -f4 | sed 's/v//')

if [[ -z "${EIRCTL_VERSION}" ]]; then
  echo "Failed to fetch latest eirctl version"
  exit 1
fi

echo "Installing eirctl version ${EIRCTL_VERSION}..."

# Download and install
EIRCTL_URL="https://github.com/Ensono/eirctl/releases/download/v${EIRCTL_VERSION}/eirctl-linux-amd64"

if ! sudo wget --timeout=30 --tries=3 -q "${EIRCTL_URL}" -O /usr/local/bin/eirctl; then
  echo "Failed to download eirctl from ${EIRCTL_URL}"
  exit 1
fi

sudo chmod +x /usr/local/bin/eirctl

# Verify installation
if ! eirctl version; then
  echo "eirctl installation verification failed"
  exit 1
fi

echo "eirctl installed successfully"
```

Expected output: `eirctl --version v<version>`

### 5.2 Verify Configuration Syntax

Test configuration parsing:

```bash
# List all pipelines (should show 5: lint, tests, infrastructure, infrastructure_destroy, docs, release)
eirctl list

# Show pipeline details
eirctl graph lint
eirctl graph infrastructure
```

**Expected output:**

- No syntax errors
- All pipelines listed correctly
- Task dependencies shown in graph

If errors occur:

- Check YAML syntax in `eirctl.yaml`, `build/eirctl/contexts.yaml`, `build/eirctl/tasks.yaml`
- Verify import paths are correct
- Look for indentation issues or invalid keys

### 5.3 Test Lint Pipeline

Start with the safest pipeline (no infrastructure changes):

```bash
# Run linting
eirctl run lint
```

**Expected behavior:**

- Containers pull successfully
- YAML linting runs
- Terraform format check runs
- Terraform validation runs
- Exit code 0

**If failures occur:**

1. **Container pull errors**: Verify container images are accessible
   - Check image names in `build/eirctl/contexts.yaml`
   - Test manual pull: `docker pull <image_name>`

2. **Path not found errors**:
   - Verify relative paths are correct
   - Check working directory is mounted properly

3. **Command not found errors**:
   - Verify PowerShell modules are loaded (profile dependency)
   - Check if `-NoProfile` was properly removed from contexts

### 5.4 Test Infrastructure Plan (Dry Run)

Test Terraform operations WITHOUT applying:

```bash
# Set required environment variables (adjust for your environment)
export TF_FILE_LOCATION="/app/deploy/terraform"
export TF_VAR_environment="test"
export TF_BACKEND_INIT="key=core,container_name=tfstate,storage_account_name=<your_storage>,resource_group_name=<your_rg>"

# Set other required TF_VAR_* variables from build/config/stage_envvars.yml
# (This is a comprehensive list - consult the file for all required variables)

# Run infrastructure init and plan
eirctl run infra:init
eirctl run infra:plan
```

**Expected behavior:**

- Terraform initializes successfully
- Terraform plan generates without errors
- No unexpected resource changes (if running against existing infrastructure)

**Critical validation:**

- Compare plan output with previous taskctl runs
- Verify no resources are being destroyed/recreated unexpectedly
- Check that all Terraform variables are passed correctly

### 5.5 Test Documentation Generation

```bash
eirctl run docs
```

**Expected output:**

- Documentation builds successfully
- Output generated in `./outputs/docs/`
- No broken links or rendering errors

### 5.6 Verify Environment Variable Passing

Create test script to verify env var inheritance:

```bash
# Test that environment variables are passed correctly
export TEST_VAR="test_value_123"
eirctl run infra:init

# Check logs to ensure TEST_VAR is accessible in containers
# (Look for any tasks that echo environment variables)
```

### 5.7 Container Access Test

Verify Docker socket mounting works (required for nested Docker operations):

```bash
# Tasks that need Docker socket access:
# - Tests that run Docker commands
# - Helm operations

# Test if Docker commands work inside container
eirctl run infra:output  # Or any task that might use Docker
```

### 5.8 Validation Checklist

Mark each item when verified:

- [ ] `eirctl --version` works
- [ ] `eirctl list` shows all 6 pipelines
- [ ] `eirctl graph <pipeline>` works for each pipeline
- [ ] `eirctl run lint` completes successfully
- [ ] `eirctl run infra:init` initializes Terraform
- [ ] `eirctl run infra:plan` generates a plan
- [ ] `eirctl run infra:apply` applies the plan successfully
- [ ] `eirctl run docs` builds documentation
- [ ] Environment variables pass correctly to containers
- [ ] Docker socket mounting works (if needed)
- [ ] All `/app/` paths resolve correctly in containers
- [ ] Terraform workspace uses `$env:TF_VAR_environment` correctly
- [ ] PowerShell modules load correctly (no `-NoProfile` issues)

**STOP** if any validation fails. Debug and fix before proceeding.

---

## 6. DOCUMENT – Update documentation and references

Update all documentation to reference eirctl instead of taskctl.

### 6.1 Update Primary Documentation

Search and update these files:

**In [.github/copilot-instructions.md](../../.github/copilot-instructions.md):**

- Replace `taskctl` with `eirctl`
- Update command examples: `taskctl <cmd>` → `eirctl run <cmd>`
- Note: Update the "Key Design Pattern" section if architecture changed

**In [README.md](../../README.md):**

- Update all command examples
- Update installation/setup instructions
- Update "Getting Started" section

**In [docs/getting_started.adoc](../../docs/getting_started.adoc):**

- Update command syntax throughout
- Update any taskctl-specific configuration examples

**In [docs/pipeline.adoc](../../docs/pipeline.adoc):**

- Update pipeline execution examples
- Update CI/CD integration documentation

**In [docs/infrastructure.adoc](../../docs/infrastructure.adoc):**

- Update workflow commands
- Update local development examples

### 6.2 Update Configuration Documentation

**In [build/config/stage_envvars.yml](../../build/config/stage_envvars.yml):**

- Add comment at top noting eirctl usage
- Ensure all variable documentation is current

**In [stackscli.yml](../../stackscli.yml):**

- Check for any taskctl references
- Update if needed

### 6.3 Search for Remaining References

Comprehensive search:

```bash
# Find all remaining "taskctl" references (excluding backups)
grep -r "taskctl" . \
  --exclude-dir=.git \
  --exclude-dir=build/taskctl.backup \
  --exclude="*.backup" \
  --exclude-dir=node_modules

# Should only find references in:
# - CHANGELOG or migration notes (intentional)
# - Historical commit messages (ignore)
# - This prompt file (ignore)
```

Update any unexpected findings.

### 6.4 Add Migration Notes

Consider adding a migration note to the repository:

**Option A: Add to README.md:**

```markdown
## Migration to eirctl

As of [DATE], this project has migrated from taskctl to eirctl.
eirctl is the officially supported task automation tool for Ensono Stacks projects.

**Key changes:**

- Command syntax: `taskctl <pipeline>` → `eirctl run <pipeline>`
- Configuration location: `build/taskctl/` → `build/eirctl/`
- See [eirctl documentation](https://github.com/Ensono/eirctl) for details.
```

**Option B: Add MIGRATION.md:**
Create a dedicated migration guide with before/after examples.

**CHECKPOINT**: Ask which approach I prefer for documenting the migration.

---

## 7. FINALIZE – Create rollback plan and final report

### 7.1 Clean git history

Remove the old taskctl configuration from git:

```bash
# Verify taskctl directory is already marked for removal
git status | grep "deleted:"

# If not already removed, remove it
git rm -r build/taskctl 2>/dev/null || echo "Already removed or not in staging"
```

This clean approach means:

- Old taskctl configuration is removed from the repository
- Full git history is preserved for recovery if needed
- No backup files to maintain or document

### 7.2 Update Rollback Documentation (Optional)

In case rollback is needed after the migration, document the process:

```bash
# Rollback to previous commit (git maintains full history)
git revert <commit_hash>

# Or checkout the previous version from git history
git checkout HEAD~1 -- build/taskctl/
git checkout HEAD~1 -- taskctl.yaml

# Verify rollback by restoring the old taskctl directory
git restore build/taskctl/
```

Since no backup files are stored, use git's history and version control system for recovery.
This is cleaner and more maintainable than local backup files.

Before committing:

**Configuration:**

- [ ] `eirctl.yaml` exists at root

### 7.3 Final Pre-Commit Checklist

Before committing:

**Configuration:**

- [ ] `eirctl.yaml` exists at root
- [ ] `build/eirctl/contexts.yaml` has all 3 contexts converted (powershell, infratests, docs)
- [ ] `build/eirctl/tasks.yaml` has all tasks with `/app/` paths
- [ ] `build/taskctl/` is removed from git (cleaned up via git rm)
- [ ] No `-NoProfile` flags in any context
- [ ] Import statements updated to `build/eirctl/`
- [ ] Container images specified (pinned or latest)

**CI/CD:**

- [ ] `agent-config-vars.yml` has `EirctlVersion` variable
- [ ] `templates/setup.yml` installs eirctl with correct version and error handling
- [ ] `deploy-infrastructure.yml` uses `eirctl run` commands
- [ ] Docker Hub login step added after setup.yml in all jobs (to avoid rate limiting)
- [ ] All paths in CI/CD files use `/app/` prefix
- [ ] GitHub Actions workflows updated (if present)
- [ ] GitLab CI configuration updated (if present)
- [ ] No remaining `taskctl` references in any CI/CD files
- [ ] Variable names use new convention (`company`, `project`, `component`, `location`)

**Documentation:**

- [ ] `.github/copilot-instructions.md` updated
- [ ] `README.md` updated with eirctl commands
- [ ] `docs/*.adoc` files updated
- [ ] Migration notes added (if applicable)

**Testing:**

- [ ] `eirctl run lint` passes
- [ ] `eirctl run infra:init` works
- [ ] `eirctl run infra:plan` generates valid plan
- [ ] `eirctl run docs` builds documentation
- [ ] All 6 pipelines validated

**Cleanup:**

- [ ] Old `build/taskctl/` removed from git
- [ ] No backup files in the commit
- [ ] No unintended file changes

### 7.4 Commit Strategy

Recommended commit structure:

```bash
# Stage migration files
git add eirctl.yaml
git add build/eirctl/

# Stage removal of old taskctl directory
git add -u build/taskctl/  # Stages deletion

# Stage CI/CD updates
git add build/azDevOps/

# Stage documentation updates
git add .github/copilot-instructions.md
git add README.md
git add docs/

# Create comprehensive commit
git commit -m "Migrate from taskctl to eirctl

- Rename taskctl.yaml → eirctl.yaml
- Remove build/taskctl/ directory (clean migration)
- Create build/eirctl/ with modernized configuration
- Convert all 3 contexts to eirctl container-first syntax (powershell, infratests, docs)
- Remove -NoProfile flags from PowerShell contexts (required for eirctl)
- Verify all task paths use /app/ prefix
- Update variable naming to simplified convention (company, project, component, location)
- Update CI/CD pipelines to use eirctl run commands
- Update GitHub Actions workflows (if present)
- Update GitLab CI configuration (if present)
- Update EirctlVersion to v\${EIRCTL_VERSION}
- Update all documentation references

Breaking changes:
- Commands now use: eirctl run <pipeline> (not taskctl <pipeline>)
- Configuration moved: build/taskctl/ → build/eirctl/
- Variable naming: name_company → company, name_project → project, etc.
- Terraform workspace variable: TF_VAR_name_environment → TF_VAR_environment
- Configuration moved: build/taskctl/ → build/eirctl/
- Container images updated to latest stable versions

Validated:
- All 6 pipelines parse correctly
- Terraform operations validated
- Lint and docs pipelines pass
- Full git history preserved for recovery
"
```

### 7.5 FINAL REPORT

Provide a structured completion report:

---

## ✅ MIGRATION COMPLETE

### Summary

Successfully migrated from taskctl to eirctl with full validation.

### Files Changed

- **Configuration**: 3 files (eirctl.yaml, contexts.yaml, tasks.yaml)
- **CI/CD**: X files in build/azDevOps/
- **Documentation**: Y files updated
- **Total**: Z files modified

### Key Changes

1. **Context modernization**: Converted 3 contexts to container-first syntax (powershell, infratests, docs)
2. **Path convention**: Verified all paths use `/app/` prefix
3. **CI/CD integration**: Updated [N] pipeline invocations to use `eirctl run`
4. **Critical fix**: Removed `-NoProfile` from PowerShell contexts
5. **Variable naming**: Updated to use `company`, `project`, `component`, `location` (not `name_*` prefix)

### Validation Results

- ✅ Syntax validation: All pipelines parse correctly
- ✅ Lint pipeline: Passes
- ✅ Terraform init: Successful
- ✅ Terraform plan: No unexpected changes
- ✅ Documentation: Builds successfully

### Container Images

Used the following images (verify versions):

- `ensono/eir-infrastructure` (powershell context)
- `ensono/eir-inspec` (infratests context)
- `ensono/eir-asciidoctor` (docs context)

### eirctl Version

Installed: `v<version>`

### Next Steps

1. **Code review**: Have team review changes
2. **Feature branch test**: Deploy to nonprod environment via CI/CD
3. **Verify CI/CD**: Ensure Azure DevOps pipeline runs successfully
4. **Monitor**: Watch first few pipeline runs for any issues
5. **Cleanup**: Remove backup files after successful validation

### Rollback Plan

If issues arise, use git to restore the previous state:

```bash
# Revert the migration commit
git revert <commit_hash>

# Or restore from git history
git checkout HEAD~1 -- build/taskctl/ taskctl.yaml build/azDevOps/

# No local backup files to manage - git maintains complete history
```

The git-based approach is cleaner and more maintainable than local backups.

### Known Considerations

- Container images use `/app` as the workspace mount point
- PowerShell modules now load via profiles (required for eirctl)
- Variable naming uses simplified convention: `company`, `project`, `component`, `location` (not `name_company`, etc.)
- Terraform workspace variable is `TF_VAR_environment`

---

**Migration is ready for commit and testing.** Please review the changes and confirm before merging to master.

---

## Important Rules

1. **Safety First**: Never skip validation steps. Every phase must complete successfully before proceeding.

2. **Incremental Progress**: Complete phases in order. Don't jump ahead if earlier phases have issues.

3. **Ask Before Major Decisions**:
   - If container image versions should be updated
   - If breaking changes are discovered in eirctl docs
   - If CI/CD tests should run before finalizing
   - Which documentation approach to use

4. **Preserve Functionality**: The migration should change HOW tasks run, not WHAT they do. Terraform plans should be identical pre/post migration.

5. **Document Everything**: The final report should clearly state what changed, why, and what was validated.

6. **Backup First**: Always create backups before modifying configuration files.

7. **Test Thoroughly**: Don't commit until at least 3 pipelines (lint, infra:plan, docs) pass successfully.

8. **No Assumptions**: If documentation is unclear or files are missing, STOP and ask rather than guessing.

---

**Remember**: This migration affects production infrastructure automation. Thoroughness trumps speed. If anything seems wrong, STOP and ask for guidance.
