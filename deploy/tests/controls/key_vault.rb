
if input("create_key_vault")
    control 'azure-key-vaults' do
        title "Key Vault"
        desc "Tests that the expected number of Azure Key vaults have been deployed and the correct permissions have been set"

        # only run the control if key vault input is populated and app id is available
        only_if do
            input('key_vault').is_a?(Array) &&
                !input('key_vault').empty? &&
                input('azure_application_id') != ""
        end

        for item in input("key_vault") do

            describe azure_key_vault(resource_group: input("resource_group_name"), name: item["name"]) do
                it { should exist }
                its('location') { should cmp input("region") }
                its('properties.sku.name') { should cmp item["sku"] }
                its('properties.provisioningState') { should cmp "Succeeded" }

                # access policy validations are performed conditionally below
            end

            # test the permissions in the accesspolicies
            accessPolicies = azure_key_vault(resource_group: input("resource_group_name"), name: item["name"]).properties.accessPolicies

            if accessPolicies.respond_to?(:each) && !accessPolicies.empty?
                # Retrieve a list of the applicationIds that have been assigned to the access policy
                appIds = Array.new
                accessPolicies.each do |ap|
                    app_id = ap.applicationId
                    if !app_id.nil? && app_id.to_s != ""
                        appIds.append(app_id)
                    end
                end

                # Ensure that the applicationId is in the array that has been created above
                if !appIds.empty?
                    describe appIds do
                        it { should include input('azure_application_id') }
                    end
                end

                # Test the permissions for the application
                accessPolicies.each do |ap|
                    if ap.applicationId == input('azure_application_id')
                        describe ap do
                            # check that the applicationId is set correctly
                            its('applicationId') { should cmp input('azure_application_id') }

                            # Check each of the permissions for the attributes
                            its('permissions.keys.length') { should be 0 }
                            its('permissions.secrets.length') { should be 2 }
                            its('permissions.secrets') { should include "Get" }
                            its('permissions.secrets') { should include "List" }
                            its('permissions.certificates.length') { should be 0 }
                            its('permissions.storage.length') { should be 0 }
                        end
                    end
                end
            end
        end

    end
end
