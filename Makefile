down: # spin down the services
down:
	@docker-compose down

up: # spin up the services
up:
	@if ! command -v systemd-detect-virt &> /dev/null; then\
        docker-compose up -d;\
        exit;\
    else\
		VIRTUALIZATION=$(systemd-detect-virt -v) docker-compose up -d;\
	fi

stop: # stops the containers
stop:
	@docker-compose stop

start: # starts the containers
start:
	@docker-compose start

help: # shows this help
	@sed -ne '/@sed/!s/# //p' $(MAKEFILE_LIST)

setup-filerun-cron: # setup filerun index cron job
	@./scripts/setup_filerun_index_cron.sh

setup-folder-structure: # setup folder structure
	@./scripts/create_folder_structure.sh

.PHONY: up down stop start setup-filerun-cron setup-folder-structure
