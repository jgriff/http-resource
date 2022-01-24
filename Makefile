# ######################################################################################################################
# Globals
# ######################################################################################################################
SHELL = /bin/bash

COLOR_RED=\033[0;31m
COLOR_GREEN=\033[0;32m
COLOR_ORANGE=\033[0;33m
COLOR_BLUE=\033[0;34m
COLOR_PURPLE=\033[0;35m
COLOR_TEAL=\033[0;36m
COLOR_WHITE=\033[0;37m
COLOR_RESET=\033[0m

IMAGE=jgriff/http-resource
VERSION=dev

# ######################################################################################################################
# Primary goals
#
# build - Build all image variants.
# test - Run all tests against all image variants.
# release - Release all image variants.
#
# ######################################################################################################################

.DEFAULT_GOAL := build

# ---------------------------------------------------------------------------------------
# build
# ---------------------------------------------------------------------------------------
.PHONY: build build_latest
build: build_latest
build: TAG=${VERSION}
build:
	@echo -e "\n[${COLOR_BLUE}build${COLOR_RESET}/${COLOR_TEAL}${TAG}${COLOR_RESET}] ${COLOR_ORANGE}Building image${COLOR_RESET}..."
	@docker build -t ${IMAGE}:${TAG} -t ${IMAGE}:$(shell echo ${TAG} | rev | cut -d '.' -f2- | rev ) .
build_latest:
	@echo -e "\n[${COLOR_BLUE}build${COLOR_RESET}/${COLOR_TEAL}latest${COLOR_RESET}] ${COLOR_ORANGE}Building image${COLOR_RESET}..."
	@docker build -t ${IMAGE} .

# ---------------------------------------------------------------------------------------
# test
# ---------------------------------------------------------------------------------------
.PHONY: test test_latest
test: test_latest
test: TAG=${VERSION}
test_latest: TAG=latest
test test_latest:
	@echo -e "\n[${COLOR_BLUE}test${COLOR_RESET}/${COLOR_TEAL}${TAG}${COLOR_RESET}] ${COLOR_ORANGE}Testing image${COLOR_RESET}..."
	@./test/run.sh -i ${IMAGE}:${TAG} -v

.PHONY: test_shell
test_shell:
	@echo -e "[${COLOR_BLUE}test${COLOR_RESET}/${COLOR_TEAL}shell${COLOR_RESET}] ${COLOR_ORANGE}Launching test shell${COLOR_RESET}..."
	@./test/run.sh shell

# ---------------------------------------------------------------------------------------
# release
# ---------------------------------------------------------------------------------------
.PHONY: release release_latest
release: release_latest
release: TAG=${VERSION}
release_latest: TAG=latest
release release_latest:
	@echo -e "\n[${COLOR_BLUE}release${COLOR_RESET}/${COLOR_TEAL}${TAG}${COLOR_RESET}] ${COLOR_ORANGE}Pushing image${COLOR_RESET}..."
	@docker buildx create --name http-resource-builder
	@docker buildx build --builder http-resource-builder --platform linux/amd64,linux/arm64/v8 --push --tag ${IMAGE}:$(shell echo ${TAG} | rev | cut -d '.' -f2- | rev ) .
	@docker buildx build --builder http-resource-builder --platform linux/amd64,linux/arm64/v8 --push --tag ${IMAGE}:${TAG} .
	@docker buildx rm http-resource-builder
