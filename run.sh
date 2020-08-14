#!/bin/bash 

#build image
tag="2.2.0"
project="ops.atomhike.com/ops/kafka"

docker build -t $project:$tag .

if [ $? -eq 0 ];then
docker push $project:$tag
fi
