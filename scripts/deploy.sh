#!/bin/bash

#1/stop docker container đang chạy và xóa image cũ
#2/export version app mới theo input
#3/build lại image mới
#4/cd vào thư mục chưa file docker compose và deploy

container_name="acerp-docker-frontend-1"
image_name="acerp/frappe-cust"

help_func()
{
   echo ""
   echo "Usage: $0 -f frappe_ver -o apps_json"
   echo "\t-f Description of frappe app version"
   echo "\t-o Description of erpnext app version & hrms app version"
   exit 1
}

while getopts f:o: flag
do
    case "${flag}" in
        f) frappe_ver=${OPTARG};;
        o) apps_json=${OPTARG};;
    esac
done

is_container_healthy()
{
    container_id="$(docker ps -aqf "name=${container_name}")"
    health_status="$(docker inspect --format='{{json .State.Status}}' "${container_id}")"
    if [ "${health_status}" != "running" ]; then
        echo "Stopped"
    else
        echo "Running"
    fi
}

is_images_healthy()
{ 
    health_status="$(docker images -q ${image_name}:latest 2> /dev/null)"
    if [ "${health_status}" != "" ]; then
        echo "Ok"
    else
        echo "Failed"
    fi
}

pre_process()
{
    cd "/home/deploy/workspace/acerp-prod/frappe_docker/build-docker"
    docker compose down
    wait

    result=$(is_container_healthy)
    if $result == "Stopped"; then 
        image_id="$(docker images --format="{{.Repository}} {{.ID}}" | grep "^${image_name} " | cut -d' ' -f2)"
        docker rmi $image_id
        echo "Ok"
    else
        echo "Failed"
    fi
}

rebuild_image()
{
    export APPS_JSON_BASE64=$(echo $apps_json | base64 -w 0)
    cd "/home/deploy/workspace/acerp-prod/frappe_docker"
    docker build --build-arg=FRAPPE_PATH=https://github.com/pandion-vn/AC_frappe --build-arg=FRAPPE_BRANCH=$frappe_ver --build-arg=APPS_JSON_BASE64=$APPS_JSON_BASE64 --tag=$image_name --file=images/custom/Containerfile .
}

launch_container()
{
    cd "/home/deploy/workspace/acerp-prod/frappe_docker/build-docker"
    docker compose up -d
    wait

    result=$(is_container_healthy)
    if $result == "Running"; then 
        echo "Ok"
    else
        echo "Failed"
    fi
}

main()
{
    if [ -z "$frappe_ver" ] || [ -z "$apps_json" ]; then
        echo "Some or all of the parameters are empty"
        help_func
    fi

    result=$(pre_process)
    if $result == "Ok"; then
        wait
        rebuild_image
        wait

        result=$(is_images_healthy)
        if $result == "Ok"; then
            wait
            launch_container
        fi
    fi
}

main "$@"
