#!/bin/bash

# echo HEX | hex2bin : BIN
# hex2bin HEX : BIN
hex2bin() {

    local -l hexstr

    if [[ "${1}" == "" ]]
    then
        read hexstr
    else
        hexstr="${1}"
    fi
# set +xv
    local -al bytearr
    local -i i=0
    while read -N2 byte
    do
#        echo "byte : ${byte}"
        bytearr+=( '\x'${byte} )

    done <<<"${hexstr}"
# set -xv
    printf "%b" ${bytearr[*]}
}

# echo STR | str2bytes : " BYTE BYTE..."
# str2bytes <<<"STR" : " BYTE BYTE... 0x0A"
# str2bytes FILE : " BYTE BYTE..."
alias str2bytes="od -t x1 -An -v -w1"
alias bin2hex="hexdump -v -e '\"\" 1/1 \"%02X\" \"\"'"

# echo " BYTE BYTE..." | bytes2hexstr : BYTEBYE...
# bytes2hex " BYTE BYTE" : BYTEBYTE...
bytes2hexstr() {
    
    local -u bytestr
    if [[ "${1}" == "" ]]
    then
        readarray -t bytestr

    else
        bytestr="${1}"
    fi

    printf "%s" ${bytestr[*]}
}

# echo BYTE[0]BYTE[1]...BYTE[n] | revbytes : BYTE[n]BYTE[n-1]...BYTE[0]
# revbytes BYTE[0]BYTE[1]...BYTE[n] : BYTE[n]BYTE[n-1]...BYTE[0]
revbyteorder() {

    local -u hexstr
    if [[ "${1}" == "" ]]
    then
        read hexstr
    else
        hexstr="${1}"
    fi

    if (( "${#hexstr}" % 2 == 1 ))
    then
        hexstr="0${hexstr}"
    fi

    local -a revstr
    for (( i=$(( ${#hexstr}-2 )); i>=0; i-- ))
    do
        revstr+=( ${hexstr:$(( i*2 )):2} )
    done

    revstr=${revstr[@]//$'\n'/}
    revstr=${revstr^^}
    printf "${revstr// /}"
}
