#!/bin/bash

op_num=( "00" "51" "52" "53" "54" "55" "56" "57" "58" "59" "5A" "5B" "5C" "5D" "5E" "5F" "60" )
ser_data=( "size" "data" )

script_p2pk=( "size" "pubkey" "CHECKSIG" )
script_p2pkh=( "DUP" "HASH160" "0x14" "pubkeyhash" "EQUALVERIFY" "CHECKSIG" )
script_p2wpkh=( "0x00" "0x14" "pubkeyhash" )
script_mofn=( "m" "pubkeys" "n" "CHECKMULTISIG" )
script_p2wsh=( "0x00" "0x20" "scripthash" )
script_p2sh=( "HASH160" "0x14" "scripthash" "EQUAL" )

serdata() {

    local -a tmparr
    local -a data
    read -r -a data <<<"${1^^}"
    local size

    local j
    j=0
    for (( i=0; i<${#data[@]}; i++ ))
    do
        read size < <( datasize ${#data[${i}]} )
        tmparr[${j}]="0x${size}"
        tmparr[$(( ${j}+1 ))]="0x${data[${i}]}"
        j=$(( ${j}+2 ))
    done

    echo "${tmparr[@]}"
}

serscript() {

    local -a script
    read -r -a script <<<"${@^^}"

    local ser
    ser=""
    
    for (( i=0; i<${#script[@]}; i++ ))
    do
        elem="${script[${i}]}"
        if [[ "${elem}" =~ "0X" ]]
        then
            ser+="${elem/0X/}"
        else
            ser+="${opcodes[${elem}]}"
        fi
    done

    echo "${ser^^}"
}

datasize() {
    local len size order revsize

    if [[ "${1}" == "" ]]
    then
        read len
    else
        len="${1}"
    fi
    read size < <( BC_ENV_ARGS='-q' bc 99_bitcoin.bc <<< \
        "size=(${len}/2); \
        obase=16; ibase=16; \
        compsize(size);" );

    order="${size:0:2}"
    read revsize < <( revbyteorder "${size:2}" )
    
    echo "${order}""${size}"
}
