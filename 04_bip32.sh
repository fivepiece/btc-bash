#!/bin/bash

bip32_point()
{
    bc <<<"ecmulcurve(${1},ggx,ggy,nn,pp); print tx, \"\n\", ty;"
}

bip32_parse_index()
{
    local index="${1}"

    if [[ "${index}" =~ "h" ]]
    then
	    index="$(( ${index//h/} + 2147483648 ))"
    fi

    echo "${index}"
}

bip32_ser32()
{
    bc <<<"ibase=A; \
	   num=${1^^}; \
       ibase=16; \
	   pad(num,8);"
}

bip32_ser256()
{
    bc <<<"pad(${1^^},40);"
}

bip32_ckdpriv()
{
    local -u k_par="${1}" c_par="${2}" n="${3}" I_val
    set_hashfun_const "sha512"

    read n < <( bip32_parse_index "${n}" )

    local -u ser_k ser_i ser_p
    if (( ${n} >= 2147483648 ))
    then
	    read ser_k < <( bip32_ser256 "${k_par}" )
	    read ser_i < <( bip32_ser32 "${n}" )
	    read I_val < <( hmac "${c_par}" "00${ser_k}${ser_i}" )
    else
	    readarray -t point_k < <( bip32_point "${k_par}" )
	    read ser_p < <( compresspoint "${point_k[0]}" "${point_k[1]}" )
	    read ser_i < <( bip32_ser32 "${n}" )
	    read I_val < <( hmac "${c_par}" "${ser_p}${ser_i}" )
    fi

    local -u I_L I_R k_i c_i

    I_L="${I_val:0:64}"
    I_R="${I_val:64}"

    read k_i < <( bc <<<" \
	    if ( ${I_L} == 0 ){ \
		0; \
	    } else { \
	        pad(mod( ${I_L} + ${k_par}, nn),40); }" )
    if [[ "${k_i}" == "0" ]]
    then
	    bip32_ckdpriv "${k_par}" "${c_par}" "$(( ${n}+1 ))"
	    return
    fi

    c_i="${I_R}"
    echo -e "${k_i}\n${c_i}"
}

bip32_ckdpub()
{
    local -u p_par="${1}" c_par="${2}" n="${3}"
    set_hashfun_const "sha512"
    
    read n < <( bip32_parse_index "${n}" )

    local -u ser_i I_val
    if (( "${n}" >= 2147483648 ))
    then
	    echo "FAILURE"
	    return
    else
	    read ser_i < <( bip32_ser32 "${n}" )
	    read I_val < <( hmac "${c_par}" "${p_par}${ser_i}" )
    fi

    local -u I_L I_R k_i c_i
    local -au p_upk

    readarray -t p_upk < <( uncompresspoint "${p_par}" )

    I_L="${I_val:0:64}"
    I_R="${I_val:64}"

    read p_i < <( bc <<<" \
	    if ( ${I_L} == 0 ){ \
		    0; \
	    } else { \
	        ecmulcurve(${I_L},ggx,ggy,nn,pp); \
		ecaddcurve(tx,ty,${p_upk[0]},${p_upk[1]},pp); \
		if ( rx == 0 ){ \
			0; \
		} else {
    			compresspoint(rx,ry); } }" )
    if [[ "${p_i}" == "0" ]]
    then
	    bip32_ckdpub "${p_par}" "${c_par}" "$(( ${n}+1 ))"
    fi

    c_i="${I_R}"
    echo -e "${p_i}\n${c_i}"
}

bip32_master()
{
    local -u data="${1}" bip32_key="426974636F696E2073656564" # 'Bitcoin seed'
    set_hashfun_const "sha512"

    local -u I_val I_R I_L

    read I_val < <( hmac "${bip32_key}" "${data}" )
    I_L="${I_val:0:64}"
    I_R="${I_val:64}"

    echo -e "${I_L}\n${I_R}"
}

bip32_neuter()
{
    if [[ "${1}" == "" ]]
    then
	    read hex_xpriv
    else
	    hex_xpriv="${1}"
    fi

    local -au data
    readarray -t data < <( bip32_decode "${hex_xpriv}" )

    local -au k_upk
    local -u k_i
    readarray -t k_upk < <( bip32_point "${data[5]}" )
    read k_i < <( compresspoint "${k_upk[0]}" "${k_upk[1]}" )

    echo "${xpubVer}${data[1]}${data[2]}${data[3]}${data[4]}${k_i}"
}

bip32_decode()
{
    local -u hexstr
    local -au xkey

    if [[ "${1}" == "" ]]
    then
	    read hexstr
    else
	    hexstr="${1}"
    fi

    xkey[0]="${hexstr:0:8}"   # magic
    xkey[1]="${hexstr:8:2}"   # depth
    xkey[2]="${hexstr:10:8}"  # parent fingerprint
    xkey[3]="${hexstr:18:8}"  # child number
    xkey[4]="${hexstr:26:64}" # chain code
    xkey[5]="${hexstr:90:66}" # private / public key

    printf "%s\n" "${xkey[@]}"
}

bip32_encode()
{
    local -a hexstr xkey256
    if [[ "${1}" == "" ]]
    then
	    read hexstr
    else
	    hexstr="${1}"
    fi

    read xkey256 < <( hash256 "${hexstr}" )

    base58enc "${hexstr}${xkey256:0:8}" && echo
}

bip32_encode_master()
{
    local -au data
    if [[ "${1}" == "" ]]
    then
	    readarray -t data
    else
	    data[0]="${1}"
	    data[1]="${2}"
    fi

    echo "${xprvVer}000000000000000000${data[1]}00${data[0]}"
}

bip32_xpriv_branch()
{
    local -u par_xpriv
    if [[ "${2}" == "" ]]
    then
	    read par_xpriv
	    read index < <( bip32_parse_index "${1}" )
    else
	    par_xpriv="${1}"
	    read index < <( bip32_parse_index "${2}" )
    fi

    local -au data next_ckey
    readarray -t data < <( bip32_decode "${par_xpriv}" )

    if [[ "${data[5]:0:2}" != "00" ]]
    then
	    echo "FAILURE xpub -> xpriv"
	    return
    fi

    local -au par_point
    local -u par_fp next_depth next_i

    readarray -t par_point < <( bip32_point "${data[5]}" )
    read par_fp < <( compresspoint "${par_point[0]}" "${par_point[1]}" | hash160 )

    read next_depth < <( bc <<<"pad(${data[1]} + 1,2)" )

    read next_i < <( bip32_ser32 "${index}" )
    
    readarray -t next_ckey < <( bip32_ckdpriv "${data[5]:2}" "${data[4]}" "${index}" )

    echo "${xprvVer}${next_depth}${par_fp:0:8}${next_i}${next_ckey[1]}00${next_ckey[0]}"
}

bip32_xpub_branch()
{
    local -u par_xpub
    if [[ "${2}" == "" ]]
    then
	    read par_xpub
	    read index < <( bip32_parse_index "${1}" )
    else
	    par_xpub="${1}"
	    read index < <( bip32_parse_index "${2}" )
    fi

    local -au data next_ckey
    readarray -t data < <( bip32_decode "${par_xpub}" )

    if [[ "${data[5]:0:2}" != "02" ]] && [[ "${data[5]:0:2}" != "03" ]]
    then
	    echo "FAILURE not an xpub"
	    return
    fi

    local -au par_point
    local -u par_fp next_depth next_i

    read par_fp < <( hash160 "${data[5]}" )

    read next_depth < <( bc <<<"pad(${data[1]} + 1,2)" )

    read next_i < <( bip32_ser32 "${index}" )
    
    readarray -t next_ckey < <( bip32_ckdpub "${data[5]}" "${data[4]}" "${index}" )

    echo "${xpubVer}${next_depth}${par_fp:0:8}${next_i}${next_ckey[1]}${next_ckey[0]}"
}
