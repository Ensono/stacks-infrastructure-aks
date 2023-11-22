# The following set of controls are designed to test if the version of Kubernetes
# being run is the current version, previous or 2 behind. These are the version that are supported 
# by Microsoft
#
# Inspec has a two stage approach. The first stage is the compile stage which analyses the controls that
# need to be executed. The second stage executes these controls.
#
# The control being executed here is dynamically configured based on the Kuebrnetes version that is suppliied
# to the tests.
#
# NOTE: This Kuberntes version is passed in from the Terraform output because the actual value from the resource
# cannot be interrogated unless it is inside a "describe" block.
#
# The list of Kubernetes vbersions also comes from an external input, in this case from the list that is retrieved
# from the Azure region (using the PowerShell Get-AzureServiceVersions cmdlet). Thisis then reversed so that the
# it is in descending order of versions.
#
# The value that is specified for the `k8s_version_threshold` in the inputs, is used to split the array into 
# two - valid and invalid versions. The test is then ruin against the valid versions to determine if it shuld pass
# or not. 
#
# The k8s_version_threshold number allows the test top be modiofied to the meet the needs of the team that are maintaining
# the project. For example, in this default case the current and previous versions of Kubernetes are valid, but if this
# value were set to 2, only the current versions would be valid.
#
# In the past we have tried to have a warnign state for when the version is OK, but work needs to be carried out
# to upgrade it. Due to the reporting method we have to use, JUnit, we only have the status of passed and failed.

# Ensure the k8s version array is sorted and in reverse order
k8s_version = input("kubernetes_version")
k8s_versions = input("kubernetes_valid_versions").sort!.reverse

k8s_version_count = k8s_versions.count

# Determine the valid and invalid lists
# Set some sensible defaults
k8s_version_threshold = input("k8s_version_threshold")

if k8s_version_threshold.nil? || k8s_version_threshold > k8s_version_count
    k8s_version_threshold = k8s_versions.count
else
    k8s_version_threshold = 0
end

valid_versions = k8s_versions[0..(k8s_version_threshold - 1)]
invalid_versions = k8s_versions[(k8s_version_threshold)..(k8s_version_count)]

# If the current version is valid then pass the test, otherwise error
control "azure-kubernetes-version" do
    title "AKS Cluster Version"
    desc sprintf("Running a valid version of Kubernetes: %s", valid_versions.join(", "))
    impact 1.0

    describe azure_aks_cluster(resource_group: input("resource_group_name"), name: input("aks_cluster_name")) do
        its("properties.kubernetesVersion") { should be_in valid_versions}
    end
end
