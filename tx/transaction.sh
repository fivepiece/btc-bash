#!/bin/bash

script_types=( 'p2pkey' 'p2pkh' 'mofn' 'p2wpkh' \
               'p2sh_p2pkey' 'p2sh_p2pkh' 'p2sh_mofn' 'p2sh_p2wpkh' \
               'p2wsh_p2pkey' 'p2wsh_p2pkh' 'p2wsh_mofn' \
               'p2sh_p2wsh_p2pkey' 'p2sh_p2wsh_p2pkh' 'p2sh_p2wsh_mofn' )

declare -a kc_addrs kc_pubks kc_prvks
declare -i kc_ptr


keychain_populate ()
{
    mapfile -t kc_addrs <"./addrs.list"
    mapfile -t kc_pubks <"./pubkeys.list"
    mapfile -t kc_prvks <"./privkeys.list"
    kc_pointer=0

    if (( "${#kc_addrs[@]}" != "${#kc_pubks[@]}" )) || \
        (( "${#kc_pubks[@]}" != "${#kc_prvks[@]}" )); then

        unset kc_addrs kc_pubks kc_prvks kc_pointer
        echo "Error in keystore: list size mismatch"
    fi
}


keychain_get_address ()
{
    echo "${kc_addrs[${kc_ptr}]}"
    kc_ptr="$(( ${kc_ptr} + 1 ))"
}


keychain_get_pubkey ()
{
    echo "${kc_pubks[${kc_ptr}]}"
    kc_ptr="$(( ${kc_ptr} + 1 ))"
}


keychain_get_privkey ()
{
    echo "${kc_prvks[${kc_ptr}]}"
    kc_ptr="$(( ${kc_ptr} + 1 ))"
}



tx_mkout_serialize ()
{
    local amount="${1}" asmscript="${2}" nest="${3}"
    local -u seramt serscript
    local scriptsize

    if [[ "${nest}" =~ "p2wsh" ]]; then

        tx_mkout_p2wsh "${amount}" "${asmscript}" "${nest//p2wsh/}"
        return
    fi

    if [[ "${nest}" =~ "p2sh" ]]; then

        tx_mkout_p2sh "${amount}" "${asmscript}" ""
        return
    fi

    read seramt < <( dec2amount "${amount}" )
    read serscript < <( script_serialize "${asmscript}" )
    read scriptsize < <( data_compsize "${#serscript}" )
#    read serpush < <( data_pushdata "${serscript}" )
#    read serpush < <( script_serialize "${serpush}" )

#    echo "${seramt}${serpush}${serscript}"
    echo "${seramt}${scriptsize}${serscript}"
}

tx_mkout_p2pkey ()
{
    local amount="${1}" pubkey="${2}"
    local nest="${3}" script

    read script < <( spk_pay2pubkey "${pubkey}" )
    tx_mkout_serialize "${amount}" "${script}" "${nest}"
}


tx_mkout_p2pkh ()
{
    local amount="${1}" addr="${2}"
    local nest="${3}" script

    read script < <( spk_pay2pkhash "${addr}" )
    tx_mkout_serialize "${amount}" "${script}" "${nest}"
}


tx_mkout_mofn ()
{
    local amount="${1}" pubkeys="${3}"
    local -i m="${2}"
    local nest="${3}" script

    read script < <( spk_pay2mofn "${m}" "${pubkeys}" )
    tx_mkout_serialize "${amount}" "${script}" "${nest}"
}


tx_mkout_p2wpkh ()
{
    local amount="${1}" addr="${2}"
    local nest="${3//p2wsh/}" script

    read script < <( spk_pay2wpkhash "${addr}" )
    tx_mkout_serialize "${amount}" "${script}" "${nest}"
}


tx_mkout_p2wsh ()
{
    local amount="${1}" asmscript="${2}"
    local nest="${3//p2wsh/}" script

    read script < <( spk_pay2wshash "${asmscript}" )
    tx_mkout_serialize "${amount}" "${script}" "${nest}"
}


tx_mkout_p2sh ()
{
    local amount="${1}" asmscript="${2}"
    local script

    read script < <( spk_pay2shash "${asmscript}" )
    tx_mkout_serialize "${amount}" "${script}" ""
}


# in : previous txid, previous output index, sequence number to apply, script to use
tx_mkin_serialize ()
{
    local -u prevtx="${1}" serpidx serseq serscript
    local -i previdx="${2}" sequence="${3}"
    local asmscript="${4}" scriptsize

    read prevtx < <( revbyteorder "${prevtx}" )

    read serpidx < <( tx_ser_int "${previdx}" )

    read serseq < <( tx_ser_int "${sequence}" )

    read serscript < <( script_serialize "${asmscript}" )
    read scriptsize < <( data_compsize "${#serscript}" )

    echo -e "${prevtx}${serpidx}\n${scriptsize}${serscript}\n${serseq}"
}


tx_input_script ()
{
    local -u script

    script="${1:72}"
    script="${script::-8}"

    echo "${script}"
}


tx_bip141_iswitprog ()
{
    local -u scriptpk
    local -i spklen pushcode

    read scriptpk < <( tx_input_script "${1}" )

    spklen="${#scriptpk}"

    if (( "${spklen}" < 6 )) || (( "${spklen}" > 86 )); then

        echo "0"
    fi

    read pushcode < <( BC_ENV_ARGS='-q' bc <<<"${scriptpk:2:2}" )

    if (( "${pushcode}" < 0 )) || (( "${pushcode}" > 16 )); then

        echo "0"
    fi

    echo "1"
}


tx_bip141_serwitness ()
{
    local -au stack serstack
    local -u sersize
    stack=( ${1} )

    read sersize < <( data_compsize "$(( ${#stack[@]}*2 ))" )

    for (( i=0; i<"${#stack[@]}"; i++ )); do

        read itemlen < <( data_compsize "${#stack[${i}]}" )
        serstack[${i}]="${itemlen}${stack[${i}]}"
    done

#    printf "%s\n" "${sersize}" ${serstack[@]}
    echo -n "${sersize}"
    for (( i=0; i<"${#serstack[@]}"; i++ )); do

        echo -n "${serstack[${i}]}"
    done
}


tx_build ()
{
    local -u version swmarker swflag vins vouts nlocktime
    local -au inputs outputs witness witsigs

    read version < <( tx_ser_int "${1}" )

    if [[ "${2,,}" != "" ]]; then

        swmarker="00"
        swflag="01"
    fi

    inputs=( ${3} )
    outputs=( ${4} )
    witsigs=( ${6} )

    read vins < <( data_compsize "$(( ${#inputs}*2 ))" )
    read vouts < <( data_compsize "$(( ${#outputs}*2 ))" )

    if [[ "${swflag}" == "01" ]]; then

        local -i j=0
        for (( i=0; i<"${#inputs[@]}"; i++ )); do

            read iswitness < <( tx_bip141_iswitprog "${inputs[${i}]}" )

            if (( "${iswitness}" )); then

                # 010100 - dummy witness
                witness[${i}]="${witsigs[${j}]:-010100}"
                j="$(( ${j}+1 ))"
            else
                witness[${i}]="00"
            fi
        done
    fi

    read nlocktime < <( tx_ser_int "${5}" )

    echo "${version}"
    if [[ "${swflag}" == "01" ]]; then

        echo "${swmarker}"
        echo "${swflag}"
    fi
    data_compsize "$(( (${#inputs[@]}*2)/3 ))"
    printf "%s\n" ${inputs[@]}
    data_compsize "$(( ${#outputs[@]}*2 ))"
    printf "%s\n" ${outputs[@]}
    if [[ "${swflag}" == "01" ]]; then

        printf "%s\n" ${witness[@]}
    fi
    echo "${nlocktime}"
}
