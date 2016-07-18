#!/bin/bash

sig2core() {

	local hbyte="${1}" rval="${2}" sval="${3}"

	echo "${hbyte}${rval}${sval}" | hex2bin | base64 -w 0
}

malsighead() {

	local coresig="${1}" hexcoresig hbyte
	read hexcoresig < <( echo -n "${coresig}" | base64 -d | str2bytes | bytes2hexstr )
	hbyte="${hexcoresig:0:2}"
	read hbyte < <( bc <<<"pad(${hbyte} % 8,2)" )
	r_val="${hexcoresig:2:64}"
	s_val="${hexcoresig:66}"

	while (( "${#hbyte}" < 3 ))
	do
		sig2core "${hbyte}" "${r_val}" "${s_val}"
		echo
		read hbyte < <( bc <<<"pad(${hbyte} + 8,2)" )
	done
}

sissigs() {

local coresig="${1}" msg="${2}" model="${3}" hexcoresig r_val s_val msglen z_val

hexcoresig="$(echo -n "${coresig}" | base64 -d | str2bytes | bytes2hexstr)"
r_val=${hexcoresig:2:64}
s_val=${hexcoresig:66}

read msglen < <( BC_ENV_ARGS='-q' bc <<<"obase=16; ${#msg};" )
read msglen < <( num2compsize "${msglen}" )
read msglen < <( printf ${msglen} | hex2bin | str2bytes )
msglen=" ${msglen}"
msglen="${msglen// /\\x}"
if [[ "${model}" == "core" ]]
then
	read z_val < <( printf "\\x18Bitcoin Signed Message:""\\x0a""${msglen}""${msg}" | str2bytes | bytes2hexstr | hash256 )
elif [[ "${model}" == "armory" ]]
then
	read z_val < <( printf "Bitcoin Signed Message:""\\x0a""${msg}" | str2bytes | bytes2hexstr | hash256 )
elif [[ "${model}" == "raw" ]]
then
	read z_val < <( printf "${msg}" | hash256 )
fi

echo "z1=${z_val}"
echo "r1=${r_val}"
echo "s1=${s_val}"
local -a points1 points2 upk cpk uaddr caddr 
local pkh cpkh
readarray -t points1 < <( bc <<<" \
	getycurve(${r_val},aa,bb,pp); \
	if ( ispoint(${r_val},y[0]) ){ \
		recoverapi(${z_val},${r_val},${s_val},ret[]); \
		pad(ret[0],numwsize); \
		pad(ret[1],numwsize); \
		pad(ret[2],numwsize); \
		pad(ret[3],numwsize); }" )
readarray -t points2 < <( bc <<<" \
	if ( ${r_val}+nn < pp ){ \
		getycurve(${r_val}+nn,aa,bb,pp) }; \
	if ( ispoint(${r_val}+nn,y[0]) ){  \
		recoverapi(${z_val},${r_val}+nn,${s_val},ret[]); \
		pad(ret[0],numwsize); \
		pad(ret[1],numwsize); \
		pad(ret[2],numwsize); \
		pad(ret[3],numwsize); }" )

pkh="1B"
cpkh="1F"
for (( i=0, j=0; i<${#points1[@]}; i=${i}+2, j++ ))
do
	upk[${j}]="04${points1[${i}]}${points1[$((${i}+1))]}"
	read uaddr[${j}] < <( pub2addr <<<"${upk[${j}]}" )
	
	read cpk[${j}] < <( compresspoint "${points1[${i}]}" "${points1[$((${i}+1))]}" )
	read caddr[${j}] < <( pub2addr <<<"${cpk[${j}]}" )
	
	read coresig < <( sig2core "${pkh}" "${r_val}" "${s_val}" )

	echo -e "\n\n${uaddr[${j}]}"
	echo "${upk[${j}]}"
#	sig2core "${pkh}" "${r_val}" "${s_val}"
	echo "${coresig}"
	bitcoin-cli verifymessage "${uaddr[${j}]}" "${coresig}" "${msg}"

	echo -e "\n${caddr[${j}]}"
#	sig2core "${cpkh}" "${r_val}" "${s_val}"
	read coresig < <( sig2core "${cpkh}" "${r_val}" "${s_val}" )
	echo "${coresig}"
	bitcoin-cli verifymessage "${caddr[${j}]}" "${coresig}" "${msg}"
	
	read pkh < <( bc <<<"${pkh}+1" )
	read cpkh < <( bc <<<"${cpkh}+1" )
	echo "1/2"
done

pkh="1D"
cpkh="21"
for (( i=0, j=0; i<${#points2[@]}; i=${i}+2, j++ ))
do
	upk[${j}]="04${points2[${i}]}${points2[$((${i}+1))]}"
	read uaddr[${j}] < <( pub2addr <<<"${upk[${j}]}" )
	
	read cpk[${j}] < <( compresspoint "${points2[${i}]}" "${points2[$((${i}+1))]}" )
	read caddr[${j}] < <( pub2addr <<<"${cpk[${j}]}" )

	read coresig < <( sig2core "${pkh}" "${r_val}" "${s_val}" )

	echo -e "\n\n${uaddr[${j}]}"
#	sig2core "${pkh}" "${r_val}" "${s_val}"
	echo "${cpk[${j}]}"
	echo "${coresig}"
	bitcoin-cli verifymessage "${uaddr[${j}]}" "${coresig}" "${msg}"

	echo -e "\n${caddr[${j}]}"
#	sig2core "${cpkh}" "${r_val}" "${s_val}"
	read coresig < <( sig2core "${cpkh}" "${r_val}" "${s_val}" )
	echo "${coresig}"
	bitcoin-cli verifymessage "${caddr[${j}]}" "${coresig}" "${msg}"
	
	read pkh < <( bc <<<"${pkh}+1" )
	read cpkh < <( bc <<<"${cpkh}+1" )
	echo "2/2"
done
echo
}
