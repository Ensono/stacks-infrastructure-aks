
# Reference documentation for the properties that are returned for ASK cluster
# https://learn.microsoft.com/en-us/rest/api/aks/managed-clusters/get?tabs=HTTP#managedcluster

control "azure-kubernetes-cluster" do
    title "Azure Kubernetes Cluster"
    desc "Ensure that the AKS cluster has been deployed as expected"

    describe azure_aks_cluster(resource_group: input("resource_group_name"), name: input("aks_cluster_name")) do
        it { should exist }
        its("location") { should cmp input("region") }
        its("properties.provisioningState") { should cmp "Succeeded" }

        its("properties.dnsPrefix") { should cmp input("dns_prefix")}
        its("properties.apiServerAccessProfile.enablePrivateCluster") { should cmp input("kubernetes_private_cluster")}
        its("properties.enableRBAC") { should be true }
        its("properties.linuxProfile.adminUsername") { should cmp "ubuntu" }

        # Count how many node_pools there are
        its("properties.agentPoolProfiles.count") { should cmp 2 }

        # Check the identity that has been assigned
        its("identity.type") { should cmp "SystemAssigned" }
    end
end





