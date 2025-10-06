
%{ for key, value in items ~}
$env:TF_VAR_${key}='${value}'
%{ endfor ~}
