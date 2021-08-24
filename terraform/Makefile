SCRIPTS=../scripts

.PHONY: init validate plan apply destroy format

init:
	terraform init

validate:
	terraform validate

plan:
	terraform plan -var-file=vars.tfvars -out terraform.tfplan

apply:
	terraform apply -var-file=vars.tfvars -auto-approve

destroy:
	terraform destroy -var-file=vars.tfvars -auto-approve

format:
	terraform fmt -recursive .
