#!/bin/bash

schsign() {

	# d = private key, m = message hash
	# kr = array for k and r values
	local -u d="${1}" m="${2}"
	local -a kr

	# k = rfc6979(d, m)
	# r = kG_x
	readarray -t kr < <(sigk "${d}" "${m}")
	local -u k="${kr[0]}" r="${kr[1]}"
	unset kr

	# if needed, pad r with null words so |r| = 32 bytes
	read r < <( bc 00_config.bc 99_hash.bc <<<"pad(${r},numwsize);" )

	# c = commitment = sha256(m||r)
	local -u c
	read c < <( sha256 "${m}${r}" )

	# if needed, discard null words, making c an integer
	read c < <( bc 00_config.bc <<<"c=${c}; c;" )

	# s = signature = k - c*d mod n
	local -u s
	read s < <( bc 00_config.bc 01_math.bc <<<"mod(${k} - (${c} * ${d}),nn);" )

	echo ${c} ${s}
}

schverify() {

	# (x,y) = signers pubkey, m = message hash
	# c = commitment, s = signature
	local -u x="${1}" y="${2}" m="${3}" c="${4}" s="${5}"
	local -i cond

	# condition: ( 0 <= c < |sha256| ) && ( 1 <= s < n )
	read cond < <( bc 00_config.bc <<<\
		"( (0 <= ${c}) && (${c} < (2^100)) ) && ( (1 <= ${s}) && (${s} < nn) )" )

	if (( ! ${cond} ))
	then
		echo FALSE
		return
	fi

	# q = array for kG_x and kG_y
	local -a q
	# (s_x,s_y) = sG
	# (c_x,c_y) = cP, P = (x,y) => cP = c*dG
	# kG = sG + cP
	readarray -t q < <( bc 00_config.bc 01_math.bc 02_ecmath.bc <<<\
		"ecmulcurve(${s},ggx,ggy,nn,pp);\
		sgx = tx; sgy = ty;\
		ecmulcurve(${c},${x},${y},nn,pp);\
		cpx = tx; cpy = ty;\
		ecaddcurve(sgx,sgy,cpx,cpy,pp);\
		if ( ispoint(rx,ry) ){\
			print rx, \"\n\", ry, \"\n\";\
		}else{\
			print \"FALSE\";\
		};" )

	echo "# Q : ${q[0]} ${q[1]}"

	# v = verifies the commitment
	# q[0] == kG_x == r
	# sha256(m||r) = c ==? v
	local -u v
	read v < <( bc 00_config.bc 99_hash.bc <<<"pad(${q[0]},numwsize);" )
	read v < <( sha256 "${m}${q[0]}" )
	read v < <( bc 00_config.bc <<<"v=${v}; v;" )

	if [[ "${v}" == "${c}" ]]
	then
		echo TRUE
	else
		echo FALSE
	fi
}

schauthsign() {

	local -u d="${1}" m="${2}" a="${3}"
	local -a kr

	readarray -t kr < <( sigk "${d}" "${m}" )
	
	local -u k="${kr[0]}" r="${kr[1]}" e=""
	unset kr

	read e < <( sha256 "${m}${r}${a}" )

	local -u s

	read s < <( bc 00_config.bc 01_math.bc <<<\
		"mod( (${k} + (${e} * ${d})), nn);" )

	echo -e "${s}\n${e}"
}

schauthverify() {

	local -u s="${1}" e="${2}" x="${3}" m="${4}" a="${5}"

	local -au pubkey
	readarray -t pubkey < <(bc 00_config.bc 01_math.bc 02_ecmath.bc <<<\
		"uncompresspoint(${x});" )

	local -u kx c

	read kx < <(bc 00_config.bc 01_math.bc 02_ecmath.bc <<<\
		"ecmulcurve(${e},${pubkey[0]},${pubkey[1]},pp,nn);\
		ex=tx; ey=ty;\
		ecmulcurve(${s},ggx,ggy,pp,nn);\
		sx=tx; sy=ty;\
		ecaddcurve(sx,sy,ex,-ey,pp);\
		rx;" )

	read c < <( sha256 "${m}${kx}${a}" )

	( [[ "${c}" == "${e}" ]] && [[ "${c}" != "" ]] && echo true ) || echo false

	echo "${kx}"
}
