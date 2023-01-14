#!/bin/bash

echo "Enter database name:"
read dbname
echo "Enter username:"
read username

now=$(date +"%m_%d_%Y")

pg_dump -U $username -W -F t $dbname >$dbname$now.tar
