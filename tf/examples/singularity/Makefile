SCRIPTS=../../../scripts

.PHONY: plan apply destroy

$SCRIPTS/custom-controller-install: custom-controller-install
	ln -sfn $$PWD/custom-controller-install ../../../scripts/custom-controller-install

plan:
	terraform plan -var-file=basic.tfvars -out terraform.tfplan

apply: $SCRIPTS/custom-controller-install
	terraform apply -var-file=basic.tfvars -auto-approve

destroy:
	terraform destroy -var-file=basic.tfvars -auto-approve
