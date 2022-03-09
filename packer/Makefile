.PHONY: init validate inspect build debug format

init:
	packer init .

validate:
	packer validate -var-file=vars.pkrvars.hcl .

inspect:
	packer inspect -var-file=vars.pkrvars.hcl .

build: init validate
	packer build -var-file=vars.pkrvars.hcl .

debug: init validate
	packer build -var-file=vars.pkrvars.hcl -debug .

format:
	packer fmt -recursive .
