.PHONY: build debug

build:
	packer build -var-file=vars.pkrvars.hcl .

validate:
	packer validate -var-file=vars.pkrvars.hcl .

init:
	packer init .

debug:
	packer build -var-file=vars.pkrvars.hcl -debug .

inspect:
	packer inspect -var-file=vars.pkrvars.hcl .
