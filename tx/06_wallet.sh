#!/bin/bash

pubkey2addr() {

	local -u pubhex pub160 pub256
	if [[ "${1}" == "" ]]
	then
		read pubhex
	else
		pubhex="${1}"
	fi

	pubhex="${pubhex^^}"

	read pub160 < <( hash160 "${pubhex}" )
	read pub256 < <( hash256 "${p2pkhVer}""${pub160}" )

	base58enc "${p2pkhVer}${pub160}${pub256:0:8}"
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

hash1602addr() {

	local -u hashhex pub256
	if [[ "${1}" == "" ]]
	then
		read hashhex
	else
		hashhex="${1}"
	fi

	read pub256 < <( hash256 "${p2pkhVer}""${hashhex}" )

	base58enc "${p2pkhVer}${hashhex}${pub256:0:8}"
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
