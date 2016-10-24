#!/bin/bash

# op_num=( "00" "51" "52" "53" "54" "55" "56" "57" "58" "59" "5A" "5B" "5C" "5D" "5E" "5F" "60" )
ser_data=( "size" "data" )

script_p2pk=( "size" "pubkey" "CHECKSIG" )                                    #1
script_p2pkh=( "DUP" "HASH160" "0x14" "pubkeyhash" "EQUALVERIFY" "CHECKSIG" ) #2
script_p2wpkh=( "0x00" "0x14" "pubkeyhash" )                                  #3
script_mofn=( "m" "pubkeys" "n" "CHECKMULTISIG" )                             #4
script_p2wsh=( "0x00" "0x20" "scripthash" )                                   #10
script_p2sh=( "HASH160" "0x14" "scripthash" "EQUAL" )                         #200

# bip112
script_ced=( "IF" "mofn" "ELSE" "countdown" "CHECKSEQUENCEVERIFY" "DROP" "pubkey" "CHECKSIGVERIFY" "ENDIF" )
script_revc=( "HASH160" "revokehash" "EQUAL" "IF" "pubkey" "ELSE" "countdown" "CHECKSEQUENCEVERIFY" "DROP" "pubkey" "ENDIF" "CHECKSIG" )
script_htlc=( "HASH160" "DUP" "rhash" "EQUAL" "IF" "countdown" "CHECKSEQUENCEVERIFY" "2DROP" "pubkey" "ELSE" "crhash" "EQUAL" "NOTIF" "deadline"  "CHECKLOCKTIMEVERIFY" "DROP" "ENDIF" "pubkey" "ENDIF" "CHECKSIG" )

minspend=49.999
# maxspend=21

getinputs(){
    
readarray inputs < <( ${clientname}-cli listunspent | grep "txid\|vout\|address\|scriptPubKey\|redeemScript\|amount\|}\|{" )

    echo -n '[' > prevtxs.json
    echo -n '[' > privatekeys.json
    echo -n "" > prevtxs.in

    for (( i=0, j=0; i<${#inputs[@]}; i++ ))
    do
        field="${inputs[${i}]}"
        case "${field}" in
        
            *{*)
                if (( ${i} != 0 ))
                then
                    echo -e ",\n{" >> prevtxs.json
                else
                    echo "{" >> prevtxs.json
                fi
                ;;&

            *txid*)
                echo -en "\t${field// }" >> prevtxs.json
            
                field="${field/    \"txid\": \"/in=}"
                echo -n "${field/\",$'\n'/:}" >> prevtxs.in
                ;;&

            *vout*)
                echo -en "\t${field// }" >> prevtxs.json

                field="${field/    \"vout\": /}"
                echo -n "${field/,$'\n'/:}" >> prevtxs.in
                ;;&
        
            *address*)
                field="${field//\"address\": \"}"
                field="${field//\",}"
            
                read key < <( ${clientname}-cli dumpprivkey "${field}" )
                if (( ${j} == 0 ))
                then
                    echo -en "\n\t\"${key}\"" >> privatekeys.json
                    j=1
                else
                    echo -en ",\n\t\"${key}\"" >> privatekeys.json
                fi
                ;;&

            *script*)
                echo -en "\t${field// }" >> prevtxs.json
                ;;&
        
            *amount*)
                field="${field// }"
                echo -en "\t${field//,}}" >> prevtxs.json

                field="${field//\"amount\":}"
                echo -n "${field//,/}" >> prevtxs.in
                ;;
        esac
    done

    echo -e "]\n" >> prevtxs.json
    echo -e "\n]" >> privatekeys.json
}

datasize() {

    local len
    local size
    local order

    if [[ "${1}" == "" ]]
    then
        read len
    else
        len="${1}"
    fi
    read size < <( BC_ENV_ARGS='-q' bc 99_bitcoin.bc <<<"size=(${len}/2); \
                    obase=16; ibase=16; \
                    compsize(size);" )

    if (( $((16#${size})) > 252 ))
    then
        order="${size:0:2}"
        read size < <( revbyteorder "${size:2}"; )
    fi

    echo "${order}""${size}"
}

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

addr2pubkey() {

    local pubkey
    read pubkey < <( ${clientname}-cli validateaddress "${1}" | grep pubkey )
    pubkey="${pubkey#*:}"
    pubkey="${pubkey//[\",]/}"

    echo "${pubkey}"
}

pay2pubkey() {

    local -a tmpscript
    local size

    tmpscript=( "${script_p2pk[@]}" )
    read size < <( datasize "${#1}" )

    tmpscript[0]="0x${size}"
    tmpscript[1]="0x${1}"

    echo "${tmpscript[@]}"
}

addr2hash160() {

    local pkhash
    read pkhash < <( base58dec "${1}" )
    pkhash="${pkhash:2:40}"

    echo "${pkhash}"
}

pay2pkhash() {

    local -a tmpscript
    local pkhash

    tmpscript=( "${script_p2pkh[@]}" )
    read pkhash < <( addr2hash160 "${1}" )

    tmpscript[3]="0x${pkhash}"

    echo "${tmpscript[@]}"
}

pay2mofn() {

    local -a pubkeys
    local -a tmpscript
    
    read -r -a pubkeys < <( serdata "${2}" )
    tmpscript=( "${script_mofn[@]}" )

    tmpscript[0]="0x${op_num[${1}]}"
    tmpscript[1]="${pubkeys[@]}"
    tmpscript[2]="0x${op_num[$(( ${#pubkeys[@]} / 2 ))]}"

    echo "${tmpscript[@]}"
}

pay2shash() {

    local -a script
    local scripthash
    local -a tmpscript

    read -r -a script <<<"${1}"
    script="${script[@]}"

    read scripthash < <( serscript "${script}" | hash160 )
    tmpscript=( "${script_p2sh[@]}" )
    tmpscript[2]="0x${scripthash}"

    echo "${tmpscript[@]}"
}

pay2wpkh() {

    local -a tmpscript
    local pkhash

    tmpscript=( "${script_p2wpkh[@]}" )
    read pkhash < <( addr2hash160 "${1}" )

    tmpscript[2]="0x${pkhash}"

    echo "${tmpscript[@]}"
}

pay2wsh() {

    local -a script
    local scripthash
    local -a tmpscript

    read -r -a script <<<"${1}"
    script="${script[@]}"

    read scripthash < <( serscript "${script}" | sha256 )
    tmpscript=( "${script_p2wsh[@]}" )
    tmpscript[2]="0x${scripthash}"

    echo "${tmpscript[@]}"
}

pay2ced() {

    local -a pubkeys escrow_script timeout_script tmpscript
    local -i m
    local timeout
    local -u pubkey

    read -r -a escrow_script < <( pay2mofn "${2}" "${1}" )
    read -r -a timeout_script < <( serdata "${3}" )
    read timeout < <( BC_ENV_ARGS='-q' bc 99_hash.bc <<<\
        "timeout = ${4}; \
        obase=16; ibase=16; \
        pad(timeout,8);" | revbyteorder )
    read -r -a timeout < <( serdata "${timeout}" )

    tmpscript=( "${script_ced[@]}" )
    tmpscript[1]="${escrow_script[@]}"
    tmpscript[3]="${timeout[@]}"
    tmpscript[6]="${timeout_script[@]}"

    echo -e "pay2ced :\n${tmpscript[@]}"

}

randspendamnt() {

    local amount
    read amount < <( BC_ENV_ARGS='-q' bc <<<"scale=8;\
        (${minspend} + 0.000${RANDOM})/1;")

    reducebalance "${amount}"

    echo "${amount}"
}

reducebalance() {

    read balance < <( BC_ENV_ARGS='-q' bc <<<"scale=8;\
        (${balance} - ${1})/1;") 
}

mkrandouts() {

    local minoutputs
    local -a scripttypes
    local funds

    minoutputs="${1}"
    read -r -a scripttypes <<<"${2}"
    
    if [[ "${scripttypes[0]}" == "all" ]]
    then
        scripttypes=( "p2pkey" "p2pkh" "mofn" \
            "p2wpkh" "p2wsh_p2pkey" "p2wsh_p2pkh" "p2wsh_mofn" \
            "p2sh_p2pkey" "p2sh_p2pkh" "p2sh_mofn" \
            "p2sh_p2wpkh" "p2sh_p2wsh_p2pkey" "p2sh_p2wsh_p2pkh" "p2sh_p2wsh_mofn")
    fi

    declare -A outputs
#    read balance < <( ${clientname}-cli getbalance "" 1 )

#    declare -i i1
#    i1=0
    while (( "${minoutputs}" > "${#thisoutput[@]}" )) # && \
#        [[ "${balance}" > "1.0" ]] && \
#        (( "${i1}" < "${outaddrslen}" ))
    do
        declare -a thisoutput
        declare -a data
        
        local addr
        local pubkeys_json
        addr=""
        pubkeys_json=""
        thisscript="${scripttypes[(( ${RANDOM} % ${#scripttypes[@]} ))]}"
        read thisamount < <( randspendamnt )
        # echo "i : ${i}"

        echo -e "\n\nthisscript : ${thisscript}"

        case ${thisscript} in

            *p2pkey*)
                echo -e "script = p2pk\n"
                local pubkey
                # local hexscript
                addr="${outaddrs[$(( ( ${i} + 1 ) % ${outaddrslen} ))]}"

                read pubkey < <( addr2pubkey "${addr}" )
                read -r -a data < <( pay2pubkey "${pubkey}" )
                # read hexscript < <( serscript "${data[*]}" )

                echo "pubkey    : ${pubkey}"
                # echo "outscript : ${data[@]}"
                # echo "hexscript : ${hexscript}"
                # echo -e "--------------------\n"
                i=$(( ${i}+1 ))
                ;;&
            *p2pkh*)
                echo -e "script = p2pkh\n"
                # local hexscript
                addr="${outaddrs[$(( ( ${i} + 1 ) % ${outaddrslen} ))]}"

                read -r -a data < <( pay2pkhash "${addr}" )
                # read hexscript < <( serscript "${data[*]}" )

                echo "address   : ${addr}"
                # echo "outscript : ${data[@]}"
                # echo "hexscript : ${hexscript}"
                # echo -e "--------------------\n"
                i=$(( ${i}+1 ))
                ;;&
            *p2wpkh*)
                echo -e "script = p2wpkh\n"
                # local hexscript
                addr="${outaddrs[$(( ( ${i} + 1 ) % ${outaddrslen} ))]}"

                read -r -a data < <( pay2wpkh "${addr}" )
                # read hexscript < <( serscript "${data[*]}" )

                ${clientname}-cli addwitnessaddress "${addr}"
#                ${clientname}-cli importaddress "${hexscript}" "" false false
                echo "outscript : ${data[@]}"
                # echo "hexscript : ${hexscript}"
                # echo -e "--------------------\n"
                i=$(( ${i}+1 ))
                ;;&
            *mofn*)
                echo -e "script = mofn\n"
                # local hexscript
                local -a pubkeys
                local m
                local n

                pubkeys=()
                n=15
#                n="$(( (${RANDOM} % 4) + 4 ))"
#                m="$(( ${n} -1 ))"
                m="${n}"
#                m="$(( (${RANDOM} % ${n}) +1 ))"
                # echo "req sigs  : ${m}"
                # echo "num keys  : ${n}"

                for (( j=0; j<${n}; j++ ))
                do
                    read pubkey < <( addr2pubkey "${outaddrs[$(( ( ${i} + 1 ) % ${outaddrslen} ))]}" )
                    # ${clientname}-cli importpubkey "${pubkey}" '' false 2>/dev/null
                    pubkeys+=( "${pubkey}" )
                    # echo "pubkey    : ${pubkey}"
                    i=$(( ${i}+1 ))
                done

                read pubkeys_json < <( echo ${pubkeys[*]} | sed -e 's/^/["/g' -e 's/$/"]/g' -e 's/ /","/g' )
                eval "${clientname}-cli addmultisigaddress "${m}" '${pubkeys_json}'"
                read -r -a data < <( pay2mofn "${m}" "${pubkeys[*]}" )
                # read hexscript < <( serscript "${data[*]}" )
#                ${clientname}-cli importaddress "${hexscript}" "" false false
                echo "outscript : ${data[@]}"
                # echo "hexscript : ${hexscript}"
                # echo -e "--------------------\n"
                ;;&
            *p2wsh*)
                echo -e "script = p2wsh\n"

                local script
                # local hexscript
                read script < <( serscript "${data[*]}" )
                ${clientname}-cli importaddress "${script}" "" false true 2>/dev/null

                # read witaddr < <( ${clientname}-cli decodescript "${script}" | grep p2sh )
                # witaddr=${witaddr##* \"}
                # echo ${witaddr%%\"}
                # ${clientname}-cli addwitnessaddress "${witaddr}"

                read -r -a data < <( pay2wsh "${data[*]}" )
                read script < <( serscript "${data[*]}" )
                # read hexscript < <( serscript "${data[*]}" )

                # ${clientname}-cli importaddress "${script}"
                ${clientname}-cli importaddress "${script}" "" false true 2>/dev/null
                # ${clientname}-cli importaddress "${witaddr}" "" false false

                echo "outscript : ${data[@]}"
                # echo "hexscript : ${hexscript}"
                # echo -e "--------------------\n"
                ;;&
            p2sh*)
                echo -e "script = p2sh\n"
                # local script
                # local hexscript
                local addr
                # read script < <( serscript "${data[*]}" )

                # if [[ "${thisscript}" =~ "p2w" ]]
                # then
                #    ${clientname}-cli importaddress "${witaddr}" "" false false 2>/dev/null
                # fi

                ${clientname}-cli importaddress "${script}" "" false true 2>/dev/null

                read -r -a data < <( pay2shash "${data[*]}" )
                read hexscript < <( serscript "${data[*]}" )
                read addr < <( ${clientname}-cli decodescript "${script}" | grep p2sh )
                addr="${addr#*: \"}"
                addr="${addr%\"}"

                echo "address   : ${addr}"
                echo "outscript : ${data[@]}"
                # echo "hexscript : ${hexscript}"
                # echo -e "--------------------\n"
                ;;
        esac
        
        thisoutput+=( outscript=${thisamount}:$'"'${data[*]}$'"' )
        reducebalance "${thisamount}"
        # echo "spent ... ${thisamount} ... left ${balance}"
    done
#    set -e
    create="${clientname}-tx -create ${thisoutput[@]}"
    read newtx < <( eval ${create} )
#    echo ${newtx} > "${HOME}/Documents/fundme"

#    fund="${clientname}-cli fundrawtransaction ${newtx} | grep -- \"hex\|fee\""
#    echo "funding..."
    echo "${newtx}" > "/dev/shm/thisfund" 
    json_fundrawtransaction "${newtx}" "$(bank-cli getnewaddress)" > /dev/shm/thisfund.curl

#    fund=" echo "${newtx}" | ${clientname}-cli -stdin fundrawtransaction '{\"lockUnspents\":true}' | grep -- \"hex\|fee\"" 
#    echo "funded?"

    local -a fundstate
#    while [[ "${fundstate[0]}" == "" ]]
    while [[ ! "${fundstate}" =~ "hex" ]] 
    do
#    set +e
#        readarray -t fundstate < <( eval ${fund} 2>&1 )
#        readarray -t fundstate < <( cat "/dev/shm/thisfund" | ${clientname}-cli -stdin fundrawtransaction | grep -- "hex\|fee" 2>&1 )
#        echo "${fundstate[*]}"
#        read fundstate < <(curl -s --user test_rpcuser_btc:test_rpcpass_btc --data-binary "{\"jsonrpc\": \"1.0\", \"id\":\"curltest\", \"method\": \"fundrawtransaction\", \"params\": [\"$(cat /dev/shm/thisfund)\",{\"changeAddress\":\"$(bank-cli getnewaddress)\",\"changePosition\":0}] }" -H 'content-type: text/plain;' http://127.0.0.1:38332/ )
        readarray -t fundstate < <( rpc_curl /dev/shm/thisfund.curl )
        echo ${fundstate}
        break
#        if [[ "${fundstate[*]}" =~ "Insufficient" ]]
         if [[ "${fundstate}" =~ "Insufficient" ]]
         then
             read balance < <( ${clientname}-cli getbalance )
             echo -e "balance : ${balance}\nminspend : ${minspend}"
             read minoutputs < <( BC_ENV_ARGS='-q' bc <<<"${balance} / ${minspend}" )
             if (( ${minoutputs} == 0 ))
             then
                 echo "no funds"
                 bank-cli getmempoolinfo
                 bank-cli generate 1
                 bank-cli getmempoolinfo
                 read
                 break
             fi
             # read
             continue
         fi
    echo "${fundstate}"
#    if [[ "${fundstate[*]}" =~ "-32603" ]]
    if [[ "${fundstate}" =~ "error" ]]
    then
        echo "${fundstate}"
#        read unspent < <( ${clientname}-cli listunspent 2 3 | grep amount -c )
#        if (( ${unspent} == 0 ))
#        then
#            echo "no inputs"
#            read
#            break
#        fi
        read
        break
    fi
#    set -e
    done

#    readarray -t fundstate < <( eval ${fund} )
#    ustx="${fundstate[0]#*: \"}"
#    ustx="${ustx%*\",}"
    ustx="${fundstate##*hex\":\"}"
    ustx="${ustx%\",*}"
    echo "${ustx}" > /dev/shm/thisustx
#    fee="${fundstate[1]#*: }"
    fee="${fundstate##*fee\":}"
#    fee="${fee%*,}"
    fee="${fee%\},*}"
#    set +e
    reducebalance "${fee:-"0"}"
#    set -e
    echo "fees .... ${fee} ... left ${balance}"
#    echo -e "ustx :\n${ustx}\n"

#    sign="${clientname}-cli signrawtransaction ${ustx} | grep hex"
    read sntx < <( cat /dev/shm/thisustx | ${clientname}-cli -stdin signrawtransaction | grep "hex" )
#    read sntx < <( eval ${sign} )
    sntx="${sntx#*: \"}"
    sntx="${sntx%*\",}"

#    echo -e "sntx :\n${sntx}\n"
#    sleep 
    set +e
#    ${clientname}-cli sendrawtransaction "${sntx}" true
#    echo "${sntx}" > "${HOME}/Documents/thisblock"
    echo "${sntx}" > /dev/shm/thisblock
    cat /dev/shm/thisblock | ${clientname}-cli -stdin sendrawtransaction
#    cat /dev/shm/thisblock | ${clientname}-cli -stdin decoderawtransaction | grep size

    echo "Remaining Balance : ${balance}"
}

gentxs() {

    mapfile -t intxs <"${1}"
    mapfile -t prevtxs_in <"${1}"
    # in=...:n:amount
    # in=...:n:amount
    # ...

    declare -A intxs
    for (( i=0; i < ${#prevtxs_in}; i++ ))
    do
    echo "intxs["${prevtxs_in[${i}]%:*}"]="${prevtxs_in[${i}]##*:}""
        intxs["${prevtxs_in[${i}]%:*}"]="${prevtxs_in[${i}]##*:}"
    done

    set -f
    read balance < <( ${clientname}-cli getbalance \'*\' 1)
    set +f
    intxslen="${#intxs[@]}"
}

findkey() {

    local adrhash
    local pkh

    for addr in ${outaddrs[@]}
    do
        read adrhash < <( addr2hash160 "${addr}" )

        read pkh < <( echo -n "0014${adrhash}" | sha256 )
        echo ${addr}
        if [[ "${pkh}" ==  "CFC9F960FF7B56E3E5A2B58F7C810745E771E154584BD39ABDD4C82A3AAB3E7C" ]]
        then
            echo -e "\nFOUND MATCH\n "0014${adrhash}" >> "${pkh}"\n"
        fi
    done

    echo "findkey done"
}

genoutaddrs() {

    declare -ax outaddrs

    ${clientname}-cli dumpwallet "${PWD}/wallet.txt"

    outaddrs=()
    while read -r line
    do
        if [[ "${line}" =~ "reserve=1" ]]
#        if [[ "${line}" =~ "addr" ]]
        then
            tline="${line##*reserve=1 # addr=}"
            tline="${tline%% hdkeypath*}"
            outaddrs+=( "${tline}" )
#            outaddrs+=( "${line##*addr=}" )
        fi
    done <"${PWD}/wallet.txt"

    outaddrslen="${#outaddrs[@]}"
    
#    findkey
#    return

    read balance < <( ${clientname}-cli getbalance "" 0 )
    read unspent < <( ${clientname}-cli listunspent 1 | grep amount -c )

    read minspend < <(BC_ENV_ARGS='-q' bc <<<\
        "ibase=A; obase=A; scale=8; \
        ((${balance}-1)/${1})*${3}/1")
    echo ${minspend}


    local -i k
    declare -i i
    k=1
    i=0
    while (( "${unspent}" > "0" )) && \
        [[ "${balance}" > "0" ]]
    do
        if (( ${k} % 30 == 0 ))
        then
            lastunspent="${unspent}"
            lastbalance="${balance}"
            read balance < <( ${clientname}-cli getbalance \'*\' 1 )
            read unspent < <( ${clientname}-cli listunspent 1 | grep amount | grep -v ' 0\.0' -c )
            if (( "${lastunspent}" == "${unspent}" )) || \
                [[ "${lastbalance}" == "${balance}" ]]
            then
                return
            fi
        fi
        mkrandouts "${1}" "${2}"
        k=$(( ${k}+1 ))
        break
    done
}
