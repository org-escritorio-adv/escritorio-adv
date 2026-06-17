variable "vercel_team" {
  description = "Slug ou ID do time Vercel. Use null para conta pessoal."
  type        = string
  default     = null
}

variable "github_repo" {
  description = "Repositorio Git no formato org/repo."
  type        = string
  default     = "org-escritorio-adv/escritorio-adv"
}

variable "production_branch" {
  description = "Branch usada para deployments de producao."
  type        = string
  default     = "main"
}

variable "frontend_project_name" {
  description = "Nome do projeto frontend na Vercel."
  type        = string
  default     = "escritorio-adv"
}

variable "backend_project_name" {
  description = "Nome do projeto backend na Vercel."
  type        = string
  default     = "escritorio-adv-api"
}

variable "frontend_root_directory" {
  description = "Diretorio do frontend no repo raiz."
  type        = string
  default     = "frontend"
}

variable "backend_root_directory" {
  description = "Diretorio do backend no repo raiz."
  type        = string
  default     = "backend"
}

variable "frontend_domain" {
  description = "Dominio customizado opcional do frontend, sem https."
  type        = string
  default     = ""
}

variable "backend_domain" {
  description = "Dominio customizado opcional do backend, sem https."
  type        = string
  default     = ""
}

variable "backend_public_url" {
  description = "URL publica do backend. Use vazio para inferir pela Vercel."
  type        = string
  default     = ""
}

variable "vercel_function_region" {
  description = "Regiao padrao das Vercel Functions do backend."
  type        = string
  default     = "iad1"
}

variable "backend_function_timeout_seconds" {
  description = "Timeout padrao das Functions do backend."
  type        = number
  default     = 300
}

variable "backend_fluid_compute" {
  description = "Ativa Fluid Compute para o backend."
  type        = bool
  default     = false
}

variable "neon_project_name" {
  description = "Nome do projeto Neon."
  type        = string
  default     = "escritorio-adv-db"
}

variable "neon_org_id" {
  description = "ID da organizacao Neon. Obrigatorio quando a API Neon exige org_id."
  type        = string
  default     = ""
}

variable "neon_region_id" {
  description = "Regiao Neon do Postgres."
  type        = string
  default     = "aws-us-east-1"
}

variable "neon_branch_name" {
  description = "Branch principal do Neon."
  type        = string
  default     = "main"
}

variable "neon_database_name" {
  description = "Nome do banco da aplicacao."
  type        = string
  default     = "escritorio_adv"
}

variable "neon_role_name" {
  description = "Nome do usuario/role do banco."
  type        = string
  default     = "escritorio_adv"
}

variable "keycloak_server_url" {
  description = "URL publica do Keycloak externo, sem barra final."
  type        = string
}

variable "keycloak_realm" {
  description = "Realm do Keycloak."
  type        = string
  default     = "escritorio-adv"
}

variable "keycloak_client_id" {
  description = "Client ID usado pelo frontend e pela API."
  type        = string
  default     = "backend-api"
}

variable "keycloak_admin_client_id" {
  description = "Client ID administrativo do Keycloak para reset de senha."
  type        = string
  default     = "backend-client"
}

variable "keycloak_admin_client_secret" {
  description = "Client secret administrativo do Keycloak."
  type        = string
  sensitive   = true
  default     = ""
}

variable "datajud_base_url" {
  description = "URL base da API DataJud."
  type        = string
  default     = "https://api-publica.datajud.cnj.jus.br"
}

variable "datajud_api_key" {
  description = "Chave da API DataJud."
  type        = string
  sensitive   = true
  default     = ""
}

variable "resend_api_key" {
  description = "Chave da API Resend para e-mail transacional."
  type        = string
  sensitive   = true
  default     = ""
}

variable "resend_from_email" {
  description = "Remetente dos e-mails transacionais."
  type        = string
  default     = "noreply@escritorio-adv.com.br"
}
