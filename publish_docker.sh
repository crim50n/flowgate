#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <docker_hub_username>"
  exit 1
fi

USERNAME=$1
REPO="flowgate"

# Variants
VARIANTS=("angie-blocky" "angie-adguardhome" "nginx-blocky" "nginx-adguardhome")

echo "Login to Docker Hub if you haven't already (docker login)"

for VARIANT in "${VARIANTS[@]}"; do
  TAG="$USERNAME/$REPO:$VARIANT"
  DOCKERFILE="Dockerfile.$VARIANT"
  
  echo "------------------------------------------------"
  echo "Building $TAG using $DOCKERFILE..."
  docker build -t "$TAG" -f "$DOCKERFILE" .
  
  echo "Pushing $TAG..."
  docker push "$TAG"
done

echo "------------------------------------------------"
echo "All images published successfully!"
