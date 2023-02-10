#!/bin/bash

if [ -z "$AMI_ID" ]; then
  AMI_ID=$(cat ./packer-manifest.json | jq -r 'last(.builds[] | select(.builder_type=="amazon-ebs").artifact_id)' | cut -f2 -d":")
fi

echo $AMI_ID

exit 1

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

# Set details JSON
DETAILS_JSON_AS_STRING=$(echo '
{
  "Version": {
    "VersionTitle": "Coder '$SAFE_VERSION'",
    "ReleaseNotes": "Updated to Coder '$SAFE_VERSION'"
  },
  "DeliveryOptions": [
    {
      "Details": {
        "AmiDeliveryOptionDetails": {
          "AmiSource": {
            "AmiId": "'$AMI_ID'",
            "AccessRoleArn": "'$MARKETPLACE_ACCESS_ROLE_ARN'",
            "UserName": "ubuntu",
            "OperatingSystemName": "Ubuntu",
            "OperatingSystemVersion": "22.04"
          },
          "UsageInstructions": "See https://coder.com/docs/v2/latest/quickstart/aws for usage instructions.",
          "RecommendedInstanceType": "t2.xlarge",
          "SecurityGroups": [
            {
              "IpProtocol": "tcp",
              "FromPort": 443,
              "ToPort": 443,
              "IpRanges": [
                "0.0.0.0/0"
              ]
            },
            {
              "IpProtocol": "tcp",
              "FromPort": 80,
              "ToPort": 80,
              "IpRanges": [
                "0.0.0.0/0"
              ]
            },
            {
              "IpProtocol": "tcp",
              "FromPort": 22,
              "ToPort": 22,
              "IpRanges": [
                "0.0.0.0/0"
              ]
            }
          ]
        }
      }
    }
  ]
}' | jq "tostring")

# Run AWS CLI command
# Entity identifier is same as the productId
aws marketplace-catalog start-change-set \
  --catalog "AWSMarketplace" \
  --change-set '[
      {
        "ChangeType": "AddDeliveryOptions",
        "Entity": {
          "Identifier": "'$PRODUCT_IDENTIFIER'",
          "Type": "AmiProduct@1.0"
        },
        "Details": '"${DETAILS_JSON_AS_STRING}"'
      }
    ]'
