#!/bin/bash

borrgenmessage(){

	local -au pubkeys=( "${1}" )
	local -u m="${2}"

	local -u cat_keys mhash
	read cat_keys <<<"${pubkeys[@]}"

#	echo -e "pubkeys : \n\t${cat_keys// /$'\n'$'\t'}" 1>&2
#	echo "message : ${m}" 1>&2
#	echo "hashing : ${m}${cat_keys// /}" 1>&2
	local -u mhash
	read mhash < <( sha256 "${m}${cat_keys// /}" )

	echo "${mhash}"
#	echo "" 1>&2
}

borrcalck() {

	local -u e="${1}" pubkey="${2}" s=""

	[[ "${3}" != "" ]] && s="${3}" || read s < <( randhex "${vsize}" )

#	echo "e : ${e}" 1>&2
#	echo "P : ${pubkey}" 1>&2
#	echo "s : ${s}" 1>&2

	readarray -t pubkey < <( uncompresspoint "${pubkey}" )
#	echo "P : ${pubkey[@]}" 1>&2

	bc 99_hash.bc 00_config.bc 01_math.bc 02_ecmath.bc 03_ecdsa.bc <<<\
		"ecmulcurve(${s},ggx,ggy,nn,pp);\
		s_x=tx; s_y=ty;\
		ecmulcurve(${e},${pubkey[0]},${pubkey[1]},nn,pp);\
		e_x=tx; e_y=ty;\
		ecaddcurve(s_x,s_y,e_x,e_y,pp);\
		compresspoint(rx,ry);"
	echo "${s}"
}

borrhash() {

	local -u m="${1}" pubkey="${2}" i="${3}" j="${4}"

	read i < <( num2compsize "${i}" )
	read j < <( num2compsize "${j}" )

	sha256 "${pubkey}${m}${i}${j}"
}

borrringstart() {

	local -u ring="${1}" message="${2}" pubkeys="${3}" privkeys="${4}"

	local -au pubarr signers
	local -Au privarr

	pubarr=( ${pubkeys} )
	for privkey in ${privkeys}
	do
		echo "privarr[${privkey%=*}]="${privkey#*=}"" 1>&2 
		privarr[${privkey%=*}]="${privkey#*=}"
	done
	signers=( ${!privarr[@]} )

	echo -e "privkeys : ${privarr[@]}, i : ${!privarr[@]}" 1>&2 

	local -u mhash
	read mhash < <( borrgenmessage "${pubkeys}" "${message}" )

	echo "SIGNER BEGIN : ${pubarr[${signers[0]}]}, ${signers[0]}" 1>&2 
	local -au sig nonce
	local vhash
	readarray -t nonce < <( sigk "${privarr[${signers[0]}]}" "${mhash}" )
	echo "SIGNER k     : ${nonce[0]}" 1>&2 
	read sig[0] < <( compresspoint "${nonce[1]}" "${nonce[2]}" )
	echo "SIGNER kG    : ${sig[0]}" 1>&2 
	
	for (( j=$(( ${signers[0]}+1 )); j>0; j=$(( (${j}+1) % ${#pubarr[@]} )) ))
	do
		read vhash < <( borrhash "${mhash}" "${sig[0]}" "${ring}" "${j}" )
		readarray -t sig < <( borrcalck "${vhash}" "${pubarr[${j}]}" "${privarr[${j}]}" )

		echo "vhash : ${vhash}" 1>&2
		echo "K     : ${sig[0]}" 1>&2 
		echo "s     : ${sig[1]}" 1>&2
		e_values[${j}]="${vhash}"
		s_values[${j}]="${sig[1]}"
	done

	read vhash < <( borrhash "${mhash}" "${sig[0]}" "${ring}" "0" )
	e_values[0]="${vhash}"
	echo "e0 hash for ring ${ring} : ${vhash}" 1>&2
}

borrringend() {

	local -u ring="${1}" message="${2}" pubkeys="${3}" privkeys="${4}"

	local -au pubarr signers
	local -Au privarr

	pubarr=( ${pubkeys} )
	for privkey in ${privkeys}
	do
		echo "privarr[${privkey%=*}]="${privkey#*=}"" 1>&2 
		privarr[${privkey%=*}]="${privkey#*=}"
	done
	signers=( ${!privarr[@]} )

	echo -e "privkeys : ${privarr[@]}, i : ${!privarr[@]}" 1>&2 

	local -u mhash
	read mhash < <( borrgenmessage "${pubkeys}" "${message}" )

	local vhash="${e_values[0]}"
	local -au sig nonce
	readarray -t nonce < <( sigk "${privarr[${signers[0]}]}" "${mhash}" )
	readarray -t sig < <( borrcalck "${vhash}" "${pubarr[0]}" "${privarr[0]}" )
	s_values[0]="${sig[1]}"
	
	echo "vhash : ${vhash}" 1>&2
	echo "K     : ${sig[0]}" 1>&2 
	echo "s     : ${sig[1]}" 1>&2
	
	local -i j
	for (( j=1; j<"${signers[0]}"; j++ ))
	do
		read vhash < <( borrhash "${mhash}" "${sig[0]}" "${ring}" "${j}" )
		readarray -t sig < <( borrcalck "${vhash}" "${pubarr[${j}]}" "${privarr[${j}]}" )
		echo "vhash : ${vhash}" 1>&2
		echo "K     : ${sig[0]}" 1>&2 
		echo "s     : ${sig[1]}" 1>&2
		e_values[${j}]="${vhash}"
		s_values[${j}]="${sig[1]}"
	done

	read vhash < <( borrhash "${mhash}" "${sig[0]}" "${ring}" "${j}" )
	echo "mod( ${nonce[0]} - ( ${vhash} * ${privarr[${j}]}),nn);"
	read sig[1] < <( bc 00_config.bc 99_hash.bc 01_math.bc 02_ecmath.bc <<<\
		"mod( ${nonce[0]} - ( ${vhash} * ${privarr[${j}]}),nn);" ) # ADD PADDING

	echo "j     : ${j}"
	echo "vhash : ${vhash}" 1>&2
	echo "end s : ${sig[1]}" 1>&2
	echo "SIGNER END"
	e_values[${j}]="${vhash}"
	s_values[${j}]="${sig[1]}"
}

borrverifyring() {

	local -u ring="${1}" message="${2}" pubkeys="${3}"

	local -au pubarr
	pubarr=( ${pubkeys} )
	
	local -u mhash
	read mhash < <( borrgenmessage "${pubkeys}" "${message}" )

	local -u vhash="${e_values[0]}"
	local -au sig nonce
	readarray -t sig < <( borrcalck "${vhash}" "${pubarr[0]}" "${s_values[0]}" )

	local -i j
	for (( j=1; j<"${#pubarr[@]}"; j++ ))
	do
		read vhash < <( borrhash "${mhash}" "${sig[0]}" "${ring}" "${j}" )
		readarray -t sig < <( borrcalck "${vhash}" "${pubarr[${j}]}" "${s_values[${j}]}" )
	done

	echo "j : ${j}"

	read vhash < <( borrhash "${mhash}" "${sig[0]}" "${ring}" "0" )

	echo "[[ ${e_values[0]} == ${vhash} ]]"
}

borrsign() {

	local pubkey_files="${1}" privkey_files="${2}" message="${3}"
	local -a rings
	local -a keys

	local -i i
	i=0
	for ring in ${pubkey_files}
	do
		[[ -r "${ring}" ]] &&\
			echo True &&\
			mapfile -t -s "${i}" -n 1 -O "${i}" rings <"${ring}"
		i=$(( ${i}+1 ))
	done

	echo "rings : ${rings[@]}"
	echo "sizes : ${!rings[@]}"

	i=0
	for key in ${privkey_files}
	do
		[[ -r "${keys}" ]] &&\
			echo True &&\
			mapfile -t -s "${i}" -n 1 -O "${i}" keys <"${key}"
		i=$(( ${i}+1 ))
	done
}

