<#
.SYNOPSIS
    Validates Azure DevOps Personal Access Token has minimum required scopes for Terraform

.DESCRIPTION
    Tests that the Azure DevOps PAT has the minimum required permissions to create
    variable groups. This helps catch authentication issues early before Terraform runs.

    Required OAuth scopes for Terraform Azure DevOps provider:
    - vso.project (Project and Team → Read)
    - vso.work (Work Items → Read)
    - vso.build (Build → Read)
    - vso.variablegroups_manage (Variable Groups → Read, create, and manage)

    Note: Azure DevOps PATs don't expose their scopes via API introspection,
    so this script validates permissions by attempting actual API operations.

.EXAMPLE
    Test-AzureDevOpsPAT

.NOTES
    AZURE DEVOPS PAT SCOPE REQUIREMENTS:

    For Terraform Azure DevOps Provider, the PAT must have these OAuth scopes:

    1. vso.project (Project and Team → Read)
       - Allows reading project metadata
       - API: GET /_apis/projects/{project}
       - Required by: data.azuredevops_project resource

    2. vso.work (Work Items → Read)
       - Allows reading work items and process templates
       - API: GET /_apis/work/processes, GET /_apis/wit/workitemtypes
       - Required by: data.azuredevops_project (reads process template)

    3. vso.build (Build → Read)
       - Allows reading build definitions and project resources
       - API: GET /_apis/build/definitions
       - Required by: azuredevops_variable_group (reads project resources/permissions)

    4. vso.variablegroups_manage (Variable Groups → Read, create, and manage)
       - Allows creating, reading, updating, and deleting variable groups
       - API: GET/POST/PUT/DELETE /_apis/distributedtask/variablegroups
       - Required by: azuredevops_variable_group resource

    SCOPE INTROSPECTION:

    Unlike OAuth 2.0 tokens, Azure DevOps Personal Access Tokens (PATs) do not
    provide a /me or introspection endpoint to query the token's granted scopes.

    The only way to validate PAT scopes is by attempting API operations and
    checking for 401/403 responses. This is why the script performs actual
    read and write operations instead of querying token metadata.

    REFERENCE:
    - OAuth Scopes: https://learn.microsoft.com/en-us/azure/devops/integrate/get-started/authentication/oauth?view=azure-devops#oauth-scopes
    - PAT Creation: https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate
#>

[CmdletBinding()]
param()

function Test-AzureDevOpsPAT {
    $ErrorActionPreference = "Stop"

    Write-Host "=========================================="
    Write-Host "Azure DevOps PAT Validation"
    Write-Host "=========================================="
    Write-Host ""

    # Check required environment variables
    $orgUrl = $env:TF_VAR_ado_org_service_url
    $project = $env:TF_VAR_ado_project_name
    $pat = $env:TF_VAR_ado_personal_access_token
    $createVG = $env:TF_VAR_create_ado_variable_group

    # If variable group creation is disabled, skip validation
    # Handle both string "false" and boolean $false
    if ($createVG -eq "false" -or $createVG -eq $false -or $createVG -eq "0") {
        Write-Host "ℹ️  Variable group creation is disabled (TF_VAR_create_ado_variable_group=false)"
        Write-Host "   Skipping PAT validation."
        Write-Host ""
        return
    }

    # If the variable is not set at all, default to true (Terraform default)
    if ([string]::IsNullOrWhiteSpace($createVG)) {
        Write-Host "ℹ️  TF_VAR_create_ado_variable_group not set, defaulting to true (Terraform default)"
        Write-Host ""
    }

    Write-Host "Configuration:"
    Write-Host "  Organization: $orgUrl"
    Write-Host "  Project: $project"
    Write-Host ""

    # Validate environment variables are set
    if ([string]::IsNullOrWhiteSpace($orgUrl)) {
        Write-Error "❌ TF_VAR_ado_org_service_url is not set"
        exit 1
    }

    if ([string]::IsNullOrWhiteSpace($project)) {
        Write-Error "❌ TF_VAR_ado_project_name is not set"
        exit 1
    }

    if ([string]::IsNullOrWhiteSpace($pat)) {
        Write-Error "❌ TF_VAR_ado_personal_access_token is not set or empty"
        Write-Host ""
        Write-Host "To fix this:"
        Write-Host "  1. Create a PAT in Azure DevOps with these scopes:"
        Write-Host "     • Project and Team → Read"
        Write-Host "     • Work Items → Read"
        Write-Host "     • Build → Read"
        Write-Host "     • Library (Variable Groups) → Read, create, & manage"
        Write-Host "  2. Set TF_VAR_ado_personal_access_token environment variable"
        Write-Host ""
        exit 1
    }

    # Validate PAT length - Azure DevOps PATs vary in length depending on format and age
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Host "Validation 1: PAT Format"
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    $patLength = $pat.Length
    Write-Host "PAT Length: $patLength characters"

    # Only check for obviously invalid PATs (too short suggests truncation/incomplete)
    if ($patLength -lt 20) {
        Write-Error "❌ PAT appears to be invalid (too short: $patLength characters)"
        Write-Host ""
        Write-Host "The PAT may be truncated or incomplete."
        Write-Host "Please verify your PAT is complete and correct."
        Write-Host ""
        exit 1
    } else {
        Write-Host "✅ PAT length appears reasonable"
        Write-Host "   (Azure DevOps PATs vary in length - actual validity will be tested via API)"
    }
    Write-Host ""

    # Create authorization header
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
    $headers = @{
        Authorization = "Basic $base64AuthInfo"
        "Content-Type" = "application/json"
    }

    # Test 1: Project and Team: Read
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Host "Validation 2: Project and Team: Read"
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Host "Testing: GET /_apis/projects/{project}"
    Write-Host ""

    $projectEncoded = [System.Web.HttpUtility]::UrlEncode($project)
    $projectUri = "$orgUrl/_apis/projects/$projectEncoded`?api-version=7.1"

    try {
        $response = Invoke-RestMethod -Uri $projectUri -Method Get -Headers $headers -ErrorAction Stop
        $projectId = $response.id
        Write-Host "✅ SUCCESS"
        Write-Host "   Project ID: $projectId"
        Write-Host "   Scope verified: Project and Team → Read"
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__

        if ($statusCode -eq 401) {
            Write-Error "❌ FAILED (HTTP 401 Unauthorized)"
            Write-Host ""
            Write-Host "Missing scope: Project and Team → Read"
            Write-Host ""
            Write-Host "To fix:"
            Write-Host "  1. Go to Azure DevOps → User Settings → Personal Access Tokens"
            Write-Host "  2. Edit your PAT or create a new one"
            Write-Host "  3. Add scope: Project and Team → Read"
            Write-Host "  4. Update TF_VAR_ado_personal_access_token with the new PAT"
            Write-Host ""
            exit 1
        }
        elseif ($statusCode -eq 404) {
            Write-Error "❌ FAILED (HTTP 404 Not Found)"
            Write-Host ""
            Write-Host "Project '$project' not found or not accessible."
            Write-Host "Available projects:"

            try {
                $projectsUri = "$orgUrl/_apis/projects?api-version=7.1"
                $projectsList = Invoke-RestMethod -Uri $projectsUri -Method Get -Headers $headers
                $projectsList.value | ForEach-Object { Write-Host "  • $($_.name)" }
            }
            catch {
                Write-Host "  Could not list projects (check PAT permissions)"
            }
            Write-Host ""
            exit 1
        }
        else {
            Write-Error "❌ FAILED (HTTP $statusCode)"
            Write-Host "   Error: $($_.Exception.Message)"
            exit 1
        }
    }
    Write-Host ""

    # Test 2: Work Items: Read (Process Template)
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Host "Validation 3: Work Items: Read"
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Host "Testing: GET /_apis/work/processes"
    Write-Host ""

    $processUri = "$orgUrl/_apis/work/processes?api-version=7.1"

    try {
        $processResponse = Invoke-RestMethod -Uri $processUri -Method Get -Headers $headers -ErrorAction Stop
        Write-Host "✅ SUCCESS"
        Write-Host "   Found $($processResponse.count) process template(s)"
        Write-Host "   Scope verified: Work Items → Read"
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__

        if ($statusCode -eq 401 -or $statusCode -eq 403) {
            Write-Error "❌ FAILED (HTTP $statusCode)"
            Write-Host ""
            Write-Host "Missing scope: Work Items → Read"
            Write-Host ""
            Write-Host "This scope is required for Terraform to read project process templates."
            Write-Host ""
            Write-Host "To fix:"
            Write-Host "  1. Go to Azure DevOps → User Settings → Personal Access Tokens"
            Write-Host "  2. Edit your PAT"
            Write-Host "  3. Add scope: Work Items → Read"
            Write-Host "  4. Update TF_VAR_ado_personal_access_token with the new PAT"
            Write-Host ""
            exit 1
        }
        else {
            Write-Error "❌ FAILED (HTTP $statusCode)"
            Write-Host "   Error: $($_.Exception.Message)"
            exit 1
        }
    }
    Write-Host ""

    # Test 3: Build: Read (Project Resources)
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Host "Validation 4: Build: Read"
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Host "Testing: GET /_apis/build/definitions"
    Write-Host ""

    $buildUri = "$orgUrl/$projectEncoded/_apis/build/definitions?api-version=7.1"

    try {
        $buildResponse = Invoke-RestMethod -Uri $buildUri -Method Get -Headers $headers -ErrorAction Stop
        Write-Host "✅ SUCCESS"
        Write-Host "   Found $($buildResponse.count) build definition(s)"
        Write-Host "   Scope verified: Build → Read"
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__

        if ($statusCode -eq 401 -or $statusCode -eq 403) {
            Write-Error "❌ FAILED (HTTP $statusCode)"
            Write-Host ""
            Write-Host "Missing scope: Build → Read"
            Write-Host ""
            Write-Host "This scope is required for Terraform to read project resources/permissions."
            Write-Host ""
            Write-Host "To fix:"
            Write-Host "  1. Go to Azure DevOps → User Settings → Personal Access Tokens"
            Write-Host "  2. Edit your PAT"
            Write-Host "  3. Add scope: Build → Read"
            Write-Host "  4. Update TF_VAR_ado_personal_access_token with the new PAT"
            Write-Host ""
            exit 1
        }
        else {
            Write-Error "❌ FAILED (HTTP $statusCode)"
            Write-Host "   Error: $($_.Exception.Message)"
            exit 1
        }
    }
    Write-Host ""

    # Test 4: Variable Groups: Read
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Host "Validation 5: Variable Groups: Read"
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Host "Testing: GET /_apis/distributedtask/variablegroups"
    Write-Host ""

    $vgListUri = "$orgUrl/$projectEncoded/_apis/distributedtask/variablegroups?api-version=7.1"

    try {
        $response = Invoke-RestMethod -Uri $vgListUri -Method Get -Headers $headers -ErrorAction Stop
        Write-Host "✅ SUCCESS"
        Write-Host "   Found $($response.count) variable group(s)"
        Write-Host "   Scope verified: Variable Groups → Read"
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__

        if ($statusCode -eq 401 -or $statusCode -eq 403) {
            Write-Error "❌ FAILED (HTTP $statusCode)"
            Write-Host ""
            Write-Host "Missing scope: Library (Variable Groups) → Read & manage"
            Write-Host ""
            Write-Host "To fix:"
            Write-Host "  1. Go to Azure DevOps → User Settings → Personal Access Tokens"
            Write-Host "  2. Edit your PAT or create a new one"
            Write-Host "  3. Add scope: Library (Variable Groups) → Read & manage"
            Write-Host "  4. Update TF_VAR_ado_personal_access_token with the new PAT"
            Write-Host ""
            exit 1
        }
        else {
            Write-Error "❌ FAILED (HTTP $statusCode)"
            Write-Host "   Error: $($_.Exception.Message)"
            exit 1
        }
    }
    Write-Host ""

    # Test 5: Variable Groups: Manage (Create)
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Host "Validation 6: Variable Groups: Manage"
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Host "Testing: POST /_apis/distributedtask/variablegroups"
    Write-Host "Action: Creating a test variable group"
    Write-Host ""

    $testVGName = "eirctl-validation-test-$(Get-Date -Format 'yyyyMMddHHmmss')"
    $createUri = "$orgUrl/_apis/distributedtask/variablegroups?api-version=7.1"

    $body = @{
        name = $testVGName
        description = "Temporary test for PAT validation - safe to delete"
        type = "Vsts"
        variables = @{
            test_key = @{
                value = "test_value"
            }
        }
        variableGroupProjectReferences = @(
            @{
                projectReference = @{
                    id = $projectId
                    name = $project
                }
                name = $testVGName
            }
        )
    } | ConvertTo-Json -Depth 10

    try {
        $createResponse = Invoke-RestMethod -Uri $createUri -Method Post -Headers $headers -Body $body -ErrorAction Stop
        $vgId = $createResponse.id

        Write-Host "✅ SUCCESS"
        Write-Host "   Created variable group: $testVGName"
        Write-Host "   Variable group ID: $vgId"
        Write-Host "   Scope verified: Variable Groups → Manage"
        Write-Host ""

        # Clean up test variable group
        Write-Host "   Cleaning up test variable group..."

        # Variable groups created with project references need to be deleted via project-specific endpoint
        $deleteUri = "$orgUrl/$projectEncoded/_apis/distributedtask/variablegroups/$($vgId)?projectIds=$projectId&api-version=7.1-preview.2"

        try {
            $deleteResponse = Invoke-WebRequest -Uri $deleteUri -Method Delete -Headers $headers -ErrorAction Stop

            if ($deleteResponse.StatusCode -eq 204 -or $deleteResponse.StatusCode -eq 200) {
                Write-Host "   ✅ Test variable group deleted successfully"
            } else {
                Write-Warning "   ⚠️  Unexpected delete response (HTTP $($deleteResponse.StatusCode))"
                Write-Host "   Please manually delete: $testVGName (ID: $vgId)"
            }
        }
        catch {
            $deleteStatusCode = $_.Exception.Response.StatusCode.value__
            Write-Warning "   ⚠️  Could not delete test variable group (HTTP $deleteStatusCode)"
            Write-Host "   Please manually delete variable group in Azure DevOps:"
            Write-Host "   Name: $testVGName"
            Write-Host "   ID: $vgId"
            Write-Host "   Location: Pipelines → Library → Variable groups"
        }
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__

        if ($statusCode -eq 401 -or $statusCode -eq 403) {
            Write-Error "❌ FAILED (HTTP $statusCode)"
            Write-Host ""
            Write-Host "PAT has Read permission but lacks Manage permission."
            Write-Host ""
            Write-Host "To fix:"
            Write-Host "  1. Go to Azure DevOps → User Settings → Personal Access Tokens"
            Write-Host "  2. Edit your PAT"
            Write-Host "  3. Ensure scope: Library (Variable Groups) → Read & manage (not just Read)"
            Write-Host "  4. Update TF_VAR_ado_personal_access_token with the new PAT"
            Write-Host ""
            exit 1
        }
        else {
            Write-Error "❌ FAILED (HTTP $statusCode)"
            Write-Host "   Error: $($_.Exception.Message)"
            exit 1
        }
    }

    Write-Host ""
    Write-Host "=========================================="
    Write-Host "✅ ALL VALIDATIONS PASSED"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "Your PAT has the required OAuth scopes:"
    Write-Host "  ✅ vso.project (Project and Team → Read)"
    Write-Host "  ✅ vso.work (Work Items → Read)"
    Write-Host "  ✅ vso.build (Build → Read)"
    Write-Host "  ✅ vso.variablegroups_manage (Variable Groups → Read, create, and manage)"
    Write-Host ""
    Write-Host "Note: These scopes are required by the Terraform Azure DevOps provider"
    Write-Host "for reading project metadata, process templates, project resources, and"
    Write-Host "managing variable groups."
    Write-Host ""
    Write-Host "Terraform should now authenticate successfully."
    Write-Host ""
}

# Run the validation
Test-AzureDevOpsPAT
