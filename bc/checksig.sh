#!/usr/bin/env bash

source /home/esh/software/git/bitcoin-bash/00_global.sh

for (( i=1; i<=1; i++ ))
do
#	msg=$(printf %0"${i}"d 0)
	msg="short sigs are cool"
	coresig=($(bitcoin-cli signmessage 15FFo2LXWsqURJxqFW6MaWqZKScxcAGVwZ "${msg}"))
	echo "CORESIG : ${coresig}"

	bitcoin-cli verifymessage 18h36rNEPV1Xa2Lj5zmG6oChsct2sJjvFy "${coresig}" "${msg}"

	hexcoresig="$(echo -n "${coresig}" | base64 -d | str2bytes | bytes2hexstr)"
	r_val=${hexcoresig:2:64}
	s_val=${hexcoresig:66}

	msglen="$(bc <<<"obase=16; ${#msg};")"
	msglen="$(bc 99_bitcoin.bc <<<"obase=16; ibase=16; compsize(${msglen});")"
	msglen="${msglen:0:2}""$(echo -n ${msglen:2} | revbyteorder)"
	msglen="$(printf ${msglen} | hex2bin | str2bytes)"
	msglen="${msglen// /\\x}"
	echo '${msglen} :' "${msglen}"
	z_val="$(printf "\\x18Bitcoin Signed Message:""\\x0a""${msglen}""${msg}" | str2bytes | bytes2hexstr | hash256)"
	echo "Z_VAL :  ${z_val}"

	echo "z1=${z_val}"
	echo "k1x=${r_val}"
	echo "s1=${s_val}"
#	echo "hex=${hexcoresig}"
#	echo "ks1=${hexcoresig:0:2}${r_val}${s_val}"
#	echo "msg len : ${msglen}"
	echo "sighead : ${hexcoresig:0:2}"
	bc 00_config.bc 01_math.bc 02_ecmath.bc 03_ecdsa.bc <<<"recover(${z_val},${r_val},${s_val});" # | grep '269F834F'
	echo
done

