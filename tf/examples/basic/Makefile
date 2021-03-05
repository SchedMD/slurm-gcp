.PHONY: plan apply destroy

plan:
	terraform plan -var-file=local.tfvars -out terraform.tfplan

apply:
	terraform apply -var-file=local.tfvars -auto-approve

destroy:
	terraform destroy -var-file=local.tfvars -auto-approve
