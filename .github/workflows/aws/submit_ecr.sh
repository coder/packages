#!/bin/bash
set -e

if [ -z "$VERSION" ]; then
  echo "\$VERSION not specified."
  exit 1
fi

SAFE_VERSION="${VERSION/v/""}"

# Publish image
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 709825985650.dkr.ecr.us-east-1.amazonaws.com
export ecr_location=709825985650.dkr.ecr.dus-east-1.amazonaws.com/coderv2-marketplace:v${{ env.coder_version }}
docker pull ghcr.io/coder/coder:v${{ env.coder_version }}
docker tag ghcr.io/coder/coder:v${{ env.coder_version }} $ecr_location
docker push $ecr_location

export HELM_EXPERIMENTAL_OCI=1
# Publish Helm chart
aws ecr get-login-password \
     --region us-east-1 | helm registry login \
     --username AWS \
     --password-stdin 709825985650.dkr.ecr.us-east-1.amazonaws.com
wget https://github.com/coder/coder/releases/download/v$SAFE_VERSION/coder_helm_$SAFE_VERSION.tgz
tar -xvf coder_helm_$SAFE_VERSION.tgz
# Replace coder.image.repo with $ECR_IMAGE_REPO
sed -i 's|repo: "ghcr.io/coder/coder"|repo: "'"$ECR_IMAGE_REPO"'"|' "./coder/values.yaml"
# Replace coder.image.tag with v$SAFE_VERSION
sed -i 's|tag: ""|tag: "v'"$SAFE_VERSION"'"|' "./coder/values.yaml"
aws ecr get-login-password --region us-east-1 | helm registry login --username AWS --password-stdin 709825985650.dkr.ecr.us-east-1.amazonaws.com
helm chart save ./coder 709825985650.dkr.ecr.us-east-1.amazonaws.com/coder/coderv2-marketplace:v$SAFE_VERSION
helm chart push 709825985650.dkr.ecr.us-east-1.amazonaws.com/coder/coderv2-marketplace:v$SAFE_VERSION
aws ecr describe-images --registry-id 709825985650 --repository-name coder/coderv2-marketplace --region us-east-1