#!/bin/bash

script_ser_num ()
{
    local -u sernum

    read sernum < <( BC_ENV_ARGS='-q' bc 99_bitcoin.bc 99_hash.bc <<<\
        "ibase=A; n=${1}; \
        obase=16; ibase=16; \
        ser_num(n);" )

    read sernum < <( revbyteorder "${sernum}" )
    data_pushdata "${sernum}"
}
