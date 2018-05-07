CREATE USER 'repl'@'%' IDENTIFIED BY 'replication';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';

