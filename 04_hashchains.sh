#!/bin/bash

_hc_16to2()
{
    local OIFS="$IFS"
    local -u b2="${1}"
    read b2 < <( BC_ENV_ARGS="-q" bc <<<"obase=2; ibase=16; ${b2}" ) # | rev
    IFS='%'
    read b2 < <( printf "%0${2}s%s\n" ${b2} )
    # read b2 < <( printf "%s%0$(( ${2}-${#b2} ))s\n" ${b2} )
    if (( ${#b2} > ${2} )); then
        echo "hc_16to2() value too large"
        return 1
    fi
    echo "${b2//$' '/0}"
    IFS="$OIFS"
}

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

_hc_2to16()
{
    local OIFS="$IFS"
    IFS='%'
    local b2="${1}"
    read b2 < <( BC_ENV_ARGS="-q" bc <<<"obase=16; ibase=2; ${b2}" )
    read b2 < <( printf "%0${2}s%s\n" ${b2} )
    echo "${b2//$' '/0}" 
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
    local -u val="${1}"
    read val < <( hc_16to2 "${val}" 64 )
    val="${val//*1}"
    echo "${#val}"
}
# sender's tree

_hc_generate_from_seed()
{
    local -u value index
    read value < <( hc_16to2 "${1}" 256 )
    read index < <( hc_16to2 "${2}" 256 )

    echo "value : ${value}"
    echo "index : ${index}"
    echo "----------------------------------------------------------------"
    #for (( i=207, j=63; i<256; i++, j=(63-i) )); do
    for (( i=255, j=63; i>=207; i--, j=(63-i) )); do

        if [[ "${index:${i}:1}" == 1 ]]; then
            
            #echo "value : ${value}"
            echo
            #echo -e "value : ${value:0:$i}\e[31m${value:$i:1}\e[0m${value:$((i+1))}"
            echo "value : ${value:0:$i}[${value:$i:1}]${value:$((i+1))}"
            echo "index : ${index}"
            #echo "i     : ${i}"
            echo "bit    : $(( 255-i ))"
            read bit < <( hc_flip "${value:$i:1}" )
            #echo "bit   : ${bit}"
            #echo -e "flip  : ${value:0:$i}\e[31m${bit}\e[0m${value:$((i+1))}"
            echo -e "flip  : ${value:0:$i}[${bit}]${value:$((i+1))}"
            read value < <( echo "${value:0:$i}${bit}${value:$((i+1))}" )
            read value < <( hc_2to16 "${value}" 64 revbytes )
            read value < <( revbytes "${value}" 2 )
            echo "pre h : ${value}"
            read value < <( sha256 "${value}" )
            echo "hash  : ${value}"
            read value < <( hc_16to2 "${value}" 256 )
            read value < <( revbytes "${value}" 8 )
            #echo "value : ${value}"
        fi
    done

    echo -e "\nfinal 2  : \n${value}\nfinal 16 : "
    hc_2to16 "${value}" "64" | revbytes; echo
}

hc_generate_from_seed()
{
    local -u value="${1}" index="${2}"
    read value < <( revbytes "${1}" 2 )
    #read index < <( revbytes "${2}" 2 )
    read value < <( hc_16to2 "${value}" 256 )
    read index < <( hc_16to2 "${index}" 48 )

    echo "value : ${value}"
    echo "index : ${index}"
    echo "----------------------------------------------------------------"
    #for (( i=207, j=63; i<256; i++, j=(63-i) )); do
    for (( i=0, j=0, k=$((256-48)); i<49; i++, j++, k++ )); do

        if [[ "${index:${j}:1}" == 1 ]]; then
            
            echo
            #echo -e "value : ${value:0:$j}\e[31m${value:$j:1}\e[0m${value:$((j+1))}"
            echo -e "value : ${value:0:$k}\e[31m${value:$k:1}\e[0m${value:$((k+1))}"
            #echo "value : ${value:0:$i}[${value:$i:1}]${value:$((i+1))}"
            echo -e "index : ${index:0:$j}\e[31m${index:$j:1}\e[0m${index:$((j+1))}"
            #echo "i     : ${i}"
            echo "bit    : ${j}"
            read bit < <( hc_flip "${value:$k:1}" )
            #echo "bit   : ${bit}"
            echo -e "flip  : ${value:0:$k}\e[31m${bit}\e[0m${value:$((k+1))}"
            #echo "flip  : ${value:0:$i}[${bit}]${value:$((i+1))}"
            read value < <( echo "${value:0:$k}${bit}${value:$((k+1))}" )
            read value < <( hc_2to16 "${value}" 64 )
            read value < <( revbytes "${value}" 2 )
            echo "pre h : ${value}"
            read value < <( sha256 "${value}" )
            echo "hash  : ${value}"
            read value < <( revbytes "${value}" 2 )
            read value < <( hc_16to2 "${value}" 256 )
            #read value < <( revbytes "${value}" 8 )
            #echo "value : ${value}"
        fi
    done

    echo -e "\nfinal 2  : \n${value}\nfinal 16 : "
    hc_2to16 "${value}" "64" | revbytes; echo
}

# receiver's tree

hc_can_derive()
{
    local -u from_index="${1}" to_index="${2}"
    local -i i
    read from_index < <( hc_16to2 "${from_index}" 64 )
    read to_index < <( hc_16to2 "${to_index}" 64 )
    read i < <( hc_count_trailing_zeros "${1}" )

    for (( i; i<64; i++ )); do

        if [[ "${from_index:$i:1}" == 1 ]] && [[ ! "${to_index:$i:1}" != 1 ]]; then
            echo false && return 1
        fi
    done

    echo true && return 0
}

hc_derive()
{
    local -u from_index="${1}" to_index="${2}" from_value="${3}" value

    if ! hc_can_derive "${from_index}" "${to_index}"; then
        echo "hc_can_derive() assert failed"
        return 1
    fi

    read from_index < <( hc_16to2 "${from_index}" 64 )
    read to_index < <( hc_16to2 "${to_index}" 64 )
    read value < <( hc_16to2 "${from_value}" 256 )
    for (( i=0; i<64; i++ )); do

        if (( ${from_index:$i:1} )) && (( ! ${to_index:$i:1} )); then

            read value < <( hc_flip_bit_in_value "${value}" "${i}" )
            read value < <( hc_2to16 "${value}" 64 )
            read value < <( sha256 "${value}" )
            read value < <( hc_16to2 "${value}" 256 )
        fi
    done

    hc_2to16 ${value} 64
}

hc_receive_value()
{
    local -u index="${1}" value="${2}"
    local -i pos
    read pos < <( hc_count_trailing_zeros "${index}" )

    for (( i=0; i<${pos}; i++ )); do

        # derive "${
        false
    done
    return true
}

hc_regenerate_value()
{
    echo failed
}


