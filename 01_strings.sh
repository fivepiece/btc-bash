#!/bin/bash

# echo HEX | hex2bin : BIN
# hex2bin HEX : BIN
hex2bin() {

	if [[ "${1}" == "" ]]
	then
		read hexstr
	else
		hexstr="${1}"
	fi

	declare -a bytearr;
	i=0;
	while read -N2 byte
	do
		bytearr[${i}]=${byte}
		i=$(( ${i} + 1))
	done< <(echo -n ${hexstr})

	bytearr="${bytearr[@]}"
	echo -ne "\\x${bytearr// /\\x}"
}

# echo STR | str2bytes : " BYTE BYTE..."
# str2bytes <<<"STR" : " BYTE BYTE... 0x0A"
# str2bytes FILE : " BYTE BYTE..."
alias str2bytes="od -t x1 -An -v"

# echo " BYTE BYTE..." | bytes2hexstr : BYTEBYE...
# bytes2hex " BYTE BYTE" : BYTEBYTE...
bytes2hexstr() {

	
	if [[ "${1}" == "" ]]
	then
		readarray bytestr

	else
		bytestr="${1}"
	fi

	bytestr=${bytestr[@]//$'\n'/}
	bytestr=${bytestr^^}
	printf "${bytestr// /}"
}

# echo BYTE[0]BYTE[1]...BYTE[n] | revbytes : BYTE[n]BYTE[n-1]...BYTE[0]
# revbytes BYTE[0]BYTE[1]...BYTE[n] : BYTE[n]BYTE[n-1]...BYTE[0]
revbyteorder() {

	if [[ "${1}" == "" ]]
	then
		read hexstr
	else
		hexstr="${1}"
	fi

	tmpstr=""
	for (( i=0; i<${#hexstr}; i+=2 )); do tmpstr=' '"${hexstr:${i}:2}${tmpstr}"; done
	tmpstr="${tmpstr^^}"
	printf "${tmpstr// /}"
}
