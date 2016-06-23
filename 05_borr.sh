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

	bc <<<\
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

	local -u ring="${1}" pubkeys="${2}" privkeys="${3}"

	local -au pubarr signers
	local -Au privarr

	pubarr=( ${pubkeys} )
	for privkey in ${privkeys}
	do
		privarr[${privkey%=*}]="${privkey#*=}"
	done
	signers=( ${!privarr[@]} )

	echo "signer privkey : ${privarr[@]}, at index : ${!privarr[@]}" 1>&2

	echo "begin ring loop at : ${pubarr[${signers[0]}]}, index ${signers[0]}" 1>&2 
	local -au sig nonce
	local vhash
	readarray -t nonce < <( sigk "${privarr[${signers[0]}]}" "${mhash}" )
	echo "signer k value : ${nonce[0]}" 1>&2 
	read sig[0] < <( compresspoint "${nonce[1]}" "${nonce[2]}" )
	echo "signer kG value : ${sig[0]}" 1>&2 

	for (( j=$(( ${signers[0]}+1 )); j>0 && j<"${#pubarr[@]}"; j=$(( (${j}+1) % ${#pubarr[@]} )) ))
	do
		read vhash < <( borrhash "${mhash}" "${sig[0]}" "${ring}" "${j}" )
		readarray -t sig < <( borrcalck "${vhash}" "${pubarr[${j}]}" "${privarr[${j}]}" )
		e_values[$(( ${pointer}+${j} ))]="${vhash}"
		s_values[$(( ${pointer}+${j} ))]="${sig[1]}"

		echo "e_values[$(( ${pointer}+${j} ))] = ${vhash}"
		echo "kG value = ${sig[0]}" 1>&2 
		echo "s_values[$(( ${pointer}+${j} ))] = ${sig[1]}"
	done

	e0+="${sig[0]}"
	echo "kG for ring ${ring} : ${sig[0]}" 1>&2
	pointer="$(( ${pointer}+${#pubarr[@]} ))"
	echo -e "pointer is at index : ${pointer}\n\n"
}

borrringend() {

	local -u ring="${1}" pubkeys="${2}" privkeys="${3}"

	local -au pubarr signers
	local -Au privarr

	pubarr=( ${pubkeys} )
	for privkey in ${privkeys}
	do
		privarr[${privkey%=*}]="${privkey#*=}"
	done
	signers=( ${!privarr[@]} )

	echo "signer privkey : ${privarr[@]}, at index : ${!privarr[@]}" 1>&2 
	
	local -au nonce
	readarray -t nonce < <( sigk "${privarr[${signers[0]}]}" "${mhash}" )
	echo "signer k value : ${nonce[0]}"

	local -u vhash
	read vhash < <( borrhash "${mhash}" "${e0}" "${ring}" "0" )
	e_values[$(( ${pointer} ))]="${vhash}"

	local -au sig

	readarray -t sig < <( borrcalck "${vhash}" "${pubarr[0]}" "${privarr[0]}" )
	s_values[$(( ${pointer} ))]="${sig[1]}"

	echo "e_values[$(( ${pointer} ))] = ${vhash}"
	echo "kG value = ${sig[0]}" 1>&2 
	echo "s_values[$(( ${pointer} ))] = ${sig[1]}"

	local -i j=0
	(( ${signers[0]} != 0 )) &&\
	for (( j=1; j<"${signers[0]}"; j++ ))
	do
		read vhash < <( borrhash "${mhash}" "${sig[0]}" "${ring}" "${j}" )
		readarray -t sig < <( borrcalck "${vhash}" "${pubarr[${j}]}" "${privarr[${j}]}" )
		e_values[$(( ${pointer}+${j} ))]="${vhash}"
		s_values[$(( ${pointer}+${j} ))]="${sig[1]}"
		
		echo "e_values[$(( ${pointer}+${j} ))] = ${vhash}"
		echo "kG value = ${sig[0]}" 1>&2 
		echo "s_values[$(( ${pointer}+${j} ))] = ${sig[1]}"
	done &&\
	read vhash < <( borrhash "${mhash}" "${sig[0]}" "${ring}" "${j}" )

	echo "mod( ${nonce[0]} - ( ${vhash} * ${privarr[${j}]}),nn);"
	read sig[1] < <( bc <<<\
		"s=mod( ${nonce[0]} - ( ${vhash} * ${privarr[${j}]}),nn);\
		pad(s,numwsize);" )
	
	e_values[$(( ${pointer}+${j} ))]="${vhash}"
	s_values[$(( ${pointer}+${j} ))]="${sig[1]}"
	echo "signer e_values[$(( ${pointer}+${j} ))] = ${vhash}"
	echo "signer s_values[$(( ${pointer}+${j} ))] = ${sig[1]}"

	pointer="$(( ${pointer}+${#pubarr[@]} ))"
	echo "pointer is at index ${pointer}"
	echo -e "signing ring ${ring} done\n\n"
}

borrverifyring() {

	local -u ring="${1}" pubkeys="${2}"

	local -au pubarr
	pubarr=( ${pubkeys} )

	echo "identities : ${pubkeys}" 1>&2
	echo "s_values[${pointer},${#pubarr[@]}]" 1>&2

	local -u vhash
	read vhash < <( borrhash "${mhash}" "${e0}" "${ring}" "0" )
	echo "e[${pointer}] = ${vhash}" 1>&2

	local -au sig nonce
	readarray -t sig < <( borrcalck "${vhash}" "${pubarr[0]}" "${s_values[$(( ${pointer} ))]}" )
	echo "kG[${pointer}] = ${sig[0]}" 1>&2

	local -i j
	for (( j=1; j<"${#pubarr[@]}"; j++ ))
	do
		read vhash < <( borrhash "${mhash}" "${sig[0]}" "${ring}" "${j}" )
		echo "e[$(( ${pointer}+${j} ))] = ${vhash}" 1>&2
		readarray -t sig < <( borrcalck "${vhash}" "${pubarr[${j}]}" "${s_values[$(( ${pointer}+${j} ))]}" )
		echo "kG[$(( ${pointer}+${j} ))] = ${sig[0]}" 1>&2
	done

	echo "j : ${j}"

	k_values+="${sig[0]}"
	echo "added ${sig[0]} to k_values" 1>&2
	pointer="$(( ${pointer}+${#pubarr[@]} ))"
	echo "Pointer is ${pointer}" 1>&2
}

borrsign() {

	local pubkey_files="${1}" privkey_files="${2}" message="${3}"
	local -au rings keys

	local -i i
	i=0
	for ring in ${pubkey_files}
	do
		[[ -r "${ring}" ]] &&\
			mapfile -t -n 1 -O "${i}" rings <"${ring}"

		echo "ring ${i} : ${rings[${i}]}"
		i=$(( ${i}+1 ))
	done

	i=0
	echo
	for key in ${privkey_files}
	do
		[[ -r "${key}" ]] &&\
			mapfile -t -n 1 -O "${i}" keys <"${key}"

		i=$(( ${i}+1 ))
	done
	unset i

	echo "message : ${message}"
	echo "generating message from pubkeys[@] || message"
	local -u mhash
	read mhash < <( borrgenmessage "${rings[@]}" "${message}" )
	echo -e "message hash : ${mhash}\n\n"

	local -i pointer=0
	local -au e_values s_values
	local -u e0

	for (( i=0; i<"${#rings[@]}"; i++ ))
	do
		echo "starting signature of ring ${i}"
		borrringstart "${i}" "${rings[${i}]}" "${keys[${i}]}"
	done

	echo "hashing : kG_0_n-1..||..kG_m_n-1 || mhash"
	read e0 < <( sha256 "${e0}${mhash}" )
	echo -e "e0 value : ${e0}\n\n"

	pointer=0
	for (( i=0; i<"${#rings[@]}"; i++ ))
	do
		echo "completing signature of ring ${i}"
		borrringend "${i}" "${rings[${i}]}" "${keys[${i}]}"
	done

	echo "e_values : ${e_values[@]}"
	echo "s_values : ${s_values[@]}"

	echo "${e0}" > ./sig.hex
	echo "${s_values[@]}" >> ./sig.hex
}

borrverify() {

	local pubkey_files="${1}" signature_file="${2}" message="${3}"

	local -au rings s_values
	local -u e0 svals

	local -i i
	i=0
	for ring in ${pubkey_files}
	do
		[[ -r "${ring}" ]] &&\
			mapfile -t -n 1 -O "${i}" rings <"${ring}"

		echo "ring ${i} : ${rings[${i}]}"
		i=$(( ${i}+1 ))
	done
	unset i

	[[ -r "${signature_file}" ]] &&\
		mapfile -t -n 1 e0 <"${signature_file}" &&\
		mapfile -t -n 1 -s 1 svals <"${signature_file}"
	s_values=( ${svals} )
	echo "s_values = ${s_values[@]} , # = ${#s_values[@]}"

	echo "message : ${message}"
	echo "generating message from pubkeys[@] || message"
	local -u mhash
	read mhash < <( borrgenmessage "${rings[@]}" "${message}" )
	echo -e "message hash : ${mhash}\n\n"

	local -i pointer=0
	local -u k_values=""

	for (( i=0; i<"${#rings[@]}"; i++ ))
	do
		echo "verifying ring ${i}"
		borrverifyring "${i}" "${rings[${i}]}"
	done

	local -u verifier
	echo "read verifier < <( sha256 "${k_values}${mhash}" )"
	read verifier < <( sha256 "${k_values}${mhash}" )

	echo "[[ ${e0} == ${verifier} ]]"

}
