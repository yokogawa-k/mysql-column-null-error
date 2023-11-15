SHELL := /bin/bash
MYSQL57_VERSION := 5.7.42
MYSQL80_VERSION := 8.0.33
BINLOG_FORMATS := row mixed statement
RESULT_FILE := result.txt

TARGET_IMAGE := mysql

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
all: clean official-5.7 official-8.0 mariadb-10.7 mariadb-10.8 mariadb-10.9 ## すべてのテストを実施
	cat $(RESULT_FILE)

.PHONY: official-5.7 official-8.0 mariadb-10.7 mariadb-10.8 mariadb-10.9
official-5.7: ## docker official の MySQL 5.7 イメージでテスト
	@make IMAGE=mysql:$(MYSQL57_VERSION) test

official-8.0: ## docker official の MySQL 8.0 イメージでテスト
	@make IMAGE=mysql:$(MYSQL80_VERSION) test

mariadb-10.7: ## docker official の MariaDB 10.7 イメージでテスト
	@make IMAGE=mariadb:10.7.8 test

mariadb-10.8: ## docker official の MariaDB 10.8 イメージでテスト
	@make IMAGE=mariadb:10.8.7 test

mariadb-10.9: ## docker official の MariaDB 10.9 イメージでテスト
	@make IMAGE=mariadb:10.9.5 test

.PHONY: all-rep
define rep_target_template
.PHONY: rep-$(1) rep-gtid-$(1)
all-rep: rep-$(1) rep-gtid-$(1)

rep-$(1):
	@make IMAGE=mysql:$(MYSQL57_VERSION) COMPOSE_FILE=docker-compose-rep.yml BINLOG_FORMAT=$(1) test-rep

rep-gtid-$(1):
	@make IMAGE=mysql:$(MYSQL57_VERSION) COMPOSE_FILE=docker-compose-rep-gtid.yml BINLOG_FORMAT=$(1) test-rep

endef

$(foreach _fmt,$(BINLOG_FORMATS),$(eval $(call rep_target_template,$(_fmt)))): ## MySQL 5.7 イメージでレプリケーションが停止しないかのテスト

### docker hub のイメージのタグ一覧の表示と URL の表示
# docker hub からイメージのタグを取得する方法
# https://qiita.com/inajob/items/d4e13f85eb855e760e76
define _get-image-tags
	TOKEN=$$(curl -s "https://auth.docker.io/token?scope=repository:$(1):pull&service=registry.docker.io" | jq -r .token) && \
	curl -sLH "Authorization: Bearer $${TOKEN}" "https://registry-1.docker.io/v2/$(1)/tags/list"
endef

.PHONY: print-image-info
print-image-info:
	if [[ "$(TARGET_IMAGE)" =~ .*/.* ]]; then \
	  echo "URL: https://hub.docker.com/$(TARGET_IMAGE)/tags"; \
	  $(call _get-image-tags,$(TARGET_IMAGE)) | jq -r '.tags[] | select(. | contains("$(MYSQL80_VERSION)", "$(MYSQL57_VERSION)"))'; \
	else \
	  echo "URL: https://hub.docker.com/_/$(TARGET_IMAGE)/tags"; \
	  $(call _get-image-tags,library/$(TARGET_IMAGE)) | jq -r '.tags[] | select(. | contains("$(MYSQL80_VERSION)", "$(MYSQL57_VERSION)"))'; \
	fi

# 更新日時は非公式ながらできるが未実装
# ref. https://stackoverflow.com/questions/73616217/what-are-the-last-updated-last-pushed-and-tag-last-pushed-dates-of-docker-image
# curl https://hub.docker.com/v2/namespaces/library/repositories/mysql/tags/8.0.33 | jq .tag_last_pushed

clean:
	rm -rf $(RESULT_FILE)
