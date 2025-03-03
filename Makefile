SCRIPT_DIR := $(shell cd $(dir $(abspath $(lastword $(MAKEFILE_LIST)))) && pwd)
APP_NAME := baseport
STAGE ?=
COMPONENT ?=
ADDR ?=
ID ?=
COMMON_BACKEND_CONFIG := $(SCRIPT_DIR)/terraform/components/tfvars/backend.tfvars
COMMON_TFVARS := $(SCRIPT_DIR)/terraform/components/tfvars/common.tfvars
COMPONENT_DIR := $(SCRIPT_DIR)/terraform/components/$(COMPONENT)
COMPONENT_TFVARS=$(COMPONENT_DIR)/tfvars/$(STAGE).tfvars
TFPLAN_DIR := $(SCRIPT_DIR)/terraform/.tfplan/$(STAGE)/$(COMPONENT)

.PHONY: option-parser
option-parser:
	@if [ -z "$(STAGE)" ]; then \
	  echo "[Err] STAGE is required"; \
	  exit 1; \
	fi
	@if [ -z "$(COMPONENT)" ]; then \
	  echo "[Err] COMPONENT is required"; \
	  exit 1; \
	fi

.PHONY: tf-init
tf-init: option-parser ## terraform init
	terraform -chdir=$(COMPONENT_DIR) init \
	  -upgrade \
	  -reconfigure \
	  -backend-config $(COMMON_BACKEND_CONFIG) \
	  -backend-config "key=$(APP_NAME)/$(STAGE)/$(COMPONENT)/terraform.tfstate"

.PHONY: tf-validate 
tf-validate: tf-init  ## terraform validate
	terraform -chdir=$(COMPONENT_DIR) validate

.PHONY: tf-plan
tf-plan: tf-validate ## terraform plan
	mkdir -p $(TFPLAN_DIR)
	terraform -chdir=$(COMPONENT_DIR) plan \
	  -var "app_name=$(APP_NAME)" \
	  -var "stage=$(STAGE)" \
	  -var-file=$(COMMON_TFVARS) \
	  -var-file=$(COMPONENT_TFVARS) \
	  -out $(TFPLAN_DIR)/.plan
	terraform -chdir=$(COMPONENT_DIR) show -json $(TFPLAN_DIR)/.plan > $(TFPLAN_DIR)/plan.tfgraph

.PHONY: tf-apply
tf-apply: tf-validate ## terraform apply
	terraform -chdir=$(COMPONENT_DIR) apply \
	  -var "app_name=$(APP_NAME)" \
	  -var "stage=$(STAGE)" \
	  -var-file=$(COMMON_TFVARS) \
	  -var-file $(COMPONENT_TFVARS) \
	  --auto-approve

.PHONY: tf-output
tf-output: tf-validate ## terraform apply
	terraform -chdir=$(COMPONENT_DIR) output

.PHONY: tf-destroy
tf-destroy: tf-validate ## terraform destroy
	terraform -chdir=$(COMPONENT_DIR) destroy \
	  -var "app_name=$(APP_NAME)" \
	  -var "stage=$(STAGE)" \
	  -var-file=$(COMMON_TFVARS) \
	  -var-file $(COMPONENT_TFVARS) \
	  --auto-approve

.PHONY: tf-import
tf-import: tf-validate ## terraform destroy
	@if [ -z "$(ADDR)" ]; then \
	  echo "[Err] ADDR is required"; \
	  exit 1; \
	fi
	@if [ -z "$(ID)" ]; then \
	  echo "[Err] ID is required"; \
	  exit 1; \
	fi
	terraform -chdir=$(COMPONENT_DIR) import \
	  -var "app_name=$(APP_NAME)" \
	  -var "stage=$(STAGE)" \
	  -var-file $(COMMON_TFVARS) \
	  -var-file $(COMPONENT_TFVARS) \
		'$(ADDR)' \
		'$(ID)'

.PHONY: help
.DEFAULT_GOAL := help
help: ## HELP表示
	@grep --no-filename -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'