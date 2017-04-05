## これは何か

MySQL 5.7.17 (5.7.16 でも発生するので 5.7.17 に限るわけではない模様) で NULL ではないカラムなのに、INSERT や UPDATE で `Column 'addr' cannot be null` と言うようなエラーが出てしまう現象が発生した。  
これはエラーを再現する最小限の sql と docker-compose.yml になる

docker-compose を使う必要は必ずしもない。

## 再現方法

- `LOAD.sql` を適切な箇所に配置する（デフォルトでは `/work/LOAD.sql`）
- `mysql <error.sql` を実行する

### 実行例

付属の docker-compose を利用

```console
$ # コンテナの起動
$ docker-compose up -d
Creating network "mysqlcolumnnullerror_default" with the default driver
Creating mysqlcolumnnullerror_mysqld_1
$ # 起動の確認
$ docker-compose ps
            Name                          Command             State    Ports
------------------------------------------------------------------------------
mysqlcolumnnullerror_mysqld_1   docker-entrypoint.sh mysqld   Up      3306/tcp
$ # コンテナに入って作業
$ docker exec -it mysqlcolumnnullerror_mysqld_1 bash
root@1fb43a1209d2:/# # エラーが発生する sql の実行（mysql に入って作業しても再現できる）
root@1fb43a1209d2:/# mysql </work/error.sql
@@session.sql_mode
ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION
*************************** 1. row ***************************
  Level: Warning
   Code: 1263
Message: Column set to default value; NULL supplied to NOT NULL column 'addr' at row 1
*************************** 1. row ***************************
  id: 1
addr:
ERROR 1048 (23000) at line 17: Column 'addr' cannot be null
root@1fb43a1209d2:/# # 別セッションでの確認とセッションが別になると問題ないことの確認
root@1fb43a1209d2:/# mysql bar -e 'SELECT * FROM ip\G;UPDATE ip SET addr="192.168.0.1" WHERE id = 1;SHOW WARNINGS;SELECT * FROM ip\G'
*************************** 1. row ***************************
  id: 1
addr:
*************************** 1. row ***************************
  id: 1
addr: 192.168.0.1
```
