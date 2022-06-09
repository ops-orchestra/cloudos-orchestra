terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.5.0"
    }
  }
}

provider "google" {
  project = "main-XXXX"
  region  = local.region
  zone    = local.zone
  credentials = "${file("main.json")}"
}
