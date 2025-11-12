variable "IMAGE_VERSION" {
  type = string
  default = "latest"
  description = "The version tag for the Docker image"
}

variable "ACR_NAME" {
  type = string
  default = ""
  description = "The Azure Container Registry name (leer lassen für lokales Image)"
}

variable "IMAGE_NAME" {
  type = string
  default = "nomad-app"
  description = "Name des Docker Images"
}


job "server-info-web" {
  datacenters = ["dc1"]
  type = "service"

  ui {
    description = "Server Info Web"
  }

  group "server-info" {
    count = 1

    network {
      port "http" {
        to = 8080
      }
    }

    service {
      name     = "server-info"
      port     = "http"
      provider = "consul"
      
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.server-info.rule=PathPrefix(`/server-info`)",
        "traefik.http.routers.server-info.entrypoints=http",
        "traefik.http.middlewares.strip-server-info.stripprefix.prefixes=/server-info",
        "traefik.http.routers.server-info.middlewares=strip-server-info"
      ]
      
      check {
        name     = "server-info-probe"
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
        port     = "http"
      }
    }

    task "server-info-task" {
      driver = "docker"

      resources {
        cpu = 512
        memory = 256
      }

      env {
        APP_ENV = "nomad"
        HOSTNAME = "${attr.unique.hostname}"
        NODE_IP = "${attr.unique.network.ip-address}"
        NOMAD_ALLOC_ID = "${NOMAD_ALLOC_ID}"
        NOMAD_JOB_NAME = "${NOMAD_JOB_NAME}"
        NOMAD_TASK_NAME = "${NOMAD_TASK_NAME}"
      }
      
      config {
        image = "${var.ACR_NAME != "" ? "${var.ACR_NAME}.azurecr.io/" : ""}${var.IMAGE_NAME}:${var.IMAGE_VERSION}"
        ports = ["http"]
      }
    }
  }
}
