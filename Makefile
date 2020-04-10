DOCKER_BUILDKIT ?= 1

all: docker

docker: Dockerfile
	@docker buildx build \
		--platform linux/arm/v6 \
		--platform linux/arm64 \
		--platform linux/amd64 \
		--push \
		--tag hairyhenderson/shairport-sync .

.PHONY: gen-changelog clean test build-x compress-all build-release build test-integration-docker gen-docs lint clean-images clean-containers docker-images
.DELETE_ON_ERROR:
.SECONDARY:
