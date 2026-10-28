locals {
  labels = {
    "app.kubernetes.io/name"       = var.name
    "app.kubernetes.io/managed-by" = "terraform"
  }
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_secret_v1" "application" {
  metadata {
    name      = "${var.name}-environment"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  data = var.secret_environment_variables
  type = "Opaque"
}

resource "kubernetes_secret_v1" "registry" {
  count = var.create_registry_pull_secret ? 1 : 0
  metadata {
    name      = "${var.name}-registry"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  type = "kubernetes.io/dockerconfigjson"
  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        (var.registry_server) = {
          username = var.registry_username
          password = var.registry_password
          auth     = base64encode("${var.registry_username}:${var.registry_password}")
        }
      }
    })
  }
}

resource "kubernetes_deployment_v1" "this" {
  wait_for_rollout = false
  metadata {
    name      = var.name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    replicas = var.replicas
    selector {
      match_labels = local.labels
    }
    template {
      metadata {
        labels = local.labels
      }
      spec {
        dynamic "image_pull_secrets" {
          for_each = var.create_registry_pull_secret ? [1] : []
          content {
            name = kubernetes_secret_v1.registry[0].metadata[0].name
          }
        }

        container {
          name              = var.name
          image             = var.image
          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = var.container_port
          }

          dynamic "env" {
            for_each = var.environment_variables
            content {
              name  = env.key
              value = env.value
            }
          }

          dynamic "env" {
            for_each = nonsensitive(toset(keys(var.secret_environment_variables)))
            content {
              name = env.value
              value_from {
                secret_key_ref {
                  name = kubernetes_secret_v1.application.metadata[0].name
                  key  = env.value
                }
              }
            }
          }

          resources {
            requests = {
              cpu    = var.cpu_request
              memory = var.memory_request
            }
            limits = {
              cpu    = var.cpu_limit
              memory = var.memory_limit
            }
          }

          readiness_probe {
            http_get {
              path = var.health_path
              port = var.container_port
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 6
          }

          liveness_probe {
            http_get {
              path = var.health_path
              port = var.container_port
            }
            initial_delay_seconds = 30
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 3
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "public" {
  metadata {
    name      = "${var.name}-public"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    selector = local.labels
    type     = "LoadBalancer"
    port {
      name        = "http"
      port        = var.public_port
      target_port = tostring(var.container_port)
      protocol    = "TCP"
    }
  }

  wait_for_load_balancer = true
}
