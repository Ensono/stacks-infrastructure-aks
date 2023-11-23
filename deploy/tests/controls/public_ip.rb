control "azure-kubernetes-public-ip" do
    title "App Gateway IP"
    desc "Ensure that a Public IP address has been configured for the App Gateway"

    describe azure_public_ip(resource_group: input("resource_group_name"), name: input("app_gateway_public_ip_name")) do
        it { should exist }
        its("location") { should cmp input("region") }
        its("properties.provisioningState") { should cmp "Succeeded" }
        its("sku.name") { should cmp "Basic" }
    end
end
