#!/bin/bash

borrgenmessage(){

	local -au pubkeys=( "${1}" )
	local -u m="${2}"

	local -u cat_keys mhash
	read cat_keys <<<"${pubkeys[@]}"

#	echo -e "pubkeys : \n\t${cat_keys// /$'\n'$'\t'}" 1>&2
#	echo "message : ${m}" 1>&2
#	echo "hashing : ${m}${cat_keys// /}" 1>&2
	local -u ret
	read ret < <( sha256 "${m}${cat_keys// /}" )

	echo "${ret}"
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

#	local -u mhash
#	read mhash < <( borrgenmessage "${pubkeys}" "${message}" )

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
		e_values[$(( (${ring}*${#signers[@]})+${j} ))]="${vhash}"
		s_values[$(( (${ring}*${#signers[@]})+${j} ))]="${sig[1]}"
	done

	e0+="${sig[0]}"
#	read vhash < <( borrhash "${mhash}" "${sig[0]}" "${ring}" "0" )
#	e_values[$(( ${ring}*${#signers[@]} ))]="${vhash}"
	echo -e "kG for ring [${ring} : ${sig[0]}]\n\n" 1>&2
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

	echo "privkeys : ${privarr[@]}, i : ${!privarr[@]}" 1>&2 
	
	local -au nonce
	readarray -t nonce < <( sigk "${privarr[${signers[0]}]}" "${mhash}" )

#	local -u mhash
#	read mhash < <( borrgenmessage "${pubkeys}" "${message}" )

#	local vhash="${e_values[$(( ${ring}*${#signers[@]} ))]}"
	local -u vhash
	read vhash < <( borrhash "${mhash}" "${e0}" "${ring}" "0" )
#	vhash="${e0}"
	e_values[$(( ${ring}*${#signers[@]} ))]="${vhash}"

	local -au sig
	readarray -t sig < <( borrcalck "${vhash}" "${pubarr[0]}" "${privarr[0]}" )
	s_values[$(( ${ring}*${#signers[@]} ))]="${sig[1]}"

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
		e_values[$(( (${ring}*${#signers[@]})+${j} ))]="${vhash}"
		s_values[$(( (${ring}*${#signers[@]})+${j} ))]="${sig[1]}"
	done

	read vhash < <( borrhash "${mhash}" "${sig[0]}" "${ring}" "${j}" )
	echo "mod( ${nonce[0]} - ( ${vhash} * ${privarr[${j}]}),nn);"
	read sig[1] < <( bc 00_config.bc 99_hash.bc 01_math.bc 02_ecmath.bc <<<\
		"s=mod( ${nonce[0]} - ( ${vhash} * ${privarr[${j}]}),nn);\
		pad(s,numwsize);" )

	echo "j     : ${j}"
	echo "vhash : ${vhash}" 1>&2
	echo "end s : ${sig[1]}" 1>&2
	echo -e "\n\nSIGNER END"
	e_values[$(( (${ring}*${#signers[@]})+${j} ))]="${vhash}"
	s_values[$(( (${ring}*${#signers[@]})+${j} ))]="${sig[1]}"
}

borrverifyring() {

	local -u ring="${1}" message="${2}" pubkeys="${3}"

	local -au pubarr
	pubarr=( ${pubkeys} )
	
	local -u mhash
	read mhash < <( borrgenmessage "${pubkeys}" "${message}" )

#	local -u vhash="${e_values[$(( ${ring}*${#signers[@]} ))]}"
#	local -u vhash="${e0}"
	local -u vhash
	read vhash < <( borrhash "${mhash}" "${e0}" "${ring}" "0" )
	echo "e[$(( ${ring}*${#signers[@]} ))] = ${vhash}"

	local -au sig nonce
	readarray -t sig < <( borrcalck "${vhash}" "${pubarr[0]}" "${s_values[$(( ${ring}*${#signers[@]} ))]}" )
#	k_values[$(( ${ring}*${#signers[@]} ))]="${sig[0]}"
#	k_values+="${sig[0]}"
	echo "kG[$(( ${ring}*${#signers[@]} ))] = ${sig[0]}"

	local -i j
	for (( j=1; j<"${#pubarr[@]}"; j++ ))
	do
		read vhash < <( borrhash "${mhash}" "${sig[0]}" "${ring}" "${j}" )
		echo "e[$(( (${ring}*${#signers[@]})+${j} ))] = ${vhash}"
		readarray -t sig < <( borrcalck "${vhash}" "${pubarr[${j}]}" "${s_values[$(( (${ring}*${#signers[@]})+${j} ))]}" )
#		k_values[$(( (${ring}*${#signers[@]})+${j} ))]="${sig[0]}"
#		k_values+="${sig[0]}"
		echo "kG[$(( (${ring}*${#signers[@]})+${j} ))] = ${sig[0]}"
	done

	echo "j : ${j}"

	k_values+="${sig[0]}"
#	read vhash < <( borrhash "${mhash}" "${sig[0]}" "${ring}" "0" )
}

borrsign() {

	local pubkey_files="${1}" privkey_files="${2}" message="${3}"
	local -au rings keys

	echo "===== START BORRRINGSIGN ====="

	local -i i
	i=0
	for ring in ${pubkey_files}
	do
		[[ -r "${ring}" ]] &&\
			mapfile -t -n 1 -O "${i}" rings <"${ring}"

		echo "ring ${i} : ${rings[${i}]}"
		i=$(( ${i}+1 ))
	done

	echo "rings : ${rings[@]}"

	i=0
	echo
	for key in ${privkey_files}
	do
		[[ -r "${key}" ]] &&\
			mapfile -t -n 1 -O "${i}" keys <"${key}"

		i=$(( ${i}+1 ))
	done

	echo "Generating borromean hash of message : ${message}"
	echo "From keys : ${rings[@]}"
	local -u mhash
	read mhash < <( borrgenmessage "${rings[@]}" "${message}" )

	unset i

	local -au e_values s_values
	local -u e0
	for (( i=0; i<"${#rings[@]}"; i++ ))
	do
		echo "Start [ring "${i}"] [mhash "${mhash}"] [ids '"${rings[${i}]}"'] [signer '"${keys[${i}]}"']"
		borrringstart "${i}" "${message}" "${rings[${i}]}" "${keys[${i}]}"
	done

	echo "===== END BORRRINGSTART ====="

	echo "Combined commit : [kG_0_n-1..||..kG_m_n-1 ${e0}] [mhash ${mhash}]"
	echo "Looks like : ( sha256 "${e0}${mhash}" )"
	read e0 < <( sha256 "${e0}${mhash}" )
	echo "Connecting node : [e0 ${e0}]"

	for (( i=0; i<"${#rings[@]}"; i++ ))
	do
		echo "End   [ring "${i}"] [mhash "${mhash}"] [ids '"${rings[${i}]}"'] [signer '"${keys[${i}]}"']"
		borrringend "${i}" "${message}" "${rings[${i}]}" "${keys[${i}]}"
	done

	echo "===== END BORRRINGEND ====="

	echo "e_values : ${e_values[@]}"
	echo "s_values : ${s_values[@]}"

#	local -au k_values
	local -u k_values=""
	echo "===== START BORRVERIFYRING ====="
	for (( i=0; i<"${#rings[@]}"; i++ ))
	do
		borrverifyring "${i}" "${message}" "${rings[@]}"
	done

	echo "===== END   BORRVERIFYRING ====="

	local -u verifier
	echo "read verifier < <( sha256 "${k_values}${mhash}" )"
	read verifier < <( sha256 "${k_values}${mhash}" )

	echo "[[ ${e0} == ${verifier} ]]"
#	echo "[[ ${e_values[$(( ${ring}*${#signers[@]} ))]} == ${vhash} ]]"
}

