SSH_KEY_DIR := .ssh
SSH_KEY     := $(SSH_KEY_DIR)/copilot-sandbox

# DNS server the image builder uses to resolve package mirrors during `build`.
# Apple's `container` builder gets no DNS by default, so apt-get update fails
# with "Temporary failure resolving 'ports.ubuntu.com'". Override if 1.1.1.1
# is blocked on your network, e.g. `make build BUILDER_DNS=8.8.8.8`.
BUILDER_DNS ?= 1.1.1.1
CONTAINER_NAME ?= copilot-cli

.PHONY: start build builder up down stop ssh clean ls help

$(SSH_KEY):
	@mkdir -p $(SSH_KEY_DIR)
	@ssh-keygen -t ed25519 -f $(SSH_KEY) -N "" -q
	@echo "✓ SSH keypair generated at $(SSH_KEY)"

start: ## Start an existing container
	container start $(CONTAINER_NAME)

builder: ## (Re)start the image builder with a working DNS server
	container system start
	container builder stop
	container builder start --dns $(BUILDER_DNS)

build: builder ## Build the container
	container-compose build

up: $(SSH_KEY) build ## Build and start the container
# 	container-compose up -d
	container run -d --name $(CONTAINER_NAME) -c 2 -m 2G -p 2222:22 --ssh --dns $(BUILDER_DNS) -v ./.ssh/copilot-sandbox.pub:/tmp/authorized_keys:ro -v ~/code/sandbox:/home/dev/code $(CONTAINER_NAME)

down: ## Stop and remove the container
	container-compose down
	
stop: ## Stop the container, saving state
	container stop $(CONTAINER_NAME)

ssh: start ## SSH into the container
	ssh -p 2222 -i $(SSH_KEY) -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null dev@localhost

clean: stop ## Remove container, image, and SSH keys
	container rm $(CONTAINER_NAME)
	rm -rf $(SSH_KEY_DIR)
	
ls: ## List all containers 
	container ls --all

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
