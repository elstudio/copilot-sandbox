SSH_KEY_DIR := .ssh
SSH_KEY     := $(SSH_KEY_DIR)/copilot-sandbox

# DNS server the image builder and the proxy sidecar use to resolve hosts.
# Apple's `container` builder gets no DNS by default, so apt-get update fails
# with "Temporary failure resolving 'ports.ubuntu.com'". Override if 1.1.1.1
# is blocked on your network, e.g. `make build BUILDER_DNS=192.168.4.1`.
BUILDER_DNS ?= 1.1.1.1
CONTAINER_NAME ?= copilot-cli
PROXY_NAME ?= copilot-proxy
PROXY_PORT ?= 8888
# No-NAT network copilot-cli lives on. Its only route to the internet is
# through $(PROXY_NAME), which allowlists destinations per
# proxy/allowlist.conf — see the "Network isolation" section in README.md.
INTERNAL_NETWORK ?= sandbox-internal
# The proxy sidecar's IP isn't stable across `container stop`/`start` (no
# static-IP option in this runtime), so it's written here and bind-mounted
# into copilot-cli instead of baked into a container env var at creation
# time. Gitignored; recreated by `wire-proxy`.
RUNTIME_DIR    := .runtime
PROXY_IP_FILE  := $(RUNTIME_DIR)/proxy-ip

.PHONY: start build network wire-proxy up down stop ssh clean ls help

$(SSH_KEY):
	@mkdir -p $(SSH_KEY_DIR)
	@ssh-keygen -t ed25519 -f $(SSH_KEY) -N "" -q
	@echo "✓ SSH keypair generated at $(SSH_KEY)"

start: ## Start the existing container and its proxy sidecar
	container start $(PROXY_NAME)
	$(MAKE) wire-proxy
	container start $(CONTAINER_NAME)

build: ## (Re)start the image builder and build the sandbox + proxy images
	container system start
	container-compose build

network: ## Create the internal (no-internet) sandbox network, if missing
	@container network inspect $(INTERNAL_NETWORK) >/dev/null 2>&1 || container network create --internal $(INTERNAL_NETWORK)

wire-proxy: ## (internal) record the proxy sidecar's current internal IP for copilot-cli
	@mkdir -p $(RUNTIME_DIR)
	@container inspect $(PROXY_NAME) | jq -r '.[0].status.networks[] | select(.network=="$(INTERNAL_NETWORK)") | .ipv4Address' | cut -d/ -f1 > $(PROXY_IP_FILE)

up: $(SSH_KEY) build network ## Build and start the sandbox behind an egress-allowlisting proxy
	container run -d --name $(PROXY_NAME) \
		--network default --network $(INTERNAL_NETWORK) \
		--dns $(BUILDER_DNS) \
		$(PROXY_NAME)
	$(MAKE) wire-proxy
	container run -d --name $(CONTAINER_NAME) -c 2 -m 2G -p 2222:22 --ssh \
		--network $(INTERNAL_NETWORK) \
		-v $(CURDIR)/$(PROXY_IP_FILE):/etc/copilot-sandbox/proxy-ip:ro \
		-v ./.ssh/copilot-sandbox.pub:/tmp/authorized_keys:ro -v ~/code/sandbox:/home/dev/code $(CONTAINER_NAME)

down: ## Stop and remove the container and proxy sidecar
	-container stop $(CONTAINER_NAME)
	-container rm $(CONTAINER_NAME)
	-container stop $(PROXY_NAME)
	-container rm $(PROXY_NAME)

stop: ## Stop the container and proxy, saving state
	container stop $(CONTAINER_NAME)
	container stop $(PROXY_NAME)

ssh: ## SSH into the container
	ssh -p 2222 -i $(SSH_KEY) -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null dev@localhost

clean: down ## Remove containers, the internal network, and SSH keys
	-container network rm $(INTERNAL_NETWORK)
	rm -rf $(SSH_KEY_DIR) $(RUNTIME_DIR)

ls: ## List all containers
	container ls --all

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
