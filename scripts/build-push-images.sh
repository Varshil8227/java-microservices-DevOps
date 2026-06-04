#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${DOCKERHUB_USERNAME:-}" ]]; then
  echo "DOCKERHUB_USERNAME is required"
  exit 1
fi

IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD 2>/dev/null || echo local)}"
SERVICES=(config-server customer discovery gateway notification order payment product)

for service in "${SERVICES[@]}"; do
  image="${DOCKERHUB_USERNAME}/java-microservice-${service}:${IMAGE_TAG}"
  latest="${DOCKERHUB_USERNAME}/java-microservice-${service}:latest"

  echo "Building ${image}"
  docker build -t "${image}" -t "${latest}" "services/${service}"

  echo "Pushing ${image}"
  docker push "${image}"
  docker push "${latest}"
done

echo "Pushed all images with tag ${IMAGE_TAG}"
