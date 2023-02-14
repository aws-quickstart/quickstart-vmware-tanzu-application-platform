PROFILE ?= default
REGIONS ?=
ACCOUNT_STACK ?= true
CLEAN_ACCOUNT ?= true
CLEAN_TYPES ?= true
CLEAN_REGIONAL ?= true

clean:
	rm -rf taskcat_outputs
	rm -rf .taskcat
	rm -rf functions/packages
	rm -rf *.zip

clean-aws:
	PROFILE=$(PROFILE) submodules/quickstart-amazon-eks/build/clean-aws.sh "$(REGIONS)"

lint:
	cfn-lint templates/*.yaml

init-submodules:
	scripts/init-submodules.sh
