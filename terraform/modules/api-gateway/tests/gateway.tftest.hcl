# Unit tests for the api-gateway module (Terraform 1.7+ mock providers).

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:root"
      id         = "123456789012"
      user_id    = "AIDACKCEVSQ6C2EXAMPLE"
    }
  }
}

mock_provider "kubernetes" {}

variables {
  service_name    = "checkout"
  namespace       = "checkout"
  oidc_issuer_url = "https://oidc.eks.us-west-2.amazonaws.com/id/EXAMPLE"
  replicas        = 3
  routes = [
    {
      prefix    = "/api/v1/cart"
      cluster   = "cart-service"
      timeout_s = 10
      retries   = 2
    },
  ]
  tags = {
    Environment = "staging"
    Team        = "payments"
  }
}

run "plan_gateway_defaults" {
  command = plan

  assert {
    condition     = aws_iam_role.gateway.name == "checkout-gateway"
    error_message = "IAM role name should be <service>-gateway"
  }

  assert {
    condition = strcontains(
      aws_iam_role.gateway.assume_role_policy,
      "system:serviceaccount:checkout:checkout-gateway"
    )
    error_message = "IRSA trust policy must scope sub to the gateway ServiceAccount"
  }

  assert {
    condition = strcontains(
      aws_iam_role.gateway.assume_role_policy,
      "sts.amazonaws.com"
    )
    error_message = "IRSA trust policy must require aud=sts.amazonaws.com"
  }

  assert {
    condition     = tonumber(kubernetes_deployment_v1.gateway.spec[0].replicas) == 3
    error_message = "Deployment replicas should match the replicas variable"
  }

  assert {
    condition = strcontains(
      kubernetes_config_map_v1.envoy.data["envoy.yaml"],
      "address: 127.0.0.1"
    )
    error_message = "Envoy admin must bind to localhost"
  }

  assert {
    condition = strcontains(
      kubernetes_config_map_v1.envoy.data["envoy.yaml"],
      "cart-service.checkout.svc.cluster.local"
    )
    error_message = "Upstream cluster host should default to in-cluster DNS"
  }

  assert {
    condition = strcontains(
      var.envoy_image,
      "@sha256:"
    )
    error_message = "Default envoy_image must be digest-pinned"
  }

  assert {
    condition     = kubernetes_network_policy_v1.gateway[0].metadata[0].name == "checkout-gateway"
    error_message = "NetworkPolicy should be created by default"
  }
}

run "rejects_invalid_service_name" {
  command = plan

  variables {
    service_name = "BAD_NAME"
  }

  expect_failures = [
    var.service_name,
  ]
}

run "rejects_single_replica" {
  command = plan

  variables {
    replicas = 1
  }

  expect_failures = [
    var.replicas,
  ]
}

run "rejects_unpinned_envoy_image" {
  command = plan

  variables {
    envoy_image = "envoyproxy/envoy:v1.29.7"
  }

  expect_failures = [
    var.envoy_image,
  ]
}
