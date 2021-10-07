SCRIPTS=../scripts
PIPFILE=$(SCRIPTS)/Pipfile
PIPENV=PIPENV_PIPFILE=$(PIPFILE) pipenv
TFVARS=vars.tfvars

.PHONY: init validate plan apply destroy format

init:
	terraform init

validate:
	terraform validate

plan:
	terraform plan -var-file=$(TFVARS) -out terraform.tfplan

apply:
	terraform apply -var-file=$(TFVARS) -auto-approve

pipenv:
	$(PIPENV) install

destroy: pipenv
	$(PIPENV) run $(SCRIPTS)/destroy_nodes.py $(shell grep "project_id" $(TFVARS) | cut -d'=' -f2) $(shell grep "cluster_name" $(TFVARS) | cut -d'=' -f2)
	terraform destroy -var-file=$(TFVARS) -auto-approve

format:
	terraform fmt -recursive .
