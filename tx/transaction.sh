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
