/**
 * https://github.com/terraform-linters/tflint-ruleset-terraform/blob/main/docs/rules/README.md
 */
plugin "terraform" {
  source  = "github.com/terraform-linters/tflint-ruleset-terraform"
  version = "0.1.1"
  enabled = true
  preset  = "all"
}

/**
 * https://github.com/terraform-linters/tflint-ruleset-google/blob/master/docs/rules/README.md
 */
plugin "google" {
  source  = "github.com/terraform-linters/tflint-ruleset-google"
  version = "0.20.0"
  enabled    = true
  deep_check = true
}
