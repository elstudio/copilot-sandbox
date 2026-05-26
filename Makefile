SSH_KEY_DIR := .ssh
SSH_KEY     := $(SSH_KEY_DIR)/copilot-sandbox

.PHONY: build up down ssh clean help

$(SSH_KEY):
	@mkdir -p $(SSH_KEY_DIR)
	@ssh-keygen -t ed25519 -f $(SSH_KEY) -N "" -q
	@echo "✓ SSH keypair generated at $(SSH_KEY)"

build: ## Build the container
	container-compose build

up: $(SSH_KEY) build ## Build and start the container
	# Work around a bug https://github.com/Mcrich23/Container-Compose/issues/93
	# container-compose up -d --build 
	container run -d --rm --name copilot-cli -c 2 -m 2G -p 2222:22 --ssh -v ./.ssh/copilot-sandbox.pub:/tmp/authorized_keys:ro copilot-cli

down: ## Stop and remove the container
	container-compose down

ssh: ## SSH into the container
	ssh -p 2222 -i $(SSH_KEY) -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null dev@localhost

clean: ## Remove container, image, and SSH keys
	container-compose down
	#container rm copilot-cli
	rm -rf $(SSH_KEY_DIR)

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
