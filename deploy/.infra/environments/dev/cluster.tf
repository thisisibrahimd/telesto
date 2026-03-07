resource "digitalocean_kubernetes_cluster" "telesto-dev-cluster" {
  name   = "telesto-dev-cluster"
  region = "lon1"
  # Grab the latest version slug from `doctl kubernetes options versions` (e.g. "1.14.6-do.1"
  # If set to "latest", latest published version will be used.
  version = "1.34.1-do.0"

  node_pool {
    name       = "main"
    size       = "s-2vcpu-2gb"
    node_count = 1

    taint {
      key    = "workloadKind"
      value  = "database"
      effect = "NoSchedule"
    }
  }
}
