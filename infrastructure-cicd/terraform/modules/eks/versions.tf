# Nested modules declare their own provider requirements. The root inherits
# the provider config, but version constraints in the module are good
# defensive practice: if this module is reused in another root that forgets
# to declare tls, terraform init fails fast with a clear message.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
