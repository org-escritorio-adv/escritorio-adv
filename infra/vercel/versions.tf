terraform {
  required_version = ">= 1.6.0"

  required_providers {
    vercel = {
      source  = "vercel/vercel"
      version = "~> 4.8"
    }

    neon = {
      source  = "kislerdm/neon"
      version = "~> 0.13"
    }
  }
}
