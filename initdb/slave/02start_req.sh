#!/bin/bash

for i in {1..60};do 
  mysql -hmaster -urepl -preplication -e "select version();" && break
  sleep 1
done

mysql -uroot -e "start slave"
