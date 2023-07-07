control "azure-kubernetes-public-ip" do
    title "Azure Kubernetes Ingress IP"
    desc "Ensure that a Public IP address has been configured for the Ingress for Kubernetes"

    describe azure_public_ip(resource_group: input("resource_group_name"), name: input("aks_ingress_public_ip")) do
        it { should exist }
        its("location") { should cmp input("region") }
        its("properties.provisioningState") { should cmp "Succeeded" }
        its("sku.name") { should cmp "Basic" }
    end
end