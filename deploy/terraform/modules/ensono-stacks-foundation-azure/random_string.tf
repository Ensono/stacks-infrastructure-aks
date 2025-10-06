# Create a random string that is used when generating names of the resources
resource "random_string" "random_seed" {
  length  = 4
  special = false
  upper   = false
  numeric = false
}
