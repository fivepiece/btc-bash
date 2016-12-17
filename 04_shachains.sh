#!/bin/bash

hc_16to2()
{
    local OIFS="$IFS"
    local -u b2="${1}"
    #read b2 < <( revbytes "${b2}" 2 )
    read b2 < <( BC_ENV_ARGS="-q" bc <<<"obase=2; ibase=16; ${b2}" ) # | rev
    IFS='%'
    read b2 < <( printf "%0${2}s%s\n" ${b2} )
    #read b2 < <( printf "%s%0$(( ${2}-${#b2} ))s\n" ${b2} )
    if (( ${#b2} > ${2} )); then
        echo "hc_16to2() value too large"
        return 1
    fi
    echo "${b2//$' '/0}" #| rev
    IFS="$OIFS"
}

hc_2to16()
{
    local OIFS="$IFS"
    IFS='%'
    local b2="${1}"
    #read b2 < <( echo "${b2}" | rev )
    #read b2 < <( revbytes "${b2}" 1 )
    read b2 < <( BC_ENV_ARGS="-q" bc <<<"obase=16; ibase=2; ${b2}" )
    read b2 < <( printf "%0${2}s%s\n" ${b2} )
    #read b2 < <( printf "%s%0$(( ${2}-${#b2} ))s\n" ${b2} )
    echo "${b2//$' '/0}" 
    IFS="$OIFS"
}

hc_flip()
{
    if [[ "${1}" == 1 ]]; then
        echo 0
    else
        echo 1
    fi
}

hc_flip_bit_in_value()
{
    local value="${1}"
    local -i i="${2}" bit
    read bit < <( hc_flip "${value:$i:1}" )
    
    echo -e "${value:0:$i}${bit}${value:$((i+1))}"
}

hc_count_trailing_zeros()
{
    local -u val="${1}" prefix
    read val < <( hc_16to2 "${val}" 48 )
    # echo "input  : ${val}" 1>&2
    # echo "output : ${val%1*}" 1>&2
    prefix="${val%1*}"
    echo -e "\
$((47-${#prefix}))\n\
${prefix}\n\
${val}" # 1>&2
}

# sender's tree

hc_generate_from_seed()
{
    local -u value="${1}" index="${2}"
    read value < <( revbytes "${1}" 2 )
    read value < <( hc_16to2 "${value}" 256 )
    read index < <( hc_16to2 "${index}" 48 )

    decho "\n----------------------------------------------------------------\n"
    decho "value : ${value}"
    decho "index : ${index}"
    decho "----------------------------------------------------------------\n"
    for (( i=0, j=0, k=$((256-48)); i<48; i++, j++, k++ )); do

        if [[ "${index:${j}:1}" == 1 ]]; then
            
            decho "value : ${value:0:$k}\e[31m${value:$k:1}\e[0m${value:$((k+1))}"
            decho "index : ${index:0:$j}\e[31m${index:$j:1}\e[0m${index:$((j+1))}"
            decho "bit   : ${j}"
            read bit < <( hc_flip "${value:$k:1}" )
            decho "flip  : ${value:0:$k}\e[31m${bit}\e[0m${value:$((k+1))}"
            value="${value:0:$k}${bit}${value:$((k+1))}"
            read value < <( hc_2to16 "${value}" 64 )
            read value < <( revbytes "${value}" 2 )
            decho "pre h : ${value}"
            read value < <( sha256 "${value}" )
            decho "hash  : ${value}"
            read value < <( revbytes "${value}" 2 )
            read value < <( hc_16to2 "${value}" 256 )
        fi
    done

    decho "\nfinal 2  : \n${value}\nfinal 16 : "
    read value < <( hc_2to16 "${value}" "64" )
    revbytes "${value}" 2 ; echo
}

# receiver's tree

hc_can_derive()
{
    #local -u from_index="${1}" to_index="${2}"
    local -au k1 k2
    #read from_index < <( hc_16to2 "${from_index}" 48 )
    #read to_index < <( hc_16to2 "${to_index}" 48 )
    readarray -t k1 < <( hc_count_trailing_zeros "${1}" )
    readarray -t k2 < <( hc_count_trailing_zeros "${2}" )
    
    #echo "${k1}, ${k2:0:${#k1}}" 1>&2
    
    if [[ "${k1[1]}1" == "${k2[1]:0:$((${#k1[1]}+1))}" ]] || [[ "${1}" == "${2}" ]] || (( ${k1[0]} == -1 )) ; then
        echo -e "\
${k1[0]}\n\
${k1[1]}\n\
${k1[2]}\n\
${k2[0]}\n\
${k2[1]}\n\
${k2[2]}" # ugh..
        return 0
    else
        echo -e "\
49\n\
${k1[1]}\n\
${k1[2]}\n\
49\n\
${k2[1]}\n\
${k2[2]}" # :(
        return 1
    fi
}

hc_derive()
{
    #local -u from_index="${1}" to_index="${2}" from_value value
    local -u from_index to_index from_value value
    local -au from_to

    readarray -t from_to < <( hc_can_derive "${1}" "${2}" )
    #if ! hc_can_derive "${from_index}" "${to_index}"; then
    if [[ "${from_to}" == 49 ]]; then
        echo "hc_can_derive() assert failed" 1>&2
        return 1
    fi

    read from_value < <( revbytes "${3}" 2 )
    #read from_index < <( hc_16to2 "${from_index}" 48 )
    from_index="${from_to[2]}"
    #read to_index < <( hc_16to2 "${to_index}" 48 )
    to_index="${from_to[5]}"
    read value < <( hc_16to2 "${from_value}" 256 )
    decho "\n----------------------------------------------------------------\n"
    decho "from_value : ${3}"
    decho "from_index : ${from_index}"
    decho "to_index   : ${to_index}"
    decho "----------------------------------------------------------------\n"
    #for (( i=${lz}, k=$(( 208+lz )); i<48; i++, k++ )); do
    #for (( i=47, k=255; i>=0; i--, k-- )); do
    for (( i=0, j=0, k=$((256-48)); j<48; i++, j++, k++ )); do

        if [[ ${to_index:$i:1} == 1 ]] && [[ ${from_index:$i:1} != 1 ]]; then

            decho "value      : ${value:0:$k}\e[31m${value:$k:1}\e[0m${value:$((k+1))}"
            decho "from_index : ${from_index:0:$i}\e[31m${from_index:$i:1}\e[0m${from_index:$((i+1))}"
            decho "to_index   : ${to_index:0:$i}\e[31m${to_index:$i:1}\e[0m${to_index:$((i+1))}"
            decho "bit        : $i"
            read value < <( hc_flip_bit_in_value "${value}" "${k}" )
            decho "flip       : ${value:0:$k}\e[31m${value:$k:1}\e[0m${value:$((k+1))}" 
            read value < <( hc_2to16 "${value}" 64 )
            read value < <( revbytes "${value}" 2 )
            decho "pre h      : ${value}"
            read value < <( sha256 "${value}" )
            decho "hash       : ${value}"
            read value < <( revbytes "${value}" 2 )
            read value < <( hc_16to2 "${value}" 256 )
        fi
    done

    decho "\nfinal 2  : \n${value}\nfinal 16 : "
    read value < <( hc_2to16 "${value}" 64 )
    revbytes "${value}" 2; echo
    return 0
}

hc_receive_value()
{
    local -u index="${1}" value="${2}" tval tpos
    local -au tknown=( ${3} ) tknown_value tknown_index pos
    decho "tknown : ${tknown[@]}"
    tknown_value=( ${tknown[@]#*,} )
    tknown_index=( ${tknown[@]%,*} )
    decho "tknown_value : ${tknown_value[@]}"
    decho "tknown_index : ${tknown_index[@]}"
    readarray -t pos < <( hc_count_trailing_zeros "${index}" )
    decho "pos : ${pos[0]}"

    for (( i=0; i<${pos[0]}; i++ )); do

        read tval < <( hc_derive "${index}" "${tknown_index[$i]}" "${value}" )
        decho "tval            : ${tval}"
        decho "tknown_value[$i] : ${tknown_value[$i]}"
        if [[ ${tval} != ${tknown_value[$i]} ]]; then
        
            echo "hc_receive_value() failed at insert" 1>&2
            return 1
        fi
    done

    for (( i=0; i<${pos[0]}; i++ )); do

        echo -n "${tknown[$i]} "
    done
    
    echo -n "${index},${value} "

    for (( i=$(( ${pos[0]}+1 )); i<${#tknown[@]}; i++ )); do

        echo -n "${tknown[$i]} "
    done

    echo; return 0
}

hc_regenerate_value()
{
    local -u index="${1}"
    local -au secrets=( ${2} )
    tsecrets_value=( ${secrets[@]#*,} )
    tsecrets_index=( ${secrets[@]%,*} )

    for (( i=0; i<${#secrets[@]}; i++ )); do

        if hc_can_derive "${tsecrets_index[$i]}" "${index}" >/dev/null; then

            hc_derive "${tsecrets_index[$i]}" "${index}" "${tsecrets_value[$i]}"
            return 0
        fi
    done

    echo "hc_regenerate_value() failes" 1>&2
    return 1
}
