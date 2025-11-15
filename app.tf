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
}

variable "client_image" {
  type    = string
}

resource "docker_image" "server_image" {
  name         = var.server_image
  keep_locally = false
}

resource "docker_image" "client_image" {
  name         = var.client_image
  keep_locally = false
}

resource "docker_container" "server" {
  name     = "prf_server"
  image    = docker_image.server_image.name
  restart  = "unless-stopped"

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
  name     = "prf_client"
  image    = docker_image.client_image.name
  restart  = "unless-stopped"

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
  filename = "${path.module}/prometheus.yml"
  content = <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prf_server'
    scrape_interval: 10s
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

resource "docker_container" "mongodb" {
  name  = "mongodb"
  image = "mongo:8.2.1"
  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.monitoring.name
  }

  volumes {
      volume_name    = "mongodb_data"
      container_path = "/data/db"
  }
}

resource "docker_container" "datanode" {
  name = "datanode"
  image = "graylog/graylog-datanode:7.0"
  restart = "unless-stopped"

  networks_advanced {
      name = docker_network.monitoring.name
  }

  env = [
      "GRAYLOG_DATANODE_NODE_ID_FILE=/var/lib/graylog-datanode/node-id",
      "GRAYLOG_DATANODE_PASSWORD_SECRET=somepasswordpepper",
      "GRAYLOG_DATANODE_MONGODB_URI=mongodb://mongodb:27017/graylog"
  ]

  ports {
      internal = 8999
      external = 8999
  }

  ports {
      internal = 9200
      external = 9200
  }

  ports {
      internal = 9300
      external = 9300
  }

  volumes {
      volume_name = "graylog_datanode"
      container_path = "/var/lib/graylog-datanode"
  }
}

resource "docker_container" "graylog" {
  name     = "graylog"
  image    = "graylog/graylog:7.0"
  restart = "unless-stopped"

  networks_advanced {
      name = docker_network.monitoring.name
  }

  env = [
      "GRAYLOG_NODE_ID_FILE=/usr/share/graylog/data/config/node-id",
      "GRAYLOG_PASSWORD_SECRET=somepasswordpepper",
      "GRAYLOG_ROOT_PASSWORD_SHA2=8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918",
      "GRAYLOG_HTTP_BIND_ADDRESS=0.0.0.0:9000",
      "GRAYLOG_HTTP_EXTERNAL_URI=http://localhost:9000/",
      "GRAYLOG_MONGODB_URI=mongodb://mongodb:27017/graylog"
  ]

  entrypoint = ["/usr/bin/tini", "--", "/docker-entrypoint.sh"]

  ports {
      internal = 5044
      external = 5044
  }

  ports {
      internal = 5140
      external = 5140
      protocol = "udp"
  }

  ports {
      internal = 5140
      external = 5140
      protocol = "tcp"
  }

  ports {
      internal = 5555
      external = 5555
      protocol = "tcp"
  }

  ports {
      internal = 5555
      external = 5555
      protocol = "udp"
  }

  ports {
      internal = 9000
      external = 9000
  }

  ports {
      internal = 12201
      external = 12201
      protocol = "tcp"
  }

  ports {
      internal = 12201
      external = 12201
      protocol = "udp"
  }

  ports {
      internal = 13301
      external = 13301
  }

  ports {
      internal = 13302
      external = 13302
  }

  volumes {
      volume_name    = "graylog_data"
      container_path = "/usr/share/graylog/data/data"
  }

  volumes {
      volume_name    = "graylog_journal"
      container_path = "/usr/share/graylog/data/journal"
  }

  depends_on = [
      docker_container.mongodb,
      docker_container.datanode
  ]
}
