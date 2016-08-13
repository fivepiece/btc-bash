#!/bin/bash



spendlost ()
{
    declare -i i=-1
    declare -a inputs
    output="mtapKMqaqPD9TmXnZpSR5qZQNQ3Ay3xX9N"

    rm ./shardtx

    while read -ers line; do
        
        i="$(( ${i} + 1))"

        if [[ "${line}" =~ "txid" ]]; then

            thistxid="$( core_json_rhs "${line}" )"
            thistxid="in=${thistxid}"
        fi

        if [[ "${line}" =~ "vout" ]]; then

            thisvout="$( core_json_rhs "${line}" )"
            thisvout="${thistxid}:${thisvout}"
        fi

        inputs[${i}]="${thisvout}"
        if (( (${i}+1) % 1000 == 0 )); then

            ustx="$(testnet-tx -create "${inputs[@]}" outaddr=7:${output})"
            eval "echo ${ustx} | testnet-cli -stdin signrawtransaction | grep hex | tr -d ' \",' | cut -d':' -f2 >> shardtx"
            i=-1
            inputs=()

        fi

        echo "i : ${i}"
        echo "# : ${#inputs[@]}"

    done <./losttx

    echo "i : ${i}"
    echo "# : ${#inputs[@]}"

    read amount < <( BC_ENV_ARGS='-q' bc<<<"scale=8; ${i}*0.007" )
    ustx="$(testnet-tx -create "${inputs[@]}" outaddr=${amount}:${output})"
    eval "echo ${ustx} | testnet-cli -stdin signrawtransaction | grep hex | tr -d ' \",' | cut -d':' -f2 >> shardtx"
}
