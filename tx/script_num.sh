#!/bin/bash

script_is_bignum()
{
    if [[ "${1}" =~ [^0-9-] ]]; then

        echo '0'
        return
    fi

    echo "$(( $(( ${1} > -$((2**31)) )) && $(( ${1} < $((2**31)) ))  ))"
}

script_is_opnum()
{
    if [[ "${1}" =~ [^0-9-] ]]; then

        echo '0'
        return
    fi

    echo "$(( $(( ${1} >= -1 )) && $(( ${1} <= 16 ))  ))"
}

script_ser_num ()
{
    local -u sernum is_opnum

    read is_opnum < <( script_is_opnum "${1}" )
    if (( "${is_opnum}" )); then

        echo "0x${op_num[${1}]}"
        return
    fi

    read sernum < <( BC_ENV_ARGS='-q' bc 99_bitcoin.bc 99_hash.bc <<<\
        "ibase=A; n=${1}; \
        obase=16; ibase=16; \
        ser_num(n);" )

    read sernum < <( revbyteorder "${sernum}" )
    data_pushdata "${sernum}"
}


tx_ser_int ()
{
    if (( "${1}" > (2**32)-1 )); then

        echo "error: tx_ser_int: int > 2^32-1" >&2
        return
    fi

    local -u serint

    read serint < <( bip32_ser32 "${1}" )
    read serint < <( revbyteorder "${serint}" )

    echo "${serint}"
}
