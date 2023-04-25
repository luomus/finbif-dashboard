#!/bin/bash

i="all"

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
FINBIF_PRIVATE_API="dev"

fi

if [ $i = "build" ]; then

ITEM=".items[0]"

elif [ $i = "image" ]; then

ITEM=".items[1]"

elif [ $i = "deploy-app" ]; then

ITEM=".items[2]"

elif [ $i = "deploy-api" ]; then

ITEM=".items[3]"

elif [ $i = "service-app" ]; then

ITEM=".items[4]"

elif [ $i = "service-api" ]; then

ITEM=".items[5]"

elif [ $i = "route" ]; then

ITEM=".items[6]"

elif [ $i = "job" ]; then

ITEM=".items[7]"

else

  ITEM=""

fi

oc process -f $f \
-p BRANCH=$BRANCH \
-p HOST=$HOST \
-p FINBIF_PRIVATE_API=$FINBIF_PRIVATE_API \
| jq $ITEM
