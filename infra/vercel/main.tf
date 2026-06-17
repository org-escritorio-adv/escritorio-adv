locals {
  backend_url = var.backend_public_url != "" ? var.backend_public_url : (
    var.backend_domain != "" ? "https://${var.backend_domain}" : "https://${var.backend_project_name}.vercel.app"
  )

  frontend_url = var.frontend_domain != "" ? "https://${var.frontend_domain}" : "https://${var.frontend_project_name}.vercel.app"

  frontend_environment = {
    VITE_API_URL            = local.backend_url
    VITE_KEYCLOAK_URL       = var.keycloak_server_url
    VITE_KEYCLOAK_REALM     = var.keycloak_realm
    VITE_KEYCLOAK_CLIENT_ID = var.keycloak_client_id
  }

  backend_plain_environment = {
    KEYCLOAK_SERVER_URL      = var.keycloak_server_url
    KEYCLOAK_REALM           = var.keycloak_realm
    KEYCLOAK_CLIENT_ID       = var.keycloak_client_id
    KEYCLOAK_ADMIN_CLIENT_ID = var.keycloak_admin_client_id
    DATAJUD_BASE_URL         = var.datajud_base_url
    RESEND_FROM_EMAIL        = var.resend_from_email
    ENVIRONMENT              = "production"
  }

  backend_required_sensitive_environment = {
    DATABASE_URL = replace(neon_project.database.connection_uri, "postgres://", "postgresql://")
  }
}

resource "neon_project" "database" {
  name                      = var.neon_project_name
  org_id                    = var.neon_org_id
  region_id                 = var.neon_region_id
  history_retention_seconds = 21600

  branch {
    name          = var.neon_branch_name
    database_name = var.neon_database_name
    role_name     = var.neon_role_name
  }
}

resource "vercel_project" "backend" {
  name           = var.backend_project_name
  root_directory = var.backend_root_directory

  git_repository = {
    type              = "github"
    repo              = var.github_repo
    production_branch = var.production_branch
  }

  resource_config = {
    fluid                    = var.backend_fluid_compute
    function_default_regions = [var.vercel_function_region]
    function_default_timeout = var.backend_function_timeout_seconds
  }

  vercel_authentication = {
    deployment_type = "none"
  }
}

resource "vercel_project" "frontend" {
  name             = var.frontend_project_name
  framework        = "vite"
  root_directory   = var.frontend_root_directory
  install_command  = "npm ci"
  build_command    = "npm run build"
  output_directory = "dist"

  git_repository = {
    type              = "github"
    repo              = var.github_repo
    production_branch = var.production_branch
  }

  vercel_authentication = {
    deployment_type = "none"
  }
}

resource "vercel_project_environment_variable" "frontend" {
  for_each = local.frontend_environment

  project_id = vercel_project.frontend.id
  key        = each.key
  value      = each.value
  target     = ["production", "preview"]
  sensitive  = false
}

resource "vercel_project_environment_variable" "backend_plain" {
  for_each = local.backend_plain_environment

  project_id = vercel_project.backend.id
  key        = each.key
  value      = each.value
  target     = ["production", "preview"]
  sensitive  = false
}

resource "vercel_project_environment_variable" "backend_database_url" {
  for_each = local.backend_required_sensitive_environment

  project_id = vercel_project.backend.id
  key        = each.key
  value      = each.value
  target     = ["production", "preview"]
  sensitive  = true
}

resource "vercel_project_environment_variable" "backend_keycloak_admin_client_secret" {
  project_id = vercel_project.backend.id
  key        = "KEYCLOAK_ADMIN_CLIENT_SECRET"
  value      = var.keycloak_admin_client_secret
  target     = ["production", "preview"]
  sensitive  = true
}

resource "vercel_project_environment_variable" "backend_datajud_api_key" {
  project_id = vercel_project.backend.id
  key        = "DATAJUD_API_KEY"
  value      = var.datajud_api_key
  target     = ["production", "preview"]
  sensitive  = true
}

resource "vercel_project_environment_variable" "backend_resend_api_key" {
  project_id = vercel_project.backend.id
  key        = "RESEND_API_KEY"
  value      = var.resend_api_key
  target     = ["production", "preview"]
  sensitive  = true
}

resource "vercel_project_domain" "frontend" {
  count = var.frontend_domain == "" ? 0 : 1

  project_id = vercel_project.frontend.id
  domain     = var.frontend_domain
}

resource "vercel_project_domain" "backend" {
  count = var.backend_domain == "" ? 0 : 1

  project_id = vercel_project.backend.id
  domain     = var.backend_domain
}
