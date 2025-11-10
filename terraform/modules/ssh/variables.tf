variable "prefix" {
  description = "Prefix für alle Ressourcen"
  type        = string
}

variable "key_vault_id" {
  description = "ID des Key Vaults, in dem die SSH-Schlüssel gespeichert werden sollen"
  type        = string
}

variable "tags" {
  description = "Tags für alle Ressourcen"
  type        = map(string)
}

# Variable save_local_keys wurde entfernt, da keine lokalen Dateien mehr erstellt werden
