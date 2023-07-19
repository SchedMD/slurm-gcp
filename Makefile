TF=terraform
PK=packer
PC=pre-commit
CHDIR=.

help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<tarinit>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Terraform

.PHONY: tf-init
tf-init: ## Run terraform init
	$(TF) -chdir=$(CHDIR) init

.PHONY: tf-init-recursive
tf-init-recursive: ## Run terraform init recursively
	find . -type d -name '\.terraform' -prune -o -type f -name '*.tf' -printf '%h\n' | sort -u | xargs -I{} $(TF) -chdir={} init

.PHONY: tf-init-upgrade
tf-init-upgrade: ## Run terraform init -upgrade
	$(TF) -chdir=$(CHDIR) init -upgrade

.PHONY: tf-init-upgrade-recursive
tf-init-upgrade-recursive: ## Run terraform init recursively
	find . -type d -name '\.terraform' -prune -o -type f -name '*.tf' -printf '%h\n' | sort -u | xargs -I{} $(TF) -chdir={} init -upgrade

.PHONY: tf-validate
tf-validate: ## Run terraform validate
	$(TF) -chdir=$(CHDIR) validate

.PHONY: tf-plan
tf-plan: tf-init tf-validate ## Run terraform plan
	$(TF) -chdir=$(CHDIR) plan

.PHONY: tf-apply
tf-apply: tf-init tf-validate ## Run terraform apply
	$(TF) -chdir=$(CHDIR) apply -auto-approve

.PHONY: tf-destroy
tf-destroy: tf-init tf-validate ## Run terraform destroy
	$(TF) -chdir=$(CHDIR) destroy -auto-approve

.PHONY: tf-fmt
tf-fmt: ## Run terraform fmt -recursive
	$(TF) -chdir=$(CHDIR) fmt -recursive

.PHONY: tf-test
tf-test: tf-init tf-validate ## Run terraform tests
	$(TF) test

##@ Packer

.PHONY: pk-init
pk-init: ## Run packer init
	$(PK) init $(CHDIR)

.PHONY: pk-init-upgrade
pk-init-upgrade: ## Run packer init -upgrade
	$(PK) init -upgrade $(CHDIR)

.PHONY: pk-validate
pk-validate: ## Run packer validate
	$(PK) validate $(CHDIR)

.PHONY: pk-build
pk-build: pk-init pk-validate ## Run packer build
	$(PK) build $(CHDIR)

.PHONY: pk-build-debug
pk-build-debug: pk-init pk-validate ## Run packer build -debug
	$(PK) build -debug $(CHDIR)

.PHONY: pk-fmt
pk-fmt: ## Run packer fmt -recursive
	$(PK) fmt -recursive $(CHDIR)

##@ Pre-commit

.PHONY: pc-run
pc-run: ## Run pre-commit run --all-files
	$(PC) run --all-files

.PHONY: pc-autoupdate
pc-autoupdate: ## Run pre-commit autoupdate
	$(PC) autoupdate
