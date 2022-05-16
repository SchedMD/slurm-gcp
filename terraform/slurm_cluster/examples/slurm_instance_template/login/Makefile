# Two options:
# (1) Use `make [COMMAND] TVFARS=example.tfvars`
# (2) Use `make [COMMAND]` and example.auto.tfvars
TFVARS=

.PHONY: init
init:
	terraform init

.PHONY: validate
validate:
	terraform validate

.PHONY: plan
plan: init validate
        ifeq ($(strip $(TFVARS)),)
	terraform plan -out terraform.tfplan
        else
	terraform plan -var-file=$(TFVARS) -out terraform.tfplan
        endif

.PHONY: apply
apply: init validate
        ifeq ($(strip $(TFVARS)),)
	terraform apply -auto-approve
        else
	terraform apply -var-file=$(TFVARS) -auto-approve
        endif

.PHONY: destroy
destroy: init validate
        ifeq ($(strip $(TFVARS)),)
	terraform destroy -auto-approve
        else
	terraform destroy -var-file=$(TFVARS) -auto-approve
        endif
