.PHONY: plan apply destroy

plan:
	terraform plan -var="project=${PROJECT}" -var="region=${REGION}" -var-file=basic.tfvars -out terraform.tfplan

apply:
	terraform apply -var-file=basic.tfvars -auto-approve

destroy:
	terraform destroy -var-file=basic.tfvars -var="project=${PROJECT}" -var="region=${REGION}" -auto-approve
