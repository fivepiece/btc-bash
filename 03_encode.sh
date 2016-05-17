#!/bin/bash

base58enc() {

	if [[ "${1}" == "" ]]
	then
		read hexstr
	else
		hexstr="${1}"
	fi

	hexstr="${hexstr^^}"

	b58str=""
	while IFS= read -r val58
	do
		b58str="${b58str}""${_codeString[${val58}]}"
	done < <( bc <<<" \
		obase=10; \
		ibase=16; \
		x=${hexstr}; \
		while(x>0){ \
		  rem=(x%3A); \
		  x/=3A; \
		  rem; };" )

	revb58str=""
	for (( i=$(( ${#b58str}-1 )); i>=0; i-- ))
	do
		revb58str="${revb58str}${b58str:${i}:1}"
	done

	zeroprefix="${hexstr%%${hexstr/*(00)/}}"
	zeroprefix="${zeroprefix//00/1}"
	printf "%s%s" "${zeroprefix}" "${revb58str}"
}

base58dec() {

	if [[ "${1}" == "" ]]
	then
		read b58str
	else
		b58str="${1}"
	fi

	b58arr_bc=()

	for (( i = 0; i < $(( ${#b58str} )); i++ ))
	do
		b58arr_bc[${i}]="c[${i}]="${_stringCode[${b58str:${i}:1}]}"; "
	done

	read b16str < <( BC_LINE_LENGTH=0 bc -q <<<" \
			${b58arr_bc[@]} \
			obase=16; \
			i=0; \
			result=0; \
			while (i<${#b58str}){ \
			  result=(result*58)+c[i]; \
			  i=i+1; }; \
			if (result > 0){
			result; };" )
	zero="0"
	oneprefix="${b58str%%${b58str/*(1)/}}"
	fixhalfbyte="$(( ${#b16str} % 2 ))"
	echo -n "${oneprefix//1/00}""${zero:0:${fixhalfbyte}}""${b16str}"

}

pub2addr() {

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

pubhash2addr() {

	if [[ "${1}" == "" ]]
	then
		read hashhex
	else
		hashhex="${1}"
	fi

	read pub256 < <( hash256 "${p2pkhVer}""${hashhex}" )

	base58enc "${p2pkhVer}${hashhex}${pub256:0:8}"
}


sisaddr() {

	if [[ "${1}" == "" ]]
	then
		read pubhex
	else
		pubhex="${1}"
	fi

	pubhex="${pubhex^^}"

	read pub02 < <( printf "%s%064s" '02' "${pubhex}" )
	pub02="${pub02// /0}"

	read pub03 < <( printf "%s%064s" '03' "${pubhex}" )
	pub03="${pub03// /0}"

	readarray yval < <( bc -q 00_config.bc 01_math.bc 02_ecmath.bc 03_ecdsa.bc <<<"getycurve(${pubhex},aa,bb,pp); y[0]; y[1];" )

	read pub04 < <( printf "%s%064s%065s" '04' "${pubhex}" "${yval[0]}" )
	pub04="${pub04// /0}"

	read pub04n < <( printf "%s%064s%065s" '04' "${pubhex}" "${yval[1]}" )
	pub04n="${pub04n// /0}"

	for pub in ${pub02} ${pub03} ${pub04} ${pub04n}
	do
		pub2addr "${pub}"
		echo -e "\n${pub}"
	done
}
