SHELL := /bin/bash
MYSQL57_VERSION := mysql:5.7.41
BINLOG_FORMATS := row mixed statement
RESULT_FILE := result.txt

.PHONY: default
default: help

.PHONY: help help-common
help: help-common

help-common:
	@grep -E '^[a-zA-Z0-9\._-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m %-30s\033[0m %s\n", $$1, $$2}'

.PHONY: test
test:
	docker-compose up -d
	docker-compose exec mysqld sh -c 'for i in $$(seq 60);do mysql -e "select version()" && exit; sleep 1;done'
	if docker-compose exec mysqld sh -c 'mysql --local-infile=1 </work/error.sql'; then \
		echo "$(IMAGE) : OK" >>$(RESULT_FILE); \
	else \
		echo "$(IMAGE) : NG" >>$(RESULT_FILE); \
	fi
	@echo '注意:'
	@echo '"ERROR 1048 (23000) at line XX: Column '\''addr'\'' cannot be null" と出るようならばバグが存在します'
	docker-compose down

.PHONY: test-rep
test-rep:
	docker-compose up -d
	docker-compose exec slave sh -c 'for i in $$(seq 60);do mysql -e "show slave status\G" | grep "Slave_IO_Running: Yes" && exit; sleep 1;done'
	docker-compose exec slave sh -c 'mysql -sNe "show variables" | grep -e gtid_mode -e sql_mode -e binlog_format'
	docker-compose exec master sh -c 'mysql --local-infile=1 </work/rep-error.sql;true'
	docker-compose exec master mysql bar -e 'UPDATE ip SET addr="192.168.0.1" WHERE id = 1'
	sleep 3
	docker-compose exec slave mysql bar -e 'select * from ip'
	docker-compose exec slave sh -c 'mysql -e "show slave status\G" | grep -e "_Running:" -e "Seconds_Behind_Master"'
	@echo '*******************************************************************************************************************'
	@echo '* 注意:'
	@echo '* IO_Thread か SQL_Thread が止まっていれば（"NO" になっていれば）レプリケーションが止まっていることになります'
	@echo '*******************************************************************************************************************'
	docker-compose logs --tail=5 slave
	docker-compose down

.PHONY: all
all: clean official-5.7 official-8.0 oracle-5.7 oracle-8.0 mariadb-10.7 mariadb-10.8 mariadb-10.9 ## すべてのテストを実施
	cat $(RESULT_FILE)

.PHONY: official-5.7 official-8.0 oracle-5.7 oracle-8.0 mariadb-10.7 mariadb-10.8 mariadb-10.9
official-5.7: ## docker official の MySQL 5.7 イメージでテスト
	@make IMAGE=$(MYSQL57_VERSION) test

official-8.0: ## docker official の MySQL 8.0 イメージでテスト
	@make IMAGE=mysql:8.0.32 test

oracle-5.7: ## Oracle の MySQL 5.7 イメージでテスト
	@make IMAGE=mysql/mysql-server:5.7.41 test

oracle-8.0: ## Oracle の MySQL 8.0 イメージでテスト
	@make IMAGE=mysql/mysql-server:8.0.32 test

mariadb-10.7: ## docker official の MariaDB 10.7 イメージでテスト
	@make IMAGE=mariadb:10.7.7 test

mariadb-10.8: ## docker official の MariaDB 10.8 イメージでテスト
	@make IMAGE=mariadb:10.8.6 test

mariadb-10.9: ## docker official の MariaDB 10.9 イメージでテスト
	@make IMAGE=mariadb:10.9.4 test

.PHONY: all-rep
define rep_target_template
.PHONY: rep-$(1) rep-gtid-$(1)
all-rep: rep-$(1) rep-gtid-$(1)

rep-$(1):
	@make IMAGE=$(MYSQL57_VERSION) COMPOSE_FILE=docker-compose-rep.yml BINLOG_FORMAT=$(1) test-rep

rep-gtid-$(1):
	@make IMAGE=$(MYSQL57_VERSION) COMPOSE_FILE=docker-compose-rep-gtid.yml BINLOG_FORMAT=$(1) test-rep

endef

$(foreach _fmt,$(BINLOG_FORMATS),$(eval $(call rep_target_template,$(_fmt)))): ## MySQL 5.7 イメージでレプリケーションが停止しないかのテスト

clean:
	rm -rf $(RESULT_FILE)
