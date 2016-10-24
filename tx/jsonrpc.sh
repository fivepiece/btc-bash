#!/bin/bash

export commonjson='"jsonrpc":"1.0" "id":"curltest"'

json_val_sep()
{
    printf "%s,\n" ${@}
}

json_name_sep()
{
    local -a arr=( ${@} )
    printf '"%s": %s\n' ${1} ${arr[@]:1}
}

json_object_make()
{
    json_wrap_make '{' '}' ${@}
}

json_array_make()
{
    json_wrap_make '[' ']' ${@} 
}

json_wrap_make()
{
    local wa="${1}" wi="${2}"
    shift 2
    local -a arr=( ${@} )
    arr=( ${arr[@]//,/} )

    printf "${wa}%s\n" "$( json_val_sep ${arr[@]::$((${#arr[@]}-1))} )"
    printf "%s${wi}\n" ${arr[-1]}
}

rpc_curl()
{
    curl -# --user test_rpcuser_btc:test_rpcpass_btc --data-binary @"${1}" -H 'content-type: text/plain;' http://127.3.0.1:18332/
}

json_fundrawtransaction()
{
    local -a options params header

    readarray -t options < <( json_object_make "\"changeAddress\":\"${2}\"" '"changePosition":0' )
    readarray -t params < <( json_array_make "\"${1}\"" ${options[@]} )
    json_object_make '"jsonrpc":"1.0"' '"id":"curltest"' '"method":"fundrawtransaction"' "\"params\":${params[@]}"
}

json_signrawtransaction()
{
    local -a prevtxs privatekeys sighash
}
