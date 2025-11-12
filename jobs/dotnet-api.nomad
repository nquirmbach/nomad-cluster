variable "API_VERSION" {
  type = string
  default = "latest"
  description = "The version tag for the .NET API executable"
}

variable "ARTIFACT_SOURCE" {
  type = string
  default = "local"
  description = "Source of the artifact (local or remote)"
}

variable "ARTIFACT_PATH" {
  type = string
  default = "../apps/dotnet-api/release"
  description = "Path to the artifact directory (local path or URL)"
}

job "dotnet-crud-api" {
  datacenters = ["dc1"]
  type = "service"

  ui {
    description = ".NET CRUD API"
  }

  group "api" {
    count = 1

    network {
      port "http" {}
    }

    service {
      name     = "dotnet-api"
      port     = "http"
      provider = "consul"
      
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.dotnet-api.rule=PathPrefix(`/dotnet-api`)",
        "traefik.http.routers.dotnet-api.entrypoints=http",
        "traefik.http.middlewares.strip-dotnet-api.stripprefix.prefixes=/dotnet-api",
        "traefik.http.routers.dotnet-api.middlewares=strip-dotnet-api"
      ]
      
      check {
        name = "dotnet-api-probe"
        type     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "2s"
        port     = "http"
      }
    }

    task "api-task" {
      driver = "exec"

      artifact {
        source = "${var.ARTIFACT_SOURCE == "local" ? var.ARTIFACT_PATH : "${var.ARTIFACT_PATH}/dotnet-api-${var.API_VERSION}.zip"}"
      }

      resources {
        cpu = 512
        memory = 256
      }

      env {
        APP_ENV = "nomad"
        PORT = "${NOMAD_PORT_http}"
        ASPNETCORE_URLS = "http://0.0.0.0:${NOMAD_PORT_http}"
        ASPNETCORE_ENVIRONMENT = "Production"
        HOSTNAME = "${attr.unique.hostname}"
        NODE_IP = "${attr.unique.network.ip-address}"
        NOMAD_ALLOC_ID = "${NOMAD_ALLOC_ID}"
        NOMAD_JOB_NAME = "${NOMAD_JOB_NAME}"
        NOMAD_TASK_NAME = "${NOMAD_TASK_NAME}"
      }
      
      config {
        command = "dotnet-api"
      }
    }
  }
}
