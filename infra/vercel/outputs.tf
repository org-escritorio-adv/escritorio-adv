output "frontend_project_id" {
  value = vercel_project.frontend.id
}

output "backend_project_id" {
  value = vercel_project.backend.id
}

output "frontend_url" {
  value = local.frontend_url
}

output "backend_url" {
  value = local.backend_url
}

output "neon_project_id" {
  value = neon_project.database.id
}

output "neon_database_host" {
  value = neon_project.database.database_host
}

