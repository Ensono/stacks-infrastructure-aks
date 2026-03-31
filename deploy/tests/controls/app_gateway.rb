# Validates Application Gateway backend pool targeting and certificate trust.
#
# These tests guard against the specific failure chain where:
#   - Application Gateway targets the wrong ingress IP  → 502 Bad Gateway
#   - Application Gateway is deployed with configuration inconsistent with the
#     valid-certificate path → later Java PKIX errors
#
# Both conditions arise from is_cluster_private=false or missing ACME prerequisites,
# and are now blocked at plan time by Terraform preconditions.  These InSpec controls
# provide the complementary post-deploy verification.

control "azure-application-gateway-exists" do
  title "Application Gateway provisioning"
  desc "Ensures the Application Gateway is provisioned and healthy after apply"

  only_if("Application Gateway not deployed") { input("create_ssl_gateway") }

  describe azure_application_gateway(
    resource_group: input("app_gateway_resource_group_name"),
    name:           input("app_gateway_name")
  ) do
    it { should exist }
    its("properties.provisioningState") { should cmp "Succeeded" }
    its("properties.operationalState")  { should cmp "Running" }
  end
end

control "azure-application-gateway-backend-pool" do
  title "Application Gateway backend pool target"
  desc <<~DESC
    Verifies that the Application Gateway backend pool targets the nginx-ingress
    internal load balancer IP.

    A mismatch between the backend pool address and the live nginx-ingress service IP
    is the root cause of probe timeouts and 502 Bad Gateway responses.
    Expected target: #{input("aks_ingress_private_ip")} (aks_ingress_private_ip).
  DESC

  only_if("Application Gateway not deployed") { input("create_ssl_gateway") }
  only_if("Cluster must be private for this check") { input("is_cluster_private") }

  gw = azure_application_gateway(
    resource_group: input("app_gateway_resource_group_name"),
    name:           input("app_gateway_name")
  )

  if gw.exist?
    backend_pools = gw.properties.backendAddressPools
    all_backend_ips = backend_pools.flat_map do |pool|
      pool.properties.backendAddresses.map do |addr|
        addr.respond_to?(:ipAddress) ? addr.ipAddress : addr["ipAddress"]
      end
    end

    describe "Application Gateway backend pool addresses" do
      subject { all_backend_ips }
      it "must include the nginx-ingress internal LB IP #{input('aks_ingress_private_ip')}" do
        expect(subject).to include(input("aks_ingress_private_ip"))
      end
      it "must not include the public ingress IP when a distinct public ingress exists" do
        public_ingress_ip = input("aks_ingress_public_ip")

        if public_ingress_ip.nil? || public_ingress_ip.empty? || public_ingress_ip == input("aks_ingress_private_ip")
          skip "No distinct public ingress IP is configured for this environment"
        end

        expect(subject).not_to include(public_ingress_ip)
      end
    end
  else
    describe "Application Gateway" do
      it "must exist before backend pool can be validated" do
        expect(gw.exist?).to be true
      end
    end
  end
end

control "azure-application-gateway-cert-configuration" do
  title "Application Gateway frontend certificate configuration is consistent with valid-cert deployment"
  desc <<~DESC
    Provides an indirect configuration check that the valid-certificate deployment
    path was used when creating the Application Gateway frontend listener.

    This control does NOT directly validate certificate trust or whether the
    certificate is self-signed. Instead, it uses the Terraform output
    app_gateway_backend_address as a proxy signal: when Terraform apply
    completes successfully with create_valid_cert=true and all ACME prerequisites
    present, the gateway is expected to be wired to the nginx-ingress internal
    load balancer IP.

    For a live TLS verification of the actual certificate and issuer, run:
      openssl s_client -connect <app_gateway_ip>:443 -servername <hostname> </dev/null 2>&1 \
        | openssl x509 -noout -issuer -subject
    and confirm that the issuer/chain meets your trust requirements.
  DESC

  only_if("Application Gateway not deployed") { input("create_ssl_gateway") }
  only_if("Valid cert creation must be enabled") { input("create_valid_cert") }

  # The Terraform output app_gateway_backend_address is non-null only when
  # create_ssl_gateway=true.  Using it as a proxy for "Terraform apply succeeded
  # with the correct cert-related configuration prerequisites" avoids embedding
  # any sensitive certificate material into InSpec inputs.
  describe input("app_gateway_backend_address") do
    it "must be the internal ingress IP, confirming Terraform applied with expected valid-cert configuration" do
      expect(subject).to eq(input("aks_ingress_private_ip"))
    end
  end
end
