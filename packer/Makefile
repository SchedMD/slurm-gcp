.PHONY: init validate inspect build debug format

init:
	packer init .
	ansible-galaxy install --role-file ../ansible/requirements.yml

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
