
provider "scaleway" {
  region = var.region
  zone   = var.zone
  # Authentication comes only from SCW_* environment variables.
}

provider "kubernetes" {
  alias = "kapsule"

  # The fallback values keep `terraform validate` usable while Kubernetes is disabled.
  host                   = try(module.kubernetes_cluster[0].kubeconfig.host, "https://127.0.0.1")
  token                  = try(module.kubernetes_cluster[0].kubeconfig.token, "unused")
  cluster_ca_certificate = try(base64decode(module.kubernetes_cluster[0].kubeconfig.cluster_ca_certificate), "")
}
