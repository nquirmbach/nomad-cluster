# Bastion Host für Nomad Cluster

Der Bastion Host dient als sicherer Einstiegspunkt für SSH-Zugriffe auf die Nomad Clients im Cluster. Er ist die einzige Ressource mit einer öffentlichen IP-Adresse, die direkten SSH-Zugriff von außen erlaubt. Die Nomad Clients akzeptieren SSH-Verbindungen nur vom Bastion Host aus.

## Architektur

```
Internet --> Bastion Host (Public IP) --> Nomad Clients (Private IPs)
```

- Der Bastion Host befindet sich in einem separaten Subnetz (`10.0.20.0/24`)
- Die Nomad Clients befinden sich im Cluster-Subnetz (`10.0.10.0/24`)
- Die NSG der Clients erlaubt SSH-Zugriff nur aus dem Bastion-Subnetz

## Verbindung zum Bastion Host

Nach dem Deployment kann mit folgendem Befehl eine Verbindung zum Bastion Host hergestellt werden:

```bash
ssh azureuser@<bastion-public-ip>
```

Die Public IP wird als Output des Terraform-Deployments angezeigt:

```bash
terraform output bastion_public_ip
```

Alternativ kann der vollständige SSH-Befehl direkt ausgegeben werden:

```bash
terraform output bastion_ssh_command
```

## Verbindung zu Nomad Clients über den Bastion Host

Um eine Verbindung zu einem Nomad Client herzustellen, muss zuerst eine Verbindung zum Bastion Host aufgebaut werden. Von dort aus kann dann per SSH auf die Clients zugegriffen werden:

```bash
# Auf dem Bastion Host
ssh azureuser@<client-private-ip>
```

Die privaten IPs der Clients können über die Azure Portal oder über die Azure CLI ermittelt werden:

```bash
az vmss list-instances --resource-group <resource-group-name> --name <vmss-name> --query "[].privateIps" -o tsv
```

## SSH-Konfiguration für direkten Zugriff über den Bastion Host

Für einen direkteren Zugriff kann die SSH-Konfiguration auf dem lokalen System angepasst werden:

```
# ~/.ssh/config
Host bastion
    HostName <bastion-public-ip>
    User azureuser
    IdentityFile ~/.ssh/id_rsa

Host nomad-client-*
    ProxyJump bastion
    User azureuser
    IdentityFile ~/.ssh/id_rsa
```

Mit dieser Konfiguration kann direkt auf die Clients zugegriffen werden:

```bash
ssh nomad-client-10.0.10.5
```

## Sicherheitshinweise

- Der Bastion Host ist mit minimalen Paketen und Diensten konfiguriert
- Nur SSH-Zugriff von autorisierten IP-Adressen ist erlaubt (konfiguriert in `allowed_ssh_ips`)
- Alle SSH-Verbindungen werden protokolliert
- Der Bastion Host hat eine eigene NSG mit restriktiven Regeln
