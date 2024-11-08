#!/bin/bash
# Generating RonDB clusters of variable sizes with docker compose
# Copyright (c) 2022, 2023 Hopsworks AB and/or its affiliates.

# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

################
### Defaults ###
################

RONDB_SIZE=small
RONDB_VERSION=22.10.6
RONDB_IMAGE_NAME=rondb
REPLICATION_FACTOR=2
RONDB_TARBALL_PATH=
RONDB_TARBALL_URL=
NUM_MYSQL_SERVERS=2
SQL_INIT_SCRIPT_CLI_DIR=
BENCHMARK=
VOLUMES_IN_LOCAL_DIR=

function print_usage() {
    cat <<EOF
Usage: $0    
    [-h     --help                                                  ]
    [-v     --rondb-version                                 <string>
                Default: $RONDB_VERSION                             ]
    [-in    --rondb-image-name                              <string>
                Default: $RONDB_IMAGE_NAME                          ]
    [-tp    --rondb-tarball-path                            <string>
                Build Dockerfile with a local tarball           
                Default: pull image from Dockerhub                  ]
    [-tu    --rondb-tarball-url                             <string>
                Build Dockerfile with a remote tarball
                Default: pull image from Dockerhub                  ]
    [-b     --run-benchmark                                 <string>
                Options: <sysbench_single, sysbench_multi,
                    dbt2_single>                                    ]
    [-b     --size                                          <string>
                Options: <mini, small, medium, large, xlarge>
                Default: $RONDB_SIZE

                The size of the machine that you are running 
                this script from:
                
                - mini: at least 8GB of memory and a few CPUs
                - small: at least 16 GB of memory and 4 CPU cores
                - medium: at least 32 GB of memory and 8 CPU cores
                - large: at least 32 GB of memory and 16 CPU cores
                - xlarge: at least 64 GB of memory and 32 CPU cores ]
    [-sql    --sql-init-scripts-dir                     <string>
                Directory with SQL scripts that will be read
                in entrypoint with root privileges.                 ]
    [-lv    --volumes-in-local-dir                                  
                Replace volumes with local directories              ]
    [-d     --detached                                              ]
    [-su    --suffix
                The suffix to add to the project name. Add a suffix
                if you want to run several clusters in parallel.    ]
EOF
}

while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
    -h | --help)
        print_usage
        exit 0
        ;;
    -v | --rondb-version)
        RONDB_VERSION="$2"
        shift # past argument
        shift # past value
        ;;
    -in | --rondb-image-name)
        RONDB_IMAGE_NAME="$2"
        shift # past argument
        shift # past value
        ;;
    -s | --size)
        RONDB_SIZE="$2"
        shift # past argument
        shift # past value
        ;;
    -b | --run-benchmark)
        BENCHMARK="$2"
        shift # past argument
        shift # past value
        ;;
    -tp | --rondb-tarball-path)
        RONDB_TARBALL_PATH="$2"
        shift # past argument
        shift # past value
        ;;
    -tu | --rondb-tarball-url)
        RONDB_TARBALL_URL="$2"
        shift # past argument
        shift # past value
        ;;
    -lv | --volumes-in-local-dir)
        VOLUMES_IN_LOCAL_DIR="--volumes-in-local-dir"
        shift # past argument
        ;;
    -d | --detached)
        DETACHED="-d"
        shift # past argument
        ;;
    -su | --suffix)
        USER_SUFFIX="$2"
        shift # past argument
        shift # past value
        ;;
    *)                     # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        shift              # past argument
        ;;
    esac
done

set -- "${POSITIONAL[@]}" # restore unknown options
if [[ -n $1 ]]; then
    echo "##################" >&2
    echo "Illegal arguments: $*" >&2
    echo "##################" >&2
    echo
    print_usage
    exit 1
fi

if [ -n "$RONDB_TARBALL_PATH" ] && [ -n "$RONDB_TARBALL_URL" ]; then
    echo "Cannot specify both a RonDB tarball path and url" >&2
    print_usage
    exit 1
fi

if [ "$BENCHMARK" != "" ] &&
    [ "$BENCHMARK" != "sysbench_single" ] &&
    [ "$BENCHMARK" != "sysbench_multi" ] &&
    [ "$BENCHMARK" != "dbt2_single" ]; then
    echo "Benchmark has to be one of <sysbench_single, sysbench_multi, dbt2_single>" >&2
    print_usage
    exit 1
fi

if [ "$RONDB_SIZE" != "small" ] &&
    [ "$RONDB_SIZE" != "mini" ] &&
    [ "$RONDB_SIZE" != "medium" ] &&
    [ "$RONDB_SIZE" != "large" ] &&
    [ "$RONDB_SIZE" != "xlarge" ]; then
    echo "Size has to be one of <mini, small, medium, large, xlarge>" >&2
    print_usage
    exit 1
fi

if [ "$RONDB_SIZE" = "mini" ]; then
    REPLICATION_FACTOR=1
    NUM_MYSQL_SERVERS=1
fi

EXEC_CMD="./build_run_docker.sh"
EXEC_CMD="$EXEC_CMD --rondb-version $RONDB_VERSION"
EXEC_CMD="$EXEC_CMD --rondb-image-name $RONDB_IMAGE_NAME"

if [ -n "$RONDB_TARBALL_PATH" ]; then
    EXEC_CMD="$EXEC_CMD --rondb-tarball-path $RONDB_TARBALL_PATH"
elif [ -n "$RONDB_TARBALL_URL" ]; then
    EXEC_CMD="$EXEC_CMD --rondb-tarball-url $RONDB_TARBALL_URL"
fi

EXEC_CMD="$EXEC_CMD --size $RONDB_SIZE"
EXEC_CMD="$EXEC_CMD $VOLUMES_IN_LOCAL_DIR $DETACHED"
EXEC_CMD="$EXEC_CMD --num-mgm-nodes 1"
EXEC_CMD="$EXEC_CMD --node-groups 1"
EXEC_CMD="$EXEC_CMD --replication-factor $REPLICATION_FACTOR"
EXEC_CMD="$EXEC_CMD --num-mysql-nodes $NUM_MYSQL_SERVERS"
EXEC_CMD="$EXEC_CMD --num-rest-api-nodes 1"
EXEC_CMD="$EXEC_CMD --num-benchmarking-nodes 1"

if [ -n "$SQL_INIT_SCRIPT_CLI_DIR" ]; then
    EXEC_CMD="$EXEC_CMD --sql-init-scripts-dir $SQL_INIT_SCRIPT_CLI_DIR"
fi

if [ "$BENCHMARK" != "" ]; then
    EXEC_CMD="$EXEC_CMD --run-benchmark $BENCHMARK"
fi

if [ "$USER_SUFFIX" != "" ]; then
    EXEC_CMD="$EXEC_CMD --suffix $USER_SUFFIX"
fi

echo "Executing command: $EXEC_CMD"
echo
eval $EXEC_CMD
