init: # create required folder structure under $DATA from .env
init:
	@bash ./scripts/create_folder_structure.sh

down: # spin down the services
down:
	@docker-compose down

up: # spin up the services
up: init
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

.PHONY: rerun up down create-folder-structure stop start
