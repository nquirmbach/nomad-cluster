job "traefik" {
  datacenters = ["dc1"]
  type        = "service"

  group "traefik" {
    count = 1

    network {
      port "http" {
        static = 8080
      }
      port "admin" {
        static = 8081
      }
      # Zusätzliche Ports für interne Kommunikation
      port "ping" {
        static = 8082
      }
    }

    service {
      name = "traefik"
      port = "http"
      tags = ["traefik.enable=true"]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    # Service für das Traefik Dashboard
    service {
      name = "traefik-dashboard"
      port = "admin"
      tags = ["traefik.enable=true"]

      check {
        name     = "dashboard-alive"
        type     = "tcp"
        port     = "admin"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image = "traefik:v2.10"
        ports = ["http", "admin", "ping"]

        # Direkte Konfiguration über Kommandozeilenargumente statt Konfigurationsdateien
        args = [
          "--entrypoints.web.address=:8080",
          "--entrypoints.dashboard.address=:8081",
          "--entrypoints.ping.address=:8082",
          "--ping.entrypoint=ping",
          "--api.dashboard=true",
          "--api.insecure=true",
          "--api.entrypoint=dashboard",
          "--providers.consulcatalog=true",
          "--providers.consulcatalog.prefix=traefik",
          "--providers.consulcatalog.exposedByDefault=false",
          "--providers.consulcatalog.endpoint.address=127.0.0.1:8500",
          "--providers.file.filename=/local/dynamic_conf.toml",
          "--log.level=DEBUG"
        ]
      }

      # Kein leeres Template mehr notwendig

      # Zusätzliche Konfiguration für Traefik (Middlewares)
      template {
        data = <<EOF
# Dynamische Konfiguration für Traefik

# Middleware zum Entfernen des Pfad-Präfixes
[http.middlewares]
  [http.middlewares.strip-server-info.stripPrefix]
    prefixes = ["/server-info"]

# Catch-All Router für die Startseite
[http.routers]
  [http.routers.catchall]
    rule = "PathPrefix(`/`)"
    service = "server-info-svc"
    entryPoints = ["web"]
    priority = 1  # Niedrige Priorität, damit spezifischere Routen Vorrang haben
EOF

        destination = "local/dynamic_conf.toml"
      }

      env {
        # Debug-Modus aktivieren
        TRAEFIK_LOG_LEVEL = "DEBUG"
      }

      resources {
        cpu    = 300
        memory = 256
      }
    }
  }
}
