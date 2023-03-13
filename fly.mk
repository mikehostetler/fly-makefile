SHELL := bash

PROJECT_ENV ?= ../.env
LOCAL_ENV ?= .env

-include $(PROJECT_ENV)
-include $(LOCAL_ENV)

ifdef VERBOSE
  Q :=
else
  Q := @
endif

TAG := $(shell git describe --exact-match --tags 2>/dev/null || git rev-parse --short HEAD)

FLY ?= flyctl
FLY_CONFIG ?= fly.toml
FLY_APP := $(shell grep -o 'app\s=\s"[^"]\+"' $(FLY_CONFIG) | cut -d'"' -f2)
FLY_ORG ?= "personal"
FLY_REGION ?= "iad"
FLY_API_TOKEN := $(shell $(FLY) auth token)
FLY_REGISTRY_APP ?= $(FLY_ORG)-registry
FLY_IMG_LABEL := $(FLY_APP)-$(TAG)
FLY_REGISTRY_IMG := registry.fly.io/$(FLY_REGISTRY_APP):$(FLY_IMG_LABEL)

TF ?= terraform
TF_VAR_APP := -var "app=$(FLY_APP)"
TF_VAR_ORG := -var "org=$(FLY_ORG)"
TF_VAR_IMAGE := -var "image=$(FLY_REGISTRY_IMG)"
TF_VAR_REGION := -var "region=$(FLY_REGION)"
TF_VAR_VOLUME_NAME := -var "volume_name=ashq_storage_data"
TF_VAR_SIZE := -var "size=2"

TF_VARS := $(TF_VAR_APP) \
			$(TF_VAR_ORG) \
			$(TF_VAR_IMAGE) \
			$(TF_VAR_REGION) \
			$(TF_VAR_VOLUME_NAME) \
			$(TF_VAR_SIZE)

default: 
	$(Q)echo "    __ _        _                  _        __ _ _     "
	$(Q)echo "   / _| |_  _  (_)___   _ __  __ _| |_____ / _(_) |___ "
	$(Q)echo "  |  _| | || |_| / _ \ | '  \/ _\ | / / -_)  _| | / -_)"
	$(Q)echo "  |_| |_|\_, (_)_\___/ |_|_|_\__,_|_\_\___|_| |_|_\___|"
	$(Q)echo "         |__/      "
	$(Q)echo ""
	$(Q)echo "+----------------------+"
	$(Q)echo "| Organization:        | $(FLY_ORG)"
	$(Q)echo "| Fly App:             | $(FLY_APP)"
	$(Q)echo "| Primary Region:      | $(FLY_REGION)"
	$(Q)echo "| Tag:                 | $(TAG)"
	$(Q)echo "| Auth Token:          | $(FLY_API_TOKEN)"
	$(Q)echo "| Registry App:        | $(FLY_REGISTRY_APP)"
	$(Q)echo "+----------------------+"
	$(Q)echo ""
	$(Q)echo "Usage: make <target>"
	$(Q)echo ""
	$(Q)echo "Run make targets"
	$(Q)echo ""
	$(Q)echo "Options:"
	$(Q)echo "   VERBOSE=1 make <target> # See what commands are being executed"
	$(Q)echo "   make <target> --dry-run # Dry Run"
	$(Q)echo ""
	$(Q)echo "Overrides:"
	$(Q)echo ""
	$(Q)echo "   Global make targets can be overridden in the project Makefile"
	$(Q)echo "     - Create a new local target without the wildcard"
	$(Q)echo "       install: overrides instal%:"
	$(Q)echo ""
	$(Q)for file in $(MAKEFILE_LIST); do \
		if echo $$file | grep -qv $(LOCAL_ENV); then \
			echo "**Available Targets in $$file:"; \
			grep -E '^[a-zA-Z0-9_-]+\/?[a-zA-Z0-9_-]*%?:.*?## .*$$' $$file | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'; \
			echo ""; \
		fi \
	done

.PHONY: instal%
instal%: ## Install project dependencies
	@if ! command -v fly &> /dev/null ; then \
		echo "Installing fly"; \
		brew install flyctl; \
	else \
		echo "Fly is already installed"; \
	fi

.PHONY: chec%
chec%: ## Check project dependencies
	$(Q)echo "Checking dependencies..."
	$(Q)which docker >/dev/null 2>&1 || { echo >&2 "Docker is not installed. Please install Docker and try again."; exit 1; }
	$(Q)docker ps >/dev/null 2>&1 || { echo >&2 "Docker is not running. Please start Docker and try again."; exit 1; }
	$(Q)echo "All dependencies are installed and running."

fly/creat%: ## Create the Fly App directly
	$(Q)if $(FLY) apps list | grep -q '^$(FLY_APP)'; then \
        echo "App $(FLY_APP) already exists"; \
    else \
        $(FLY) apps create $(FLY_APP) --machines --org $(FLY_ORG); \
    fi

fly/destro%: ## Destroy the Fly App directly
	$(Q)if $(FLY) apps list | grep '^$(FLY_APP)' > /dev/null; then \
		read -p "Are you sure you want to destroy the $(FLY_APP) app? (y/N) " confirm; \
		if [ "$$confirm" = "y" ]; then \
			$(FLY) apps destroy $(FLY_APP) -y; \
		else \
			echo "Aborting destroy"; \
		fi; \
	else \
		echo "App $(FLY_APP) does not exist"; \
	fi

fly/create_registr%: ## Create an app to act as a Docker Registry
	$(Q)if $(FLY) apps list | grep -q '^$(FLY_REGISTRY_APP)'; then \
        echo "App $(FLY_REGISTRY_APP) already exists"; \
    else \
        $(FLY) apps create $(FLY_REGISTRY_APP) --machines --org $(FLY_ORG); \
    fi

fly/pus%: fly/create_registry ## Push the Docker image to the Fly Registry
	$(FLY) deploy --config $(FLY_CONFIG) --app $(FLY_REGISTRY_APP) --build-only --remote-only --image-label $(FLY_IMG_LABEL) --push

fly/deplo%: fly/push ## Deploy the Docker image from the Fly Registry
	$(FLY) deploy --config $(FLY_CONFIG) --app $(FLY_APP) --image $(FLY_REGISTRY_IMG) --detach

fly/secret%: ## Import secrets from a file
	$(Q)cat $(LOCAL_ENV) | sed '/^\s*#/d;s/#.*//' | sed 's/\\"/"/g;s/"\([^"]*\)"/\1/g;s/"//g' | $(FLY) secrets import

tf/ini%:
	$(Q)if [ ! -d .terraform ]; then \
		echo "Initializing Terraform..."; \
		$(TF) init; \
	fi	

tf/fmt%:
	$(TF) fmt

tf/pla%:
	$(TF) plan $(TF_VARS)

tf/appl%:
	$(TF) apply $(TF_VARS) -auto-approve
