init: # create required folder structure under $DATA from .env
init:
	@sh ./scripts/create_folder_structure.sh

down: # spin down the services
down:
	@docker-compose down

up: # spin up the services
up: down init
	@docker-compose up -d

help: # shows this help
	@sed -ne '/@sed/!s/# //p' $(MAKEFILE_LIST)

.PHONY: rerun up down create-folder-structure
