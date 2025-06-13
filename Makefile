.PHONY: help install lint test deploy-staging deploy-production clean

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: ## Install Ansible and dependencies
	pip install -r requirements.txt
	ansible-galaxy install -r requirements.yml

lint: ## Run linting tools
	yamllint .
	ansible-lint playbooks/*.yml roles/*/tasks/*.yml

test: ## Run Molecule tests
	cd roles/common && molecule test
	cd ../security && molecule test
	cd ../docker && molecule test

vault-edit: ## Edit vault file
	ansible-vault edit group_vars/all/vault.yml

deploy-staging: ## Deploy to staging environment
	ansible-playbook -i inventories/staging/hosts.yml playbooks/site.yml --ask-vault-pass

deploy-production: ## Deploy to production environment
	ansible-playbook -i inventories/production/hosts.yml playbooks/site.yml --ask-vault-pass

backup-staging: ## Run backup on staging
	ansible-playbook -i inventories/staging/hosts.yml playbooks/backup.yml --ask-vault-pass

backup-production: ## Run backup on production
	ansible-playbook -i inventories/production/hosts.yml playbooks/backup.yml --ask-vault-pass

clean: ## Clean temporary files
	find . -type f -name '*.retry' -delete
	find . -type f -name '*.pyc' -delete
	find . -type d -name '__pycache__' -exec rm -rf {} +
