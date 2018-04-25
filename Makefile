SHELL := /bin/bash

.PHONY: default
default: help

.PHONY: help help-common
help: help-common

help-common:
	@grep -E '^[a-zA-Z0-9\._-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m %-30s\033[0m %s\n", $$1, $$2}'

#	echo '"ERROR 1048 (23000) at line 17: Column \'addr\' cannot be null" と出るようならばバグが存在します'
.PHONY: test
test:
	docker-compose up -d
	docker-compose exec mysqld sh -c 'for i in $$(seq 60);do mysql -e "select version()" && exit; sleep 1;done'
	docker-compose exec mysqld sh -c 'mysql --local-infile=1 </work/error.sql;true'
	@echo '注意:'
	@echo '"ERROR 1048 (23000) at line 17: Column '\''addr'\'' cannot be null" と出るようならばバグが存在します'
	docker-compose down

.PHONY: all
all: official-5.7 official-8.0 oracle-5.7 oracle-8.0 mariadb-10.1 mariadb-10.2 mariadb-10.3 ## すべてのテストを実施

.PHONY: official-5.7 official-8.0 oracle-5.7 oracle-8.0 mariadb-10.1 mariadb-10.2 mariadb-10.3
official-5.7: ## docker official の MySQL 5.7 イメージでテスト
	@make IMAGE=mysql:5.7.22 test

official-8.0: ## docker official の MySQL 8.0 イメージでテスト
	@make IMAGE=mysql:8.0.11 test

oracle-5.7: ## Oracle の MySQL 5.7 イメージでテスト
	@make IMAGE=mysql/mysql-server:5.7.22 test

oracle-8.0: ## Oracle の MySQL 8.0 イメージでテスト
	@make IMAGE=mysql/mysql-server:8.0.11 test

mariadb-10.1: ## docker official の MariaDB 10.1 イメージでテスト
	@make IMAGE=mariadb:10.1.32 test

mariadb-10.2: ## docker official の MariaDB 10.2 イメージでテスト
	@make IMAGE=mariadb:10.2.14 test

mariadb-10.3: ## docker official の MariaDB 10.3 イメージでテスト
	@make IMAGE=mariadb:10.3.6 test

