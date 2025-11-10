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
        ports = ["http", "admin"]

        # Direkte Konfiguration über Kommandozeilenargumente statt Konfigurationsdateien
        args = [
          "--entrypoints.web.address=:8080",
          "--entrypoints.dashboard.address=:8081",
          "--api.dashboard=true",
          "--api.insecure=true",
          "--providers.file.directory=/local/config",
          "--providers.file.watch=true",
          "--log.level=DEBUG"
        ]
      }

      # Erstelle ein Verzeichnis für die Traefik-Konfiguration
      template {
        data = ""
        destination = "local/config/.keep"
      }

      # Einfache Konfiguration für den Server-Info-Service
      template {
        data = <<EOF
# Dynamische Konfiguration für Traefik

# Definiere einen http Service für die Server-Info App
[http.services]
  [http.services.server-info-svc]
    [http.services.server-info-svc.loadBalancer]
      # Hardcoded URL für den Server-Info-Service
      # In einer realen Umgebung würde man hier Service-Discovery verwenden
      [[http.services.server-info-svc.loadBalancer.servers]]
        url = "http://127.0.0.1:8080"

# Router für die Server-Info App
[http.routers]
  [http.routers.server-info]
    rule = "PathPrefix(`/server-info`)"
    service = "server-info-svc"
    entryPoints = ["web"]
    middlewares = ["server-info-stripprefix"]
    
  # Catch-All Router für alle anderen Anfragen
  [http.routers.catchall]
    rule = "PathPrefix(`/`)"
    service = "server-info-svc"
    entryPoints = ["web"]

# Middleware zum Entfernen des Pfad-Präfixes
[http.middlewares]
  [http.middlewares.server-info-stripprefix.stripPrefix]
    prefixes = ["/server-info"]
EOF

        destination = "local/config/server-info.toml"
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
