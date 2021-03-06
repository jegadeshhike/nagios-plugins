#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2015-11-11 19:49:15 +0000 (Wed, 11 Nov 2015)
#
#  https://github.com/harisekhon/nagios-plugins
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback to help improve or steer this or other code I publish
#
#  https://www.linkedin.com/in/harisekhon
#

set -euo pipefail
[ -n "${DEBUG:-}" ] && set -x
srcdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd "$srcdir/..";

. ./tests/utils.sh

section "Z o o K e e p e r"

export ZOOKEEPER_VERSIONS="${@:-${ZOOKEEPER_VERSIONS:-latest 3.3 3.4}}"

ZOOKEEPER_HOST="${DOCKER_HOST:-${ZOOKEEPER_HOST:-${HOST:-localhost}}}"
ZOOKEEPER_HOST="${ZOOKEEPER_HOST##*/}"
ZOOKEEPER_HOST="${ZOOKEEPER_HOST%%:*}"
export ZOOKEEPER_HOST
export ZOOKEEPER_PORT_DEFAULT=2181
#export ZOOKEEPER_PORTS="$ZOOKEEPER_PORT_DEFAULT 3181 4181"

export MNTDIR="/pl"

check_docker_available

trap_debug_env zookeeper

docker_exec(){
    echo "docker-compose exec '$DOCKER_SERVICE' $MNTDIR/$@"
    docker-compose exec "$DOCKER_SERVICE" $MNTDIR/$@
}

startupwait 10

test_zookeeper(){
    local version="$1"
    section2 "Setting up ZooKeeper $version test container"
    #launch_container "$DOCKER_IMAGE:$version" "$DOCKER_CONTAINER" $ZOOKEEPER_PORTS
    #docker cp "$DOCKER_CONTAINER":/zookeeper/conf/zoo.cfg .
    #hr
    #echo "Setting up nagios-plugins test container with zkperl library"
    #local DOCKER_OPTS="--link $DOCKER_CONTAINER:zookeeper -v $PWD:$MNTDIR"
    #local DOCKER_CMD="tail -f /dev/null"
    #launch_container "$DOCKER_IMAGE2" "$DOCKER_CONTAINER2"
    #docker cp zoo.cfg "$DOCKER_CONTAINER2":"$MNTDIR/"
    VERSION="$version" docker-compose up -d
    export ZOOKEEPER_PORT="`docker-compose port "$DOCKER_SERVICE" "$ZOOKEEPER_PORT_DEFAULT" | sed 's/.*://'`"
    #local DOCKER_CONTAINER="$(docker-compose ps | sed -n '3s/ .*/p')"
    when_ports_available "$startupwait" "$ZOOKEEPER_HOST" "$ZOOKEEPER_PORT"
    if [ -n "${NOTESTS:-}" ]; then
        exit 0
    fi
    expected_version="$version"
    if [ "$expected_version" = "latest" ]; then
        expected_version=".*"
    fi
    hr
    echo "./check_zookeeper_version.py -e "$expected_version""
    ./check_zookeeper_version.py -e "$expected_version"
    hr
    if [ "${version:0:3}" = "3.3" ]; then
        echo "$perl -T ./check_zookeeper.pl -s -w 50 -c 100 -v || :"
        $perl -T ./check_zookeeper.pl -s -w 50 -c 100 -v || :
    else
        echo "$perl -T ./check_zookeeper.pl -s -w 50 -c 100 -v"
        $perl -T ./check_zookeeper.pl -s -w 50 -c 100 -v
    fi
    hr
    echo "docker_exec check_zookeeper_config.pl -H localhost -C '/zookeeper/conf/zoo.cfg' -v"
    docker_exec check_zookeeper_config.pl -H localhost -C "/zookeeper/conf/zoo.cfg" -v
    hr
    echo "docker_exec check_zookeeper_child_znodes.pl -H localhost -z / --no-ephemeral-check -v"
    docker_exec check_zookeeper_child_znodes.pl -H localhost -z / --no-ephemeral-check -v
    hr
    echo "docker_exec check_zookeeper_znode.pl -H localhost -z / -v -n --child-znodes"
    docker_exec check_zookeeper_znode.pl -H localhost -z / -v -n --child-znodes
    hr

    #delete_container "$DOCKER_CONTAINER"
    docker-compose down
}

run_test_versions ZooKeeper
