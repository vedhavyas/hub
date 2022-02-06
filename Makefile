down: # spin down the services
down:
	@docker-compose down

up: # spin up the services
up:
	@docker-compose up -d --remove-orphans

stop: # stops the containers
stop:
	@docker-compose stop

start: # starts the containers
start:
	@docker-compose start

help: # shows this help
	@sed -ne '/@sed/!s/# //p' $(MAKEFILE_LIST)

.PHONY: up down stop start
