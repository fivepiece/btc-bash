#!/bin/bash

pay2pubkey() {

	local -a tmpscript
	local size

	tmpscript=( "${script_p2pk[@]}" )
	read size < <( datasize "${#1}" )

	tmpscript[0]="0x${size}"
	tmpscript[1]="0x${1}"

	echo "${tmpscript[@]}"
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
