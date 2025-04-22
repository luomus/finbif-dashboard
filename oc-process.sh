#!/bin/bash

i="all"
f="template.yml"
e=".env"

while getopts ":f:e:i::" flag; do
  case $flag in
    f) f=${OPTARG} ;;
    e) e=${OPTARG} ;;
    i) i=${OPTARG} ;;
  esac
done

set -a

source ./$e

set +a

BRANCH=$(git symbolic-ref --short -q HEAD)
FINBIF_PRIVATE_API="unset"

if [ "$BRANCH" != "main" ]; then

  HOST=$HOST_DEV
  FINBIF_PRIVATE_API="beta"
  DB_PASSWORD=$DB_PASSWORD_DEV
  MEMORY=$MEMORY_DEV

fi

if [ $i = "volume" ]; then

  ITEM=".items[0]"

elif [ $i = "config" ]; then

  ITEM=".items[1]"

elif [ $i = "nginx-config" ]; then

  ITEM=".items[2]"

elif [ $i = "secrets" ]; then

  ITEM=".items[3]"

elif [ $i = "nginx-secrets" ]; then

  ITEM=".items[4]"

elif [ $i = "deploy-app" ]; then

  ITEM=".items[5]"

elif [ $i = "deploy-api" ]; then

  ITEM=".items[6]"

elif [ $i = "deploy-db" ]; then

  ITEM=".items[7]"

elif [ $i = "service-app" ]; then

  ITEM=".items[8]"

elif [ $i = "service-api" ]; then

  ITEM=".items[9]"

elif [ $i = "service-db" ]; then

  ITEM=".items[10]"

elif [ $i = "route" ]; then

  ITEM=".items[11]"

elif [ $i = "all" ]; then

  ITEM=""

else

  echo "Object not found"
  exit 1

fi

DB_PASSWORD=$(echo -n $DB_PASSWORD | base64)
NGINX_TEMPLATE=$(cat default.conf.template)
TLS_CRT=$(cat tls.crt | base64)
TLS_KEY=$(cat tls.key | base64)

echo "# $(oc project finbif-dashboard)"

oc process -f $f \
  -p BRANCH="$BRANCH" \
  -p HOST="$HOST" \
  -p FINBIF_PRIVATE_API="$FINBIF_PRIVATE_API" \
  -p DB_PASSWORD="$DB_PASSWORD" \
  -p SMTP_SERVER="$SMTP_SERVER" \
  -p SMTP_PORT="$SMTP_PORT" \
  -p ERROR_EMAIL_TO="$ERROR_EMAIL_TO" \
  -p ERROR_EMAIL_FROM="$ERROR_EMAIL_FROM" \
  -p MEMORY="$MEMORY" \
  -p NGINX_TEMPLATE="$NGINX_TEMPLATE" \
  -p TLS_CRT="$TLS_CRT" \
  -p TLS_KEY="$TLS_KEY" \
  | jq $ITEM
