#!/bin/bash

sissigs() {

local coresig="${1}" msg="${2}" model="${3}" hexcoresig r_val s_val msglen z_val

hexcoresig="$(echo -n "${coresig}" | base64 -d | str2bytes | bytes2hexstr)"
r_val=${hexcoresig:2:64}
s_val=${hexcoresig:66}

#msglen="$(bc <<<"ibase=A; ${#msg};")"
read msglen < <( BC_ENV_ARGS='-q' bc <<<"obase=16; ${#msg};" )
#msglen="$(bc <<<"compsize(${msglen});")"
read msglen < <( num2compsize "${msglen}" )
#msglen="i$(printf ${msglen} | hex2bin | str2bytes)"
read msglen < <( printf ${msglen} | hex2bin | str2bytes )
msglen=" ${msglen}"
msglen="${msglen// /\\x}"
#z_val="$(printf "\\x18Bitcoin Signed Message:""\\x0a""${msglen}""${msg}" | str2bytes | bytes2hexstr | hash256)"
if [[ "${model}" == "core" ]]
then
	read z_val < <( printf "\\x18Bitcoin Signed Message:""\\x0a""${msglen}""${msg}" | str2bytes | bytes2hexstr | hash256 )
elif [[ "${model}" == "armory" ]]
then
	read z_val < <( printf "Bitcoin Signed Message:""\\x0a""${msg}" | str2bytes | bytes2hexstr | hash256 )
fi

echo "z1=${z_val}"
echo "k1x=${r_val}"
echo "s1=${s_val}"
#echo "hex=${hexcoresig}"
#echo "ks1=${hexcoresig:0:2}${r_val}${s_val}"
#echo "msg len : ${msglen}"
#echo "sighead : ${hexcoresig:0:2}"
local -a points
local uaddr1 uaddr2 caddr1 caddr2 pk1 pk2 cpk1 cpk2 cpk1h pk1h cpk2h pk2h
readarray -t points < <( bc <<<"recoverapi(${z_val},${r_val},${s_val},retarr[]); retarr[0]; retarr[1]; retarr[2]; retarr[3]" )

pk1="04${points[0]}${points[1]}"
pk2="04${points[2]}${points[3]}"
read uaddr1 < <( echo "${pk1}" | hash160 | pubhash2addr )
read cpk1 < <( compresspoint "${points[0]}" "${points[1]}" )
read caddr1 < <( echo "${cpk1}" | hash160 | pubhash2addr )

read uaddr2 < <( echo "${pk2}" | hash160 | pubhash2addr )
read cpk2 < <( compresspoint "${points[2]}" "${points[3]}" )
read caddr2 < <( echo "${cpk2}" | hash160 | pubhash2addr )

if [[ "${cpk1:0:2}" == "02" ]]
then
	cpk1h="1F"
	pk1h="23"
else
	cpk1h="20"
	pk1h="1C"
fi

if [[ "${cpk2:0:2}" == "03" ]]
then
	cpk2h="20"
	pk2h="1C"
else
	cpk2h="1F"
	pk2h="23"
fi

echo -e "\n${uaddr1}"
echo "${pk1h}${r_val}${s_val}" | hex2bin | base64 -w 0
echo -e "\n${caddr1}"
echo "${cpk1h}${r_val}${s_val}" | hex2bin | base64 -w 0

echo -e "\n${uaddr2}"
echo "${pk2h}${r_val}${s_val}" | hex2bin | base64 -w 0
echo -e "\n${caddr2}"
echo "${cpk2h}${r_val}${s_val}" | hex2bin | base64 -w 0
echo
}
