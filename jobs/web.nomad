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
      name     = "server-info-svc"
      port     = "http"
      provider = "nomad"
      
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.server-info.rule=Host(`server-info.service.consul`)"
      ]
      
      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "server-info-task" {
      driver = "docker"

      resources {
        cpu = 512
        memory = 256
      }

      env {
        # Static environment variables
        APP_ENV = "nomad"
        HOSTNAME = "${attr.unique.hostname}"
        NODE_IP = "${attr.unique.network.ip-address}"
        
        # You can also reference Nomad variables
        NOMAD_ALLOC_ID = "${NOMAD_ALLOC_ID}"
        NOMAD_JOB_NAME = "${NOMAD_JOB_NAME}"
        NOMAD_TASK_NAME = "${NOMAD_TASK_NAME}"
      }
      
      config {
        # Dynamische Image-Auswahl: lokal oder aus ACR
        image = "${var.ACR_NAME != "" ? "${var.ACR_NAME}.azurecr.io/" : ""}${var.IMAGE_NAME}:${var.IMAGE_VERSION}"
        ports = ["http"]
      }
    }
  }
}
