#!/bin/bash

declare -A _stringCode
_stringCode=(\
    [A]=09 [B]=10 [C]=11 [D]=12 [E]=13 [F]=14 [G]=15 [H]=16 \
    [J]=17 [K]=18 [L]=19 [M]=20 [N]=21 [P]=22 [Q]=23 [R]=24 \
    [S]=25 [T]=26 [U]=27 [V]=28 [W]=29 [X]=30 [Y]=31 [Z]=32 \
    [a]=33 [b]=34 [c]=35 [d]=36 [e]=37 [f]=38 [g]=39 [h]=40 \
    [i]=41 [j]=42 [k]=43 [m]=44 [n]=45 [o]=46 [p]=47 [q]=48 \
    [1]=00 [r]=49 [2]=1 [s]=50 [3]=2 [t]=51 [4]=3 [u]=52 [5]=4 \
    [v]=53 [6]=5 [w]=54 [7]=6 [x]=55 [8]=7 [y]=56 [9]=8 [z]=57)

declare -a _codeString
_codeString=(\
    1 2 3 4 5 6 7 8 9 A B C D E F G H J K \
    L M N P Q R S T U V W X Y Z a b c d e \
    f g h i j k m n o p q r s t u v w x y z)

base58enc() {

    local -u hexstr
    if [[ "${1}" == "" ]]
    then
        read hexstr
    else
		hexstr="${1}"
	fi

	hexstr="${hexstr^^}"

	local b58str revb58str zeroprefix
	b58str=""
	while IFS= read -r val58
	do
		b58str="${b58str}""${_codeString[${val58}]}"
	done < <( BC_ENV_ARGS='-q' bc <<<" \
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

	local b58str
	if [[ "${1}" == "" ]]
	then
		read b58str
	else
		b58str="${1}"
	fi

	local -a b58arr_bc
#	b58arr_bc=()

	for (( i = 0; i < $(( ${#b58str} )); i++ ))
	do
		b58arr_bc[${i}]="c[${i}]="${_stringCode[${b58str:${i}:1}]}"; "
	done

	local zero oneprefix fixhalfbyte
	read b16str < <( BC_ENV_ARGS='-q' bc <<<"\
		${b58arr_bc[@]}\
		obase=16;\
		i=0;\
		result=0;\
		while (i<${#b58str}){\
		  result=(result*58)+c[i];\
		  i=i+1; };\
		if (result > 0){\
		result; };" )
	zero="0"
	oneprefix="${b58str%%${b58str/*(1)/}}"
	fixhalfbyte="$(( ${#b16str} % 2 ))"
	echo -n "${oneprefix//1/00}""${zero:0:${fixhalfbyte}}""${b16str}"

}

pub2addr() {

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

pubhash2addr() {

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

compresspoint() {

	local -u x="${1}" y="${2}"

	bc <<<"compresspoint(${x},${y});"
}

uncompresspoint() {

	local -u x="${1}"

	bc <<<"uncompresspoint(${x});"
}

num2compsize() {

	local -u size="${1}"

	read size < <( bc <<<"x=${size}; compsize(x);" )

	echo -n "${size:0:2}"
	revbyteorder <<<"${size:2}"
}

sisaddr() {

	local -u pubhex pub02 pub03 pub04 pub04n

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

	readarray yval < <( bc <<<"getycurve(${pubhex},aa,bb,pp); y[0]; y[1];" )

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

dec2amount() {

	local decimal revamount
	if [[ "${1}" == "" ]]
	then
		read decimal
	else
		decimal="${1}"
	fi

	read revamount < <( bc <<<" \
		ibase=A; \
		bal=${decimal}*100000000; \
		ibase=16; \
		pad(bal/1,10);" )

	revbyteorder "${revamount}"
}

amount2dec() {

	local hexamount revamount
	if [[ "${1}" == "" ]]
	then
		read hexamount
	else
		hexamount="${1}"
	fi

	read revamount < <( revbyteorder "${hexamount}" )

	BC_ENV_ARGS='-q' bc <<<" \
		scale=8; \
		satoshi=100000000; \
		ibase=16; \
		print ${revamount}/satoshi;"
}
