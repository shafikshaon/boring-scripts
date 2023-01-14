#!/bin/bash

echo "Enter database name:"
read dbname
echo "Enter username:"
read username
echo "Enter backup file name with path:"
read filename

psql -U $username -W $dbname <$filename
