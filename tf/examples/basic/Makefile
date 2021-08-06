SCRIPTS=../../../scripts

.PHONY: plan apply destroy import

plan:
	terraform plan -var-file=basic.tfvars -out terraform.tfplan

apply:
	terraform apply -var-file=basic.tfvars -auto-approve

import:
	@python3 $(SCRIPTS)/import.py

destroy: import
	terraform destroy -var-file=basic.tfvars -auto-approve
