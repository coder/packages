#!/bin/bash

# Get the image ID from the Packer manifest
if [ -z "$IMAGE_ID" ]; then
    IMAGE_ID=$(cat ./packer-manifest.json | jq -r 'last(.builds[] | select(.builder_type=="googlecompute").artifact_id)' | cut -f2 -d":")
fi

# Make the image public
gcloud compute images add-iam-policy-binding \
    $IMAGE_ID --member=allAuthenticatedUsers \
    --role=roles/compute.imageUser

# TODO: Publish to the marketplace.
# We have an open support case with GCP to determine
# whether this is possible:
# https://partnersupport.cloud.google.com/case/46715431
