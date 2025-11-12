terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

resource "docker_network" "monitoring" {
  name   = "monitoring-net"
  driver = "bridge"
}

variable "server_image" {
  type    = string
  default = "prf-server:latest"
}

variable "client_image" {
  type    = string
  default = "prf-client:latest"
}

resource "docker_image" "server_image" {
  name         = var.server_image
  build {
    context    = "${path.cwd}"
    dockerfile = "${path.cwd}/Dockerfile.server"
  }
}

resource "docker_image" "client_image" {
  name         = var.client_image
  build {
    context    = "${path.cwd}"
    dockerfile = "${path.cwd}/Dockerfile.client"
  }
}

resource "docker_container" "server" {
  name  = "prf_server"
  image = docker_image.server_image.name
  restart = "unless-stopped"

  env = [
    "JWT_SECRET=valami_nagyon_titkos_jelszo",
    "ATLAS_URI=mongodb+srv://sprokdaniel:Jbt68TGnWczTYilq@prfcluster.bjw44kp.mongodb.net/healthcare_data_manager?retryWrites=true&w=majority&appName=PrfCluster"
  ]

  ports {
    internal = 3000
    external = 3000
  }

  networks_advanced {
    name = docker_network.monitoring.name
  }
}

resource "docker_container" "client" {
  name  = "prf_client"
  image = docker_image.client_image.name
  restart = "unless-stopped"

  ports {
    internal = 80
    external = 4200
  }

  depends_on = [docker_container.server]

  networks_advanced {
    name = docker_network.monitoring.name
  }
}

resource "local_file" "prometheus_config" {
  filename = "${path.cwd}/prometheus.yml"
  content = <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prf_server'
    scrape_interval: 5s
    static_configs:
      - targets: ['prf_server:3000']
EOF
}

resource "docker_container" "prometheus" {
  name  = "prometheus"
  image = "prom/prometheus:v3.7.3"
  restart = "unless-stopped"

  mounts {
      target = "/etc/prometheus/prometheus.yml"
      source = local_file.prometheus_config.filename
      type   = "bind"
  }

  ports {
    internal = 9090
    external = 9090
  }

  networks_advanced {
    name = docker_network.monitoring.name
  }
}

resource "docker_container" "grafana" {
  name  = "grafana"
  image = "grafana/grafana-oss:12.2.0-17142428006"
  restart = "unless-stopped"

  env = [
      "GF_SECURITY_ADMIN_USER=admin",
      "GF_SECURITY_ADMIN_PASSWORD=admin"
  ]

  ports {
    internal = 3000
    external = 4000
  }

  depends_on = [docker_container.prometheus]

  networks_advanced {
    name = docker_network.monitoring.name
  }
}
