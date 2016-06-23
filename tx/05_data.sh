#!/bin/bash

op_num=( "00" "51" "52" "53" "54" "55" "56" "57" "58" "59" "5A" "5B" "5C" "5D" "5E" "5F" "60" )
ser_data=( "size" "data" )

script_p2pk=( "size" "pubkey" "CHECKSIG" )
script_p2pkh=( "DUP" "HASH160" "0x14" "pubkeyhash" "EQUALVERIFY" "CHECKSIG" )
script_p2wpkh=( "0x00" "0x14" "pubkeyhash" )
script_mofn=( "m" "pubkeys" "n" "CHECKMULTISIG" )
script_p2wsh=( "0x00" "0x20" "scripthash" )
script_p2sh=( "HASH160" "0x14" "scripthash" "EQUAL" )

# num2compsize()

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
	read pubkey < <( segnet-cli validateaddress "${1}" | grep pubkey )
	pubkey="${pubkey#*:}"
	pubkey="${pubkey//[\",]/}"

	echo "${pubkey}"
}

addr2hash160() {

	local pkhash
	read pkhash < <( base58dec "${1}" )
	pkhash="${pkhash:2:40}"

	echo "${pkhash}"
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
