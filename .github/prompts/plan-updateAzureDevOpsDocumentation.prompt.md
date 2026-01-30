# Plan: Update documentation for Azure DevOps integration and multi-environment patterns

Comprehensive documentation update addressing 10 major gaps in Azure DevOps integration, multi-environment strategy, and advanced infrastructure features. Focus on clean AsciiDoc with Graphviz diagrams for complex workflows and architecture decisions.

## Implementation Steps

### 1. Create Azure DevOps Integration Guide
**File**: `docs/azure-devops-integration.adoc`

**Content**:
- PAT validation workflow and why it's necessary
- Variable group generation and structure
- OAuth scope requirements (vso.project, vso.work, vso.build, vso.variablegroups_manage, vso.pipelineresources_manage)
- Security implications and best practices
- Troubleshooting PAT validation failures

**Diagram**: PAT → validation → variable group pipeline flow (Graphviz)

---

### 2. Expand getting_started.adoc
**Additions**:
- Step-by-step Azure DevOps PAT creation walkthrough with screenshots references
- Azure DevOps PAT validation section (extends existing brief mention)
- Environment definitions format explanation (format: "env:is_prod")
- Multi-environment deployment examples (dev:false vs prod:true behavior)
- Workspace switching and state management
- Variable precedence and override patterns

**Diagram**: Environment definitions decision tree showing dev vs prod path divergence

---

### 3. Create Advanced Configuration Guide
**File**: `docs/advanced-configuration.adoc`

**Content**:
- Node pool configuration via `aks_node_pools` variable with examples
- DNS parent zone delegation pattern and when to use it
- Certificate management and Key Vault integration
- Conditional resource creation patterns (`create_ado_variable_group`, etc.)
- Ensono Stacks module capabilities and limitations (v8.0.19)
- Custom naming patterns using foundation-azure module

**Diagram**: Configuration decision matrix - which variables to set for different scenarios

---

### 4. Update infrastructure.adoc
**Additions**:
- Terraform architecture overview
- Module dependency tree (Ensono Stacks, local modules, data sources)
- Terraform outputs and their purposes
- Data source references and Azure API dependencies
- Integration points between modules
- Terraform workspace strategy for multi-environment

**Diagram**: Module relationship diagram showing ensono-stacks-foundation-azure, azurerm-aks-local, data sources, and outputs

---

### 5. Enhance helm.adoc
**Additions**:
- Terraform output → Helm values templating workflow
- Complete worked example with actual TFOUT_ variables
- Cluster-setup identity binding integration with Terraform outputs
- Chart dependency management
- Default vs optional charts and their purpose
- Values override patterns

**Diagram**: Data flow from Terraform apply → outputs extraction → TFOUT_ variables → Helm values → Chart deployment

---

### 6. Create Troubleshooting Guide
**File**: `docs/troubleshooting.adoc`

**Content**:
- PAT validation failures (missing scopes, expired tokens, insufficient permissions)
- Variable group creation failures
- Terraform initialization and planning issues
- DNS propagation problems
- InSpec test failures and diagnostics
- Helm chart deployment issues
- Script error codes and remediation

---

### 7. Enhance pipeline.adoc
**Additions**:
- Task dependency graph visualization
- PAT validation placement in pipeline
- Variable extraction flow and timing
- Parallel vs sequential task execution
- Environment-specific pipeline behavior
- Pipeline troubleshooting

**Diagram**: Complete task dependency graph showing setup → validation → init → plan → apply flow with helm deployment branch

---

### 8. Update tests.adoc
**Additions**:
- InSpec inputs generation mechanism (inputs.yml creation)
- Azure service version retrieval mechanism
- Test environment prerequisites
- How to add new InSpec controls
- Test result interpretation

---

## Diagram Strategy

Create Graphviz diagrams for these difficult-to-explain concepts:

1. **PAT Validation Pipeline** (digraph)
   - User input PAT → Validate scopes → Check Azure DevOps → Create/update variable groups → Success/Failure

2. **Environment Definitions Decision Tree** (digraph)
   - Variable selection → Environment type (dev/test/prod) → Workspace selection → Resource configuration

3. **Module Dependency Tree** (digraph)
   - main.tf → naming module → azurerm-aks-local → Azure resources
   - main.tf → aks.tf → Ensono Stacks module → Azure resources
   - Data sources branching from multiple modules

4. **Terraform → Helm Data Flow** (digraph)
   - Terraform apply → outputs → extraction → TFOUT_ environment variables → values.yaml → Helm deploy

5. **Task Dependency Graph** (digraph)
   - setup:environment → setup:validate:azdo:pat → infra:init → infra:plan → infra:apply → [optional] infra:helm:apply

6. **Configuration Decision Matrix** (table)
   - Decision criteria vs configuration variables (basic cluster, multi-node-pool, DNS delegation, public IP)

---

## Documentation Quality Standards

### AsciiDoc Formatting
- Use consistent heading hierarchy
- Include table of contents in each major document
- Cross-reference between documents using xref:
- Use `+` for literal code blocks, ---- for code samples
- Include "NOTE:", "WARNING:", "IMPORTANT:" admonitions

### Code Examples
- Include actual `build/config/stage_envvars.yml` examples
- Show before/after for multi-environment scenarios
- Include error messages and how to resolve them
- Use relevant files from the repository as references

### Security Considerations
- Document PAT scope requirements and why each is necessary
- Explain Key Vault integration for certificate management
- Highlight what NOT to do (hardcoding credentials, etc.)
- Reference compliance requirements where applicable

---

## File Organization

```
docs/
├── index.adoc (main TOC - update to link to new files)
├── introduction.adoc (existing)
├── getting_started.adoc (EXPAND - add PAT section, multi-env examples)
├── infrastructure.adoc (UPDATE - add architecture details, diagrams)
├── azure-devops-integration.adoc (CREATE - new comprehensive guide)
├── advanced-configuration.adoc (CREATE - node pools, DNS, certificates)
├── helm.adoc (EXPAND - add Terraform integration examples)
├── pipeline.adoc (UPDATE - add task dependency graph)
├── tests.adoc (UPDATE - add inputs generation, test mechanics)
├── troubleshooting.adoc (CREATE - comprehensive problem-solution guide)
└── diagrams/
    ├── pat-validation-pipeline.dot (CREATE)
    ├── environment-definitions.dot (CREATE)
    ├── module-dependencies.dot (CREATE)
    ├── terraform-helm-dataflow.dot (CREATE)
    ├── task-dependency-graph.dot (CREATE - enhance existing if present)
    └── configuration-decisions.adoc (CREATE - decision matrix)
```

---

## Priority Ordering

**CRITICAL** (blocks other tasks):
1. Update getting_started.adoc with PAT creation walkthrough
2. Create azure-devops-integration.adoc
3. Create advanced-configuration.adoc diagrams (decision trees)

**HIGH** (impact on new users):
4. Enhance infrastructure.adoc with module diagram
5. Enhance helm.adoc with worked examples
6. Create troubleshooting.adoc

**MEDIUM** (nice-to-have improvements):
7. Update pipeline.adoc with task dependency graph
8. Update tests.adoc with mechanics details

**LOW** (polish):
9. Add cross-references between all documents
10. Create glossary updates if needed

---

## Success Criteria

- [ ] All 10 documentation gaps addressed
- [ ] At least 5 Graphviz diagrams created
- [ ] Every complex workflow explained in both prose and diagram
- [ ] Code examples work with actual repository files
- [ ] No broken cross-references
- [ ] AsciiDoc validates with asciidoctor
- [ ] Diagrams render correctly
- [ ] Security best practices highlighted
- [ ] PAT creation process fully documented with step-by-step instructions
- [ ] Multi-environment deployment clearly explained with examples
