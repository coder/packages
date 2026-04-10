#!/bin/bash
# ---------------------------------------------------------------------------
# Publish a new version of the Coder Community Edition container product
# to AWS Marketplace using the Catalog API (StartChangeSet).
#
# Prerequisites:
#   - AWS CLI v2 configured with seller account credentials
#   - S3 assets already updated and synced (use copy-to-s3.sh)
#
# Usage:
#   ./publish-marketplace-version.sh <coder-version> <product-id>
#
# Examples:
#   # Add a brand new version (creates new delivery option)
#   ./publish-marketplace-version.sh 2.31.0 prod-abcdef1234567890
#
# ---------------------------------------------------------------------------

if [ -z "$MARKETPLACE_ACCESS_ROLE_ARN" ]; then
  echo "\$MARKETPLACE_ACCESS_ROLE_ARN not specified."
  exit 1
fi

if [ -z "$VERSION" ]; then
  echo "\$VERSION not specified."
  exit 1
fi

SAFE_VERSION="${VERSION/v/""}"

if [ -z "$PRODUCT_IDENTIFIER" ]; then
  echo "\$PRODUCT_IDENTIFIER not specified."
  exit 1
fi

CODER_VERSION="${SAFE_VERSION}"
PRODUCT_ID="${PRODUCT_IDENTIFIER}"
DELIVERY_TITLE="${1:-Coder v${CODER_VERSION} - EKS Container Deployment}"

# --- Configuration ---
ECR_REGION="${AWS_DEFAULT_REGION}"
IMAGE_TAG="v${CODER_VERSION}"
IMAGE_URI="${ECR_ACCOUNT}.dkr.ecr.${ECR_REGION}.amazonaws.com/${ECR_REPO}:${IMAGE_TAG}"
CFN_TEMPLATE_URL="https://codermktplc-assets.s3.us-east-1.amazonaws.com/community-edition/eks-cluster.yaml"
QUICKCREATE_URL="https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/quickcreate?stackName=coder-community-edition&templateURL=${CFN_TEMPLATE_URL}&param_CoderVersion=${CODER_VERSION}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Marketplace Version Publisher ==="
echo "Coder Version:  ${CODER_VERSION}"
echo "Product ID:     ${PRODUCT_ID}"
echo "Image URI:      ${IMAGE_URI}"
echo ""

# --- Step 1: Pull and push image to ECR ---
echo ">>> Pulling and pushing image to ECR..."
# Pull the docker image from the GCR public registry 
docker pull "ghcr.io/coder/coder:v${CODER_VERSION}"
# Tag and then Push the docker image to the registry 
docker tag "ghcr.io/coder/coder:v${CODER_VERSION}" "${IMAGE_URI}"
aws ecr get-login-password --region $ECR_REGION | docker login --username AWS --password-stdin "${ECR_ACCOUNT}.dkr.ecr.us-east-1.amazonaws.com"
docker push "${IMAGE_URI}"

# --- Step 2: Verify the image exists in ECR ---
echo ">>> Verifying image exists in ECR..."
if ! aws ecr describe-images \
    --registry-id "${ECR_ACCOUNT}" \
    --repository-name "${ECR_REPO}" \
    --image-ids imageTag="${IMAGE_TAG}" \
    --region "${ECR_REGION}" \
    --query 'imageDetails[0].imageTags' \
    --output text > /dev/null 2>&1; then
  echo "ERROR: Image ${IMAGE_URI} not found in ECR after push."
  exit 1
fi
echo "Image verified."

# --- Step 2: Build the changeset JSON ---
CHANGESET_FILE=$(mktemp /tmp/changeset-XXXXXX.json)

cat > "${CHANGESET_FILE}" <<EOF
{
  "Catalog": "AWSMarketplace",
  "ChangeSet": [
    {
      "ChangeType": "AddDeliveryOptions",
      "Entity": {
        "Identifier": "${PRODUCT_ID}",
        "Type": "ContainerProduct@1.0"
      },
      "DetailsDocument": {
        "Version": {
          "VersionTitle": "Coder v${CODER_VERSION}",
          "ReleaseNotes": "Coder v${CODER_VERSION} - See https://github.com/coder/coder/releases/tag/v${CODER_VERSION} for full release notes."
        },
        "DeliveryOptions": [
          {
            "DeliveryOptionTitle": "${DELIVERY_TITLE}",
            "Details": {
              "EcrDeliveryOptionDetails": {
                "ContainerImages": [
                  "${IMAGE_URI}"
                ],
                "DeploymentResources": [
                  {
                    "Name": "CloudFormation Template",
                    "Url": "${QUICKCREATE_URL}"
                  }
                ],
                "CompatibleServices": [
                  "EKS"
                ],
                "Description": "Deploy Coder v${CODER_VERSION} on Amazon EKS using the provided CloudFormation template. The template provisions a complete environment including VPC, Aurora PostgreSQL, EKS cluster with Auto Mode, and Coder with CloudFront.",
                "UsageInstructions": "Review the AWS Marketplace Coder Community Edition install documentation at https://coder.com/docs/install/cloud/aws-marketplace"
              }
            }
          }
        ]
      }
    }
  ]
}
EOF

echo ">>> Changeset payload:"
cat "${CHANGESET_FILE}" | python3 -m json.tool 2>/dev/null || cat "${CHANGESET_FILE}"
echo ""

# --- Step 3: Submit the changeset ---
echo ">>> Submitting changeset to Marketplace Catalog API..."
RESPONSE=$(aws marketplace-catalog start-change-set \
  --cli-input-json "file://${CHANGESET_FILE}" \
  --region $AWS_DEFAULT_REGION \
  --output json)

CHANGESET_ID=$(echo "${RESPONSE}" | python3 -c "import sys,json; print(json.load(sys.stdin)['ChangeSetId'])")
CHANGESET_ARN=$(echo "${RESPONSE}" | python3 -c "import sys,json; print(json.load(sys.stdin)['ChangeSetArn'])")

echo "Changeset submitted successfully."
echo "  ChangeSetId:  ${CHANGESET_ID}"
echo "  ChangeSetArn: ${CHANGESET_ARN}"
echo ""
echo "Changeset is now processing asynchronously."
echo "You will receive an email notification when it succeeds, fails, or is cancelled."
echo ""
echo "To check status manually:"
echo "  aws marketplace-catalog describe-change-set --catalog AWSMarketplace --change-set-id ${CHANGESET_ID} --region us-east-1"

rm -f "${CHANGESET_FILE}"
