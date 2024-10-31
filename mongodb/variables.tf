variable "hackathon_tags" {
  description = "Hackathon Tags"
  type        = map(string)
  default = {
    hackathon_group = "pejotinha_da_gringa"
    created_by      = "lombardi"
  }
}

variable "hackathon_group" {
  type    = string
  default = "pejotinha_da_gringa"
}

variable "created_by" {
  type    = string
  default = "lombardi"
}

variable "ssh_key_name" {
  type    = string
  default = "lombardi"
}