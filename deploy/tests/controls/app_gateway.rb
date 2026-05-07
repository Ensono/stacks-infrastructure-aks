# Validates Application Gateway backend pool targeting and SSL configuration.
#
# These tests guard against the specific failure chain where:
#   - Application Gateway targets the wrong ingress IP  → 502 Bad Gateway
#   - Application Gateway is deployed with configuration inconsistent with the
#     valid-certificate path → later Java PKIX errors
#
# Both conditions arise from internal_ingress_enabled=false or missing ACME prerequisites,
# and are now blocked at plan time by Terraform preconditions.  These InSpec controls
# provide the complementary post-deploy verification.
#
# Note: These controls do not validate certificate issuer/chain trust.

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

  # Assert (rather than skip) when internal_ingress_enabled=false so that the
  # misconfiguration that causes 502 errors is caught by `eirctl run tests`
  # instead of silently passing.
  describe "Cluster configuration" do
    it "must use internal ingress (internal_ingress_enabled=true) when the Application Gateway is deployed" do
      expect(input("internal_ingress_enabled")).to be true
    end
  end

  gw = azure_application_gateway(
    resource_group: input("app_gateway_resource_group_name"),
    name:           input("app_gateway_name")
  )

  if gw.exist?
    backend_pools = Array(gw.properties&.backendAddressPools)
    backend_addresses = backend_pools.flat_map do |pool|
      Array(pool.properties&.backendAddresses)
    end
    all_backend_ips = backend_addresses.map do |addr|
      addr.respond_to?(:ipAddress) ? addr.ipAddress : addr["ipAddress"]
    end.compact

    describe "Application Gateway backend pools" do
      subject { backend_pools }
      it "must contain at least one backend pool" do
        expect(subject).not_to be_empty
      end
    end

    describe "Application Gateway backend addresses" do
      subject { backend_addresses }
      it "must contain at least one backend address" do
        expect(subject).not_to be_empty
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
  title "Application Gateway SSL certificate is configured and TLS policy is applied"
  desc <<~DESC
    Verifies that the Application Gateway has at least one SSL certificate loaded
    and the expected predefined TLS policy (AppGwSslPolicy20170401S) applied.

    These assertions are distinct from the backend-pool targeting check and serve
    as non-sensitive, directly observable signals that the valid-certificate
    deployment path completed:
      - An empty sslCertificates collection means the cert-upload step failed so
        no TLS termination is possible.
      - A missing or default SSL policy indicates the TLS hardening configuration
        was not applied by Terraform.

    This control does NOT validate the certificate issuer, expiry, or chain.
    For a live TLS verification of the actual certificate and issuer, run:
      openssl s_client -connect <app_gateway_ip>:443 -servername <hostname> </dev/null 2>&1 \
        | openssl x509 -noout -issuer -subject
    and confirm that the issuer/chain meets your trust requirements.
  DESC

  only_if("Application Gateway not deployed") { input("create_ssl_gateway") }
  only_if("Valid cert creation must be enabled") { input("create_valid_cert") }

  gw = azure_application_gateway(
    resource_group: input("app_gateway_resource_group_name"),
    name:           input("app_gateway_name")
  )

  if gw.exist?
    describe "Application Gateway SSL certificates" do
      subject { gw.properties.sslCertificates }
      it "must have at least one SSL certificate configured" do
        expect(subject).not_to be_nil
        expect(subject).not_to be_empty
      end
    end

    ssl_policy = gw.properties.sslPolicy
    describe "Application Gateway SSL policy" do
      subject { ssl_policy }
      it "must be configured with the expected predefined TLS policy (AppGwSslPolicy20170401S)" do
        expect(subject).not_to be_nil
        policy_name =
          if subject.respond_to?(:policyName)
            subject.policyName
          elsif subject.respond_to?(:[])
            subject["policyName"]
          end
        expect(policy_name).to eq("AppGwSslPolicy20170401S")
      end
    end
  else
    describe "Application Gateway" do
      it "must exist before SSL certificate configuration can be validated" do
        expect(gw.exist?).to be true
      end
    end
  end
end
