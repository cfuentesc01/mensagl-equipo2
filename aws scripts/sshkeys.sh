#!/bin/bash
# Key pair SSH

ALUMNO=X
KEY_NAME="ssh-mensagl-2025-${ALUMNO}"

aws ec2 create-key-pair \
  --key-name "${KEY_NAME}" \
  --query "KeyMaterial" \
  --output text > ${KEY_NAME}.pem
 
