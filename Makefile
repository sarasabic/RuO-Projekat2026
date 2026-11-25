#   make help ispisuje sve ciljeve
#   make all      prazan sistem -> aplikacija koja radi   (infra -> config -> dns -> deploy)
#   make test     testovi: SSH, DNS, izolacija mreže, aplikacija i trajnost podataka
#   make destroy  uklanja sve što je projekat kreirao

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.RECIPEPREFIX := >
.DEFAULT_GOAL := help

ZONE      := sarasabicdns.lab
IMAGE_URL := https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
IMAGE     := $(HOME)/.cache/ruo/noble-server-cloudimg-amd64.img
TF_VM     := terraform -chdir=terraform/vm
TF_DNS    := terraform -chdir=terraform/dns
SSH_OPTS  := -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR

# TSIG secret se čita iz ključa koji je Ansible preuzeo sa vm-dns (.secrets/ nije u Gitu)
TSIG   = TF_VAR_tsig_secret="$$(awk -F'"' '/secret/{print $$2}' .secrets/tf-key.key)"

# Adrese uvijek dolaze iz Terraform outputa, nikad se ne kucaju ručno

VM_ENV = APP_IP="$$($(TF_VM) output -raw app_ip)" DNS_IP="$$($(TF_VM) output -raw dns_ip)" \
         ADMIN_USER="$$($(TF_VM) output -raw admin_user)" ZONE=$(ZONE)

banner = printf '\n\033[1;36m== %s\033[0m\n' '$(1)'

.PHONY: help check secrets image infra config dns deploy all test plan drift destroy tunnel ssh-app ssh-dns

##@ Pomoć
help: ## ovaj spisak
> @awk 'BEGIN{FS=":.*## "} /^##@/{printf "\n\033[1m%s\033[0m\n", substr($$0,5)} /^[a-zA-Z0-9_-]+:.*## /{printf "  \033[36m%-10s\033[0m %s\n",$$1,$$2}' $(MAKEFILE_LIST)

##@ Izgradnja (ovim redom; "make all" ih pokreće sve)
check: ## alati, verzija Ansiblea, KVM/libvirt, SSH ključ, Ansible kolekcije
> @for t in terraform ansible-playbook ansible-galaxy ansible-vault virsh dig nsupdate curl ssh openssl; do \
>   if command -v $$t >/dev/null; then printf '  \033[32mok\033[0m       %s\n' $$t; \
>   else printf '  \033[31mNEDOSTAJE\033[0m %s  (instalirati alate: README)\n' $$t; exit 1; fi; done
> @v=$$(ansible --version | sed -n 's/.*\[core \([0-9]*\.[0-9]*\).*/\1/p'); \
>   if [ -n "$$v" ] && [ "$$(printf '%s\n' 2.20 "$$v" | sort -V | sed -n 1p)" = 2.20 ]; then echo "  ok       ansible-core $$v"; \
>   else echo "  STARO    ansible-core '$$v' (potrebna podržana verzija >= 2.20: README)"; exit 1; fi
> @echo "  ok       $$(terraform version | sed -n 1p)"
> @test -e /dev/kvm && echo "  ok       /dev/kvm" || { echo "  NEDOSTAJE /dev/kvm (ugniježđena virtualizacija, README)"; exit 1; }
> @virsh -c qemu:///system pool-info default >/dev/null && echo "  ok       libvirt + pool 'default'" \
>   || { echo "  libvirt ne radi (README: rješavanje problema)"; exit 1; }
> @test -f ~/.ssh/id_ed25519.pub || ssh-keygen -q -t ed25519 -N "" -f ~/.ssh/id_ed25519
> @echo "  ok       SSH ključ ~/.ssh/id_ed25519"
> cd ansible && ansible-galaxy collection install -r requirements.yml -p collections

secrets: ## jednom pravi lokalne tajne: vault lozinku + šifrovani vault.yml sa nasumičnim lozinkama baze
> @mkdir -p .secrets && chmod 700 .secrets
> @test -f .secrets/vault_pass || { openssl rand -base64 32 > .secrets/vault_pass; chmod 600 .secrets/vault_pass; \
>   echo "napravljen .secrets/vault_pass"; }
> @test -f ansible/group_vars/all/vault.yml || { \
>   printf 'vault_postgres_password: "%s"\nvault_app_db_password: "%s"\n' "$$(openssl rand -hex 16)" "$$(openssl rand -hex 16)" \
>   | (cd ansible && ansible-vault encrypt --output group_vars/all/vault.yml -); \
>   echo "napravljen ansible/group_vars/all/vault.yml (šifrovan)"; }

image: ## jednom preuzima Ubuntu 24.04 cloud image (čuva se u ~/.cache, preživljava "destroy")
> @test -f $(IMAGE) || { mkdir -p $(dir $(IMAGE)); echo "preuzimam $(IMAGE_URL)"; \
>   curl -fL --progress-bar -o $(IMAGE).part $(IMAGE_URL) && mv $(IMAGE).part $(IMAGE); }
> @echo "bazni image: $(IMAGE)"

infra: check image ## Terraform: libvirt mreža + VM-ovi vm-app i vm-dns + Ansible inventory
> @$(call banner,Terraform: mreža i VM-ovi)
> $(TF_VM) init -input=false
> $(TF_VM) apply -auto-approve -input=false
> $(TF_VM) output

config: secrets ## Ansible: osnovna konfiguracija, BIND na vm-dns, Docker na vm-app
> @$(call banner,Ansible: role common + dns + docker)
> cd ansible && ansible-playbook config.yml

dns: ## Terraform: DNS zapisi servisa (RFC 2136 + TSIG)
> @$(call banner,Terraform: DNS zapisi u $(ZONE))
> $(TF_DNS) init -input=false
> $(TSIG) $(TF_DNS) apply -auto-approve -input=false

deploy: ## Ansible: kopira aplikaciju na vm-app, gradi image-e, pokreće stack
> @$(call banner,Ansible: rola app)
> cd ansible && ansible-playbook deploy.yml
> @echo; echo "Aplikacija: http://$$($(TF_VM) output -raw app_ip)/   (Windows preglednik: 'make tunnel', pa http://localhost:8080)"

all: infra config dns deploy ## sve, od praznog sistema do aplikacije koja radi

##@ Provjera
test: ## testovi: SSH, DNS, izolacija mreže, aplikacija + trajnost podataka
> @export $(VM_ENV); rc=0; \
>   for t in vm dns isolation app; do bash tests/$$t.sh || rc=1; done; \
>   if [ $$rc = 0 ]; then printf '\n\033[32mSVI TESTOVI PROŠLI\033[0m\n'; else printf '\n\033[31mNEKI TESTOVI NISU PROŠLI\033[0m\n'; fi; \
>   exit $$rc

plan: ## nakon "make all" oba plana moraju reći "No changes" 
> $(TF_VM) plan -detailed-exitcode -input=false
> $(TSIG) $(TF_DNS) plan -detailed-exitcode -input=false

drift: ## demo: DNS zapis se mijenja mimo Terraforma; plan to otkriva, apply popravlja
> @export $(VM_ENV) $(TSIG); bash tests/drift.sh

##@ Korištenje
tunnel: ## aplikacija na http://localhost:8080 (Ctrl+C zatvara)
> @echo "Otvori http://localhost:8080  Ctrl+C zatvara tunel."
> ssh $(SSH_OPTS) -N -L 8080:localhost:80 "$$($(TF_VM) output -raw admin_user)@$$($(TF_VM) output -raw app_ip)"

ssh-app: ## SSH na vm-app
> ssh $(SSH_OPTS) "$$($(TF_VM) output -raw admin_user)@$$($(TF_VM) output -raw app_ip)"

ssh-dns: ## SSH na vm-dns
> ssh $(SSH_OPTS) "$$($(TF_VM) output -raw admin_user)@$$($(TF_VM) output -raw dns_ip)"

##@ Čišćenje
destroy: ## uklanja sve što je projekat kreirao (čuva .secrets/ vault i preuzetu image)
> @$(call banner,Terraform: DNS zapisi)
> -test -f .secrets/tf-key.key && $(TF_DNS) init -input=false >/dev/null && $(TSIG) $(TF_DNS) destroy -auto-approve -input=false
> rm -f terraform/dns/terraform.tfstate terraform/dns/terraform.tfstate.backup .secrets/tf-key.key
> @$(call banner,Terraform: VM-ovi i mreža)
> $(TF_VM) init -input=false >/dev/null
> -for ip in $$($(TF_VM) output -json vm_ips 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+){3}'); do ssh-keygen -R $$ip >/dev/null 2>&1; done
> $(TF_VM) destroy -auto-approve -input=false
> rm -f ansible/inventory.yml