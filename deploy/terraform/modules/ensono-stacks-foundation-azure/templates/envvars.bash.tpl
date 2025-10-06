#!/usr/bin/env bash

%{ for key, value in items ~}
export TF_VAR_${key}='${value}'
%{ endfor ~}
