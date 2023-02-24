#!/bin/bash

if [ -z "$VERSION" ]; then
  echo "\$VERSION not specified."
  exit 1
fi

SAFE_VERSION="${VERSION/v/""}"

aws ecr get-login-password \
     --region us-east-1 | helm registry login \
     --username AWS \
     --password-stdin 816024705881.dkr.ecr.us-east-1.amazonaws.com

wget https://github.com/coder/coder/releases/download/v$SAFE_VERSION/coder_helm_$SAFE_VERSION.tgz

helm push coder_helm_$SAFE_VERSION.tgz oci://816024705881.dkr.ecr.us-east-1.amazonaws.com/
