#!/bin/bash
trap 'kill $(jobs -p)' EXIT

CONF_PATH=`readlink -f ${1-/etc/mongo-watcher}`
pushd / >>/dev/null
echo "Looking for config in ${CONF_PATH}"

function pushStatsd {
    host="${STATSD_HOST:-127.0.0.1}"
    port="${STATSD_PORT:-8125}"

    payload="${1}:${2}|g"

    # Setup UDP socket with statsd server
    exec 3<> /dev/udp/$host/$port

    # Send data
    printf "$payload" >&3

    # Close UDP socket
    exec 3<&-
    exec 3>&-
}

function runWatch {
    file=$1
    statName=$2
    interval=$3
    dbName=$4

    while true; do
        value=$(mongo --quiet $dbName $file)
        echo "$statName -> $value"
        pushStatsd $statName $value
        sleep $interval
    done
}

for file in `find $CONF_PATH -type f -name '*.js'`; do

    statName=`echo $file | awk -F/ '{print $(NF)}' | sed 's/\.js$//'`
    interval=`echo $file | awk -F/ '{print $(NF-2)}'`
    dbName=`echo $file | awk -F/ '{print $(NF-1)}'`

    echo "Found $file: $statName every ${interval}s on $dbName"

    (runWatch $file $statName $interval $dbName) &
done

while true; do
    sleep 1000
done
