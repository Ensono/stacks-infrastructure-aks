# Check the properties of the container registry, if it has been deployed
# 
# NOTE: Cannot use the only_if method here because the name of the resource must be
# specified for the control to pass the compile phase. This means that if the name of the registry 
# is null and the container registry is false it will still fail to compile.

if input("create_acr")
    control "container_registry" do

        title "Azure Container Registry"
        desc "Conatiner registry for the images that Kubernetes will use for deployments"

        describe azure_container_registry(resource_group: input("resource_group_name"), name: input("container_registry_name")) do
            it { should exist }
            its("location") { should cmp input("region") }
            its("properties.provisioningState") { should cmp "Succeeded" }
            its("sku.name") { should cmp input("container_registry_sku")}
        end
    end
end