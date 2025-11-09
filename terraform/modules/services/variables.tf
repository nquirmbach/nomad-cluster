variable "prefix" {
  description = "Prefix für alle Ressourcen"
  type        = string
}

variable "location" {
  description = "Azure Region für alle Ressourcen"
  type        = string
}

variable "resource_group_name" {
  description = "Name der Resource Group"
  type        = string
}

variable "tags" {
  description = "Tags für alle Ressourcen"
  type        = map(string)
}

variable "enable_github_actions_rbac" {
  description = "Aktiviert RBAC-Zuweisungen für GitHub Actions Managed Identity"
  type        = bool
  default     = false
}
