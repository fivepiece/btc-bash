#!/bin/bash

sha256() {

	local -u hexstr
	if [[ "${1}" == "" ]]
	then
	
		read hexstr
	else
	
		hexstr="${1}"
	fi

	local -u digest
	read digest < <( hex2bin "${hexstr^^}" | sha256sum -b )
	digest="${digest% *-}"

	printf "${digest^^}"
}

ripemd160() {

	local -u hexstr
	if [[ "${1}" == "" ]]
	then
	
		read hexstr
	else
	
		hexstr="${1}"
	fi

	local -u digest
	read digest < <( hex2bin "${hexstr^^}" | openssl rmd160 -r )
	digest="${digest% *}"

	printf "${digest^^}"
}

sha512() {

	local -u hexstr
	if [[ "${1}" == "" ]]
	then
	
		read hexstr
	else
	
		hexstr="${1}"
	fi

	local -u digest
	read digest < <( hex2bin "${hexstr^^}" | sha512sum -b )
	digest="${digest% *-}"

	printf "${digest^^}"
}

hash256() {

	local -u hash0 hash1 hash2
	if [[ "${1}" == "" ]]
	then
	
		read hash0
	else
	
		hash0="${1}"
	fi

	read hash1 < <( sha256 "${hash0^^}" )
	read hash2 < <( sha256 "${hash1}" )

	printf "${hash2}"
}

hash160() {

	local -u hash0 hash1 hash2
	if [[ "${1}" == "" ]]
	then
	
		read hash0
	else
	
		hash0="${1}"
	fi

	read hash1 < <( sha256 "${hash0^^}" )
	read hash2 < <( ripemd160 "${hash1}" )

	printf "${hash2}"
}

hash512() {

	local -u hash0 hash1 hash2
	if [[ "${1}" == "" ]]
	then
	
		read hash0
	else
	
		hash0="${1}"
	fi

	read hash1 < <( sha512 "${hash0^^}" )
	read hash2 < <( ripemd160 "${hash1}" )

	printf "${hash2}"
}

hmac() { # https://www.ietf.org/rfc/rfc2104.txt

	local -u key text
	key="${1^^}"
	text="${2^^}"

	# keys larger than the maximum keysize are hashed to a keysize length hash
	if (( "${#key}" > "$((16#${keysize}))" ))
	then
		read key < <( sha256 "${key}" )
	fi

	local -u knw
	# number of null words to consider at the start of the key.
	# the key "1" will become "100..00", and the key "00..001"
	# will be treated as '0x01'
	#
	knw="${key%%${key/*(0)/}}"

	local -au pads
	# steps (1) (2) (5)
	# pads[0] = key
	# pads[1] = opad
	# pads[2] = ipad
	#
	readarray -t pads < <( bc <<<"hmac(${#knw}, ${key}, ${hashblock});" )

	# step (3)
	text="${pads[2]}${text}"

	# step (4)
	read text < <( sha256 "${text}" )

	# step (6)
	text="${pads[1]}${text}"

	# step (7)
	read text < <( sha256 "${text}" )

	echo "${text}"
}

sigk() { # https://tools.ietf.org/html/rfc6979#section-3.2

	local -u key msg
	key="${1^^}"
	msg="${2^^}"

	# keys shorter than the keysize are appended 0x00's
	if (( ${#key} < $((16#${keysize})) ))
	then
		read key < <( bc <<<"pad(${key},${keysize});" )
	fi

	local -u h1 v k t foundk
	# 3.2.a
	read h1 < <( sha256 "${msg}" )
#	echo
#	echo "# sighash : ${h1}"

	# 3.2.b
	read v < <( printf "%0*d" "${vsize}" 0 )
	v="${v//0/01}"
#	echo "# 3.2.b, v : ${v}"

	# 3.2.c
	read k < <( printf "%0*d" "${vsize}" 0 )
	k="${k//0/00}"
#	echo "# 3.2.c, k : ${k}"

	# 3.2.d
	read k < <( hmac "${k}" "${v}00${key}${h1}" )
	# 3.2.e
	read v < <( hmac "${k}" "${v}" )

#	echo "# 3.2.d, k : ${k}"
#	echo "# 3.2.e, v : ${v}"

	# 3.2.f
	read k < <( hmac "${k}" "${v}01${key}${h1}" )
	# 3.2.g
	read v < <( hmac "${k}" "${v}" )

#	echo "# 3.2.f, k : ${k}"
#	echo "# 3.2.g, v : ${v}"

	# 3.2.h
	while :
	do
#		echo "start 3.2.h"
		# 3.2.h.1
		t=""

		# 3.2.h.2
		while (( ${#t} < $((16#${keysize})) ))
		do
#			echo "start 3.2.h.2"
			read v < <( hmac "${k}" "${v}" )
			t="${t}${v}"
#			echo "# 3.2.h.2, v : ${v}"
#			echo "# 3.2.h.2, t : ${t}"
#			echo "end   3.2.h.2"
		done

		# 3.2.h.3
		read foundk < <( bc <<<"(1 < ${t}) && (${t} < nn);" )

		if (( "${foundk}" == 1 ))
		then
			bc <<<"ecmulcurve(${t},ggx,ggy,nn,pp); print ${t}, \"\n\", tx, \"\n\", ty, \"\n\";"
#				"print \"\n# K : \", ${t}, \"\n\"; ecmul(${t});"
			return
		fi

		read k < <( hmac "${k}" "${v}00" )
#		echo "# 3.2.h.3, k : ${k}"
#		echo "end   3.2.h"
#		read v < <( hmac "${k}" "${v}" )
	done
}

randhex() {

	bytes2hexstr < <(str2bytes -N"${1}" /dev/urandom)
	echo
}
