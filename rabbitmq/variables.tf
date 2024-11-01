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

variable "machine_type" {
  type    = string
  default = "BV1-1-10"
}

variable "cluster_size" {
  type    = number
  default = 1
}

variable "lb_security_group_id" {
  type    = string
  default = "3f0404f1-c06b-4724-ad1e-84d62956abca"
}