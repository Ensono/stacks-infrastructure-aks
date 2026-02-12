%{ for key, value in items ~}
%{ if startswith(value, "[") || startswith(value, "{") ~}
${key} = ${value}
%{ else ~}
${key} = "${value}"
%{ endif ~}
%{ endfor ~}
