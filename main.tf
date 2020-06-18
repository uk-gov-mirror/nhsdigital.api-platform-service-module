data "archive_file" "bundle" {
  type = "zip"
  source_dir = "../proxies/${var.proxy_type}"
  output_path = "../build/${var.name}.zip"
}

resource "apigee_api_proxy" "proxy" {
  name = "${var.name}-${var.apigee_environment}${var.namespace}"
  bundle = data.archive_file.bundle.output_path
  bundle_sha = data.archive_file.bundle.output_sha
}

resource "apigee_api_proxy_deployment" "proxy_deployment" {
  proxy_name = apigee_api_proxy.proxy.name
  env = var.apigee_environment
  revision = apigee_api_proxy.proxy.revision

  # This tells the deploy to give existing connections a 60 grace period before abandoning them,
  # and otherwise deploys seamlessly.
  override = true
  delay = 60

  # Explicit dependency
  depends_on = [apigee_api_proxy.proxy]
}

resource "apigee_product" "product" {
  count = var.make_api_product ? 1 : 0
  name = "${var.name}-${var.apigee_environment}${var.namespace}"
  display_name = "${var.api_product_display_name} (${var.env_names[var.apigee_environment]} environment)"
  description = var.api_product_description
  approval_type = length(regexall("prod|ref", var.apigee_environment)) > 0 ? "manual" : "auto"
  proxies = var.apigee_environment == "int" ? [apigee_api_proxy.proxy.name, "identity-service-${var.apigee_environment}", "identity-service-${var.apigee_environment}-no-smartcard" ] : [apigee_api_proxy.proxy.name, "identity-service-${var.apigee_environment}"]

  quota = 300
  quota_interval = 1
  quota_time_unit = "minute"

  attributes = {
    access = "public",
    ratelimit = "5ps"
  }

  environments = [var.apigee_environment]
}
