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
# The list of Kubernetes versions also comes from an external input, in this case from the list that is retrieved
# from the Azure region (using hte CLI). This is then revesre sorted so that the elements 1 and 2 are the current
# support version, 3 and 4 are the previous version and 5 and 6 are the last supported version.
#
# This configures the impact of the failing test to show whether the version is currently supported (info), if
# it is the previous version (warn) or if using the last version (error)
#
# As the "describe" block needs to warn or fail, if not running current, the logic states that the version
# of Kubernets being run should _not_ be in the list. As it is in the list this will fail the control - it is
# an inverted test

# Ensure the k8s version array is sorted and in reverse order
k8s_version = input("kubernetes_version")
k8s_versions = input("kubernetes_valid_versions").sort!.reverse
current = k8s_versions[0..1]
previous = k8s_versions[2..3]
last = k8s_versions[4..5]

if k8s_versions.include? k8s_version

    # Determine what the impact will be depending on the version of kubernetes that is running
    if current.include? k8s_version
        description = "Running the current version of Kubernetes"
        impact_value = 0.0
        suffix = "Current"
        version_list = current
    elsif previous.include? k8s_version
        description = "Running the previous version of Kubernetes"
        impact_value = 0.3
        suffix = "Previous"
        version_list = previous
    else
        description = "Running the last supported version of Kubernetes, please consider upgrading"
        impact_value = 1.0
        suffix = "Last"
        version_list = last
    end

    control "azure-kubernetes-version" do
        title ("Kubernetes Cluster Version - " + suffix)
        desc description
        impact impact_value

        describe azure_aks_cluster(resource_group: input("resource_group_name"), name: input("aks_cluster_name")) do
            if current.include? k8s_version
                its("properties.kubernetesVersion") { should be_in version_list }
            else
                its("properties.kubernetesVersion") { should_not be_in version_list }
            end
        end
    end

else 

    control "azure-kubernetes-version" do
        title "Kubernetes Cluster Version - Out of date"
        desc "Current kubernetes version is out of support"
        impact 1.0

        describe azure_aks_cluster(resource_group: input("resource_group_name"), name: input("aks_cluster_name")) do
            its("properties.kubernetesVersion") { should be_in k8s_versions }
        end
    end

end