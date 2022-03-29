# Two options:
# (1) Use `make [COMMAND] PKRHCL=example.pkr.hclvars`
# (2) Use `make [COMMAND]` and example.auto.pkr.hclvars
PKRHCL=

.PHONY: init
init:
	packer init .

.PHONY: validate
validate:
        ifeq ($(strip $(PKRHCL)),)
	packer validate .
        else
	packer validate -var-file=$(PKRHCL) .
        endif

.PHONY: inspect
inspect: validate
        ifeq ($(strip $(PKRHCL)),)
	packer inspect .
        else
	packer inspect -var-file=$(PKRHCL) .
        endif

.PHONY: build
build: init validate
        ifeq ($(strip $(PKRHCL)),)
	packer build .
        else
	packer build -var-file=$(PKRHCL) .
        endif

.PHONY: build-debug
build-debug: init validate
        ifeq ($(strip $(PKRHCL)),)
	packer build -debug .
        else
	packer build -debug -var-file=$(PKRHCL) .
        endif

.PHONY: fmt
fmt:
	packer fmt -recursive .
