TFVARS=vars.tfvars

.PHONY: init validate plan apply destroy

init:
	terraform init

validate:
	terraform validate

plan: init validate
	terraform plan -var-file=$(TFVARS) -out terraform.tfplan

apply: init validate
	terraform apply -var-file=$(TFVARS) -auto-approve

destroy: init validate
	terraform destroy -var-file=$(TFVARS) -auto-approve
