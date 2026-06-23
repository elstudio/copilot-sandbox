SSH_KEY_DIR := .ssh
SSH_KEY     := $(SSH_KEY_DIR)/copilot-sandbox

.PHONY: build up down ssh clean help

$(SSH_KEY):
	@mkdir -p $(SSH_KEY_DIR)
	@ssh-keygen -t ed25519 -f $(SSH_KEY) -N "" -q
	@echo "✓ SSH keypair generated at $(SSH_KEY)"

start:
	container start copilot-cli

build: ## Build the container
	container system start
	container-compose build

up: $(SSH_KEY) build ## Build and start the container
	container-compose up -d
# 	container run -d --name copilot-cli -c 2 -m 2G -p 2222:22 --ssh -v ./.ssh/copilot-sandbox.pub:/tmp/authorized_keys:ro -v ~/code/sandbox:/home/dev/code copilot-cli

down: ## Stop and remove the container
	container-compose down

ssh: start ## SSH into the container
	ssh -p 2222 -i $(SSH_KEY) -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null dev@localhost

clean: down ## Remove container, image, and SSH keys
	container rm copilot-cli
	rm -rf $(SSH_KEY_DIR)
	
ls: ## List all containers 
	container ls --all

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
