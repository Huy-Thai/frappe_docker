#!/bin/bash

#1/stop docker container đang chạy và xóa image cũ
#2/export version app mới theo input
#3/build lại image mới
#4/cd vào thư mục chưa file docker compose và deploy

compose_file_path="../build-docker"
if [ -d $compose_file_path ]
then
    cd $compose_file_path
    echo "Inside folder"
else
    echo "Directory does not exist"
fi

