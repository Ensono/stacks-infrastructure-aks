
# So that meaningful tags can be applied to resources, this data resource gets the current
# user from the environment
# This is then set as an output and can be used to tag resources so we know who deployed the resources
# the last time they were applied
data "external" "current_user" {
  program = [
    "pwsh", "-NoProfile", "-Command",
    "@{ username = if ($env:USERNAME) { $env:USERNAME } elseif ($env:USER) { $env:USER } else { whoami } } | ConvertTo-Json -Compress"
  ]
}
