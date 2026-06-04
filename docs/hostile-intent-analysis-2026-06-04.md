= Hostile Intent Analysis: Staged Terraform Module Update
:toc:
:toclevels: 2

Date: 2026-06-04
Scope: staged changes in `deploy/terraform`, plus related Azure DevOps variable and documentation updates.

== Summary

No clear hostile intent found in staged Terraform module-related changes.

Changes appear to align repository variable schema with upstream `Ensono/stacks-terraform//azurerm/modules/azurerm-aks?ref=v8.0.79` expectations for `aks_node_pools`, and refresh provider lock entries for `azure/modtm` and `hashicorp/azurerm` within existing version constraints.

Main risks are operational and supply-chain validation risks, not obvious malicious behavior:

* Provider lock file updates move `azure/modtm` from `0.3.5` to `0.4.0` and `hashicorp/azurerm` from `4.74.0` to `4.75.0`.
* `aks_node_pools` now accepts optional availability-zone fields that can change node pool placement if enabled by operators.
* Misspelled `availabilty_zones` is intentional because upstream module contract uses that spelling; typo may still confuse future maintainers.

== Staged Terraform-Relevant Changes Reviewed

* `deploy/terraform/variables.tf`
** Adds optional `enable_availability_zones` and `availabilty_zones` attributes to `var.aks_node_pools`.
** Keeps `aks_node_pools` default as `{}`.
** Documents misspelling as matching upstream module contract.
* `deploy/terraform/.terraform.lock.hcl`
** Updates locked `azure/modtm` provider from `0.3.5` to `0.4.0`.
** Updates locked `hashicorp/azurerm` provider from `4.74.0` to `4.75.0`.
** Replaces hashes for those updated provider versions.
** Other provider versions reviewed stayed unchanged.
* `build/azDevOps/azure/pipeline-vars.template.yml`
** Adds commented JSON example for `aks_node_pools` including new availability-zone fields.
** Keeps actual default value as `{}`.
* `build/azDevOps/azure/pipeline-vars.yml`
** Comment-only/default guidance change for `aks_node_pools`; default remains `{}`.
* `docs/advanced-configuration.adoc`
** Updates example `TF_VAR_aks_node_pools` to include new fields.
* `docs/diagrams/configuration-decisions.adoc`
** Updates docs wording around upstream contract.

== Hostile Intent Checks

[cols="1,1,2", options="header"]
|===
|Check
|Result
|Notes

|Backdoor resource creation
|No evidence
|No new Terraform resources, data sources, provisioners, external scripts, or module sources were added in staged changes.

|Secret exfiltration path
|No evidence
|No new outputs, `local-exec`, `external` data execution, network endpoints, or pipeline secret handling changes were staged.

|Privilege escalation
|No direct evidence
|No RBAC, identity, role assignment, service principal, tenant, or subscription changes were staged.

|Supply-chain substitution
|Low-to-medium risk
|Provider binaries changed through lock file updates. Sources remain official registry addresses, but updated hashes should be validated by `terraform init -lockfile=readonly` or trusted CI before merge.

|Malicious default behavior
|No evidence
|`aks_node_pools` default remains `{}`. New availability-zone fields default to disabled/empty.

|Hidden cost increase
|Low risk
|No default extra node pools are enabled. Example uses `Standard_D4s_v5`, but only in comments/docs. Cost impact occurs only if operator copies/enables example.

|Availability/reliability degradation
|Low risk
|Availability zones are opt-in for additional node pools. Incorrect zone selection could cause scheduling/capacity failures, but default remains off.

|Typo-based confusion
|Medium maintainability risk
|`availabilty_zones` is misspelled, but upstream module uses same spelling. Removing or correcting it locally would likely break compatibility.
|===

== Risk Assessment

=== Supply-chain risk: provider lock updates

Risk: medium until validated.

The lock file updates two provider versions:

* `registry.terraform.io/azure/modtm`: `0.3.5` -> `0.4.0`
* `registry.terraform.io/hashicorp/azurerm`: `4.74.0` -> `4.75.0`

Both updates remain within existing constraints:

* `azure/modtm` constraint: `~> 0.3`
* `hashicorp/azurerm` constraint: `>= 4.0.0, ~> 4.62`

Hostile-intent angle: malicious supply-chain changes often appear as lock-file hash changes or provider source changes. Here, provider source addresses were not changed, but binaries and hashes changed. That is normal for provider upgrades, but should still be verified in CI from official registry metadata.

Recommended validation:

[source,bash]
----
cd deploy/terraform
terraform init -lockfile=readonly
terraform providers
terraform plan
----

=== AKS node pool availability-zone fields

Risk: low by default; medium if enabled without regional validation.

`var.aks_node_pools` now accepts:

[source,hcl]
----
enable_availability_zones = optional(bool, false)
availabilty_zones         = optional(list(number), [])
----

This matches upstream module `v8.0.79`, where fields are required inside each node pool object. Local optional defaults improve compatibility with existing callers and prevent forced changes to current `aks_node_pools` values.

Hostile-intent angle: zone fields could be abused to degrade availability or force node pools into constrained zones, but no default staged value enables them. Risk depends on future pipeline variable values.

Recommended guardrails:

* Keep `aks_node_pools` default as `{}`.
* If enabling zones, validate region supports selected zones.
* Prefer explicit allowed values such as `[1]`, `[2]`, `[3]`, or `[1,2,3]` if policy allows.
* Consider adding Terraform validation to reject invalid zone numbers.

=== Misspelled `availabilty_zones`

Risk: medium maintainability, low hostile intent.

The misspelling is suspicious-looking but appears intentional because upstream module contract uses `availabilty_zones`. Staged docs call this out. This reduces risk of accidental “fixes” that break module compatibility.

Recommended guardrail:

* Keep comment explaining misspelling.
* Avoid adding parallel `availability_zones` unless wrapper logic maps it to upstream spelling.

== Findings

=== Finding 1: Provider lock file update needs trusted validation

Severity: medium

Lock file changes update provider binaries and checksums. This is normal, but supply-chain-sensitive. No provider source address changed, which lowers suspicion. Still, merge should require successful `terraform init -lockfile=readonly` from clean environment and plan review.

=== Finding 2: Availability-zone additions are opt-in and not hostile by default

Severity: low

New AKS node pool fields can influence placement, availability, and capacity. Defaults are safe (`false` and `[]`), and pipeline defaults remain `{}`. No evidence of hidden node pool creation or forced zone pinning.

=== Finding 3: Upstream typo compatibility is documented

Severity: low

`availabilty_zones` typo could be used to confuse reviewers, but staged changes explicitly document that spelling matches upstream. This looks like compatibility work, not hostile intent.

== Recommended Pre-Merge Actions

. Run Terraform initialization in clean environment:
+
[source,bash]
----
cd deploy/terraform
terraform init -lockfile=readonly
----
. Run and review Terraform plan for unexpected provider-driven drift:
+
[source,bash]
----
terraform plan
----
. Confirm provider changes are expected from dependency update process.
. If availability zones will be used, add or track Terraform validation for `availabilty_zones` values.
. Ensure CI runs with staged lock file, not implicit provider upgrades.

== Conclusion

No direct hostile intent detected. Staged changes do not add backdoors, secret exfiltration, privilege escalation, or malicious defaults.

Primary residual risk is provider supply-chain/change-management risk from lock file upgrades. Secondary risk is operator error from newly exposed AKS availability-zone fields. Both risks are manageable with clean `terraform init`, plan review, and optional validation around zone values.
