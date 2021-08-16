.PHONY: init validate inspect build debug

init:
	packer init .

validate:
	packer validate -var-file=vars.pkrvars.hcl .

inspect:
	packer inspect -var-file=vars.pkrvars.hcl .

build:
	packer build -var-file=vars.pkrvars.hcl .

debug:
	packer build -var-file=vars.pkrvars.hcl -debug .
