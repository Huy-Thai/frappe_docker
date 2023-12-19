#!/bin/bash

#1/stop docker container đang chạy và xóa image cũ
#2/export version app mới theo input
#3/build lại image mới
#4/cd vào thư mục chưa file docker compose và deploy

folder_path="../build-docker"
container_name="acerp-docker-frontend-1"
container_id="$(docker ps -aqf "name=${container_name}")"
image_name="acerp/frappe-cust"
image_id="$(docker images --format="{{.Repository}} {{.ID}}" | grep "^${image_name} " | cut -d' ' -f2)"

help_func()
{
   echo ""
   echo "Usage: $0 -f frappe_ver -e erpnext_ver -h hrms_ver"
   echo "\t-f Description of frappe app version"
   echo "\t-e Description of erpnext app version"
   echo "\t-h Description of hrms app version"
   exit 1
}

while getopts f:e:h: flag
do
    case "${flag}" in
        f) frappe_ver=${OPTARG};;
        e) erpnext_ver=${OPTARG};;
        h) hrms_ver=${OPTARG};;
    esac
done

main()
{
    if [ -z "$frappe_ver" ] || [ -z "$erpnext_ver" ] || [ -z "$hrms_ver" ]; then
        echo "Some or all of the parameters are empty";
        help_func
    fi

    if [ -d $folder_path ]; then
        if pre_process; then
            wait
            rebuild_image
            # wait
            # launch_container
        fi
    else
        echo "-Directory does not exist"
        return 1
    fi
}

is_healthy()
{ 
    health_status="$(docker inspect --format='{{json .State.Status}}' "${container_id}")"
    if [ "${health_status}" != "running" ]; then
        echo "-Healthy Ok for Rebuild!"
    else
        return 1
    fi
}

pre_process()
{
    cd $compose_file_path
    docker compose down
    wait
    if is_healthy; then 
        docker rmi $image_id
        echo "-Step 1 Ok"
    else
        echo "-Step 1 Error, stop docker image failed!"
        return 1
    fi
}

rebuild_image()
{
    declare -A apps_json0=(
        [url]="https://github.com/pandion-vn/AC_erpnext"
        [branch]=${erpnext_ver}
    )
    declare -A apps_json1=(
        [url]="https://github.com/pandion-vn/AC_hrms"
        [branch]=${hrms_ver}
    )

    declare -n apps_json
    export APPS_JSON=$apps_json
    export APPS_JSON_BASE64=$(echo ${APPS_JSON} | base64 -w 0)
    env
    # docker build \
    #     --build-arg=FRAPPE_PATH=https://github.com/pandion-vn/AC_frappe \
    #     --build-arg=FRAPPE_BRANCH=$frappe_ver \
    #     --build-arg=APPS_JSON_BASE64=$APPS_JSON_BASE64 \
    #     --tag=$image_name \
    #     --file=../images/custom/Containerfile .
}

# launch_container() {
#     echo "runnn 2"
# }

main "$@"
