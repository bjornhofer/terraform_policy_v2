variable "deploy_policies" {
  type        = bool
  default     = false
  description = "set to true, this will deploy policies - set to false, it will only download the policies (default: false)"
}

variable "git_pat" {
  type        = string
  description = "Personal Access Token for Azure DevOps"
  default = ""
}

variable "git_service_url" {
  type        = string
  description = "Service URL for Azure DevOps"
  default = ""
}