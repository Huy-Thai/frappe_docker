#!/bin/bash
container_name="acerp-docker-frontend-1"
image_name="acerp/frappe-cust"
container_status=-1
image_status=-1

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
    if "${health_status}" != "running"
    then
        container_status=1
    else
        container_status=0
    fi
}

is_images_healthy()
{ 
    health_status="$(docker images -q ${image_name}:latest 2> /dev/null)"
    if "${health_status}" != ""
    then
        image_status=1
    else
        image_status=0
    fi
}

pre_process()
{
    cd "/home/deploy/workspace/acerp-prod/frappe_docker/build-docker"
    docker compose down
    wait
    is_container_healthy
    if "$container_status" == 1
    then 
        image_id="$(docker images --format="{{.Repository}} {{.ID}}" | grep "^${image_name} " | cut -d' ' -f2)"
        docker rmi $image_id
    else
        exit 1
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
    is_container_healthy
    if "$container_status" == 0
    then
        echo "Deploy Successful"
    else
        echo "Deploy Failed"
    fi
}

main()
{
    if [ -z "$frappe_ver" ] || [ -z "$apps_json" ]
    then
        echo "Some or all of the parameters are empty"
        help_func
    fi
    
    pre_process
    wait
    rebuild_image
    wait
    is_images_healthy
    if "$image_status" == 1
    then
        wait
        launch_container
    fi
}

main "$@"
