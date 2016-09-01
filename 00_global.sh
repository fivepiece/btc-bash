#!/bin/bash

set_network_versions() {
    
    case "${1}" in
        
        bitcoin)
            export privkeyVer="80"
            export p2pkhVer="00"
            export p2shVer="05"
            export xpubVer="0488B21E"
            export xprvVer="0488ADE4"
            export clientname="bitcoin"
            ;;

        testnet)
            export privkeyVer="EF"
            export p2pkhVer="6F"
            export p2shVer="C4"
            export xpubVer="043587CF"
            export xprvVer="04358394"
            export clientname="testnet"
            ;;
    
        segnet)
            export privkeyVer="9E"
            export p2pkhVer="1E"
            export p2shVer="32"
            export xpubVer="043587CF"
            export xprvVer="04358394"
            export clientname="segnet"
            ;;

        regtest)
            export privkeyVer="EF"
            export p2pkhVer="6F"
            export p2shVer="C4"
            export xpubVer="043587CF"
            export xprvVer="04358394"
            export clientname="regtest"
            ;;
        
    esac
}

set_hashfun_const() {

    case "${1}" in

        sha224)
            export hashDecLen="28"
            export hashByteLen="1C"
            export hashWordLen="38"
            export hashBlockLen="80"
            export hashfun="sha224"
            ;;
        sha256)
            export hashDecLen="32"
            export hashByteLen="20"
            export hashWordLen="40"
            export hashBlockLen="80"
            export hashfun="sha256"
            export hmacVDecLen="32"
            export hmacKeyWordLen="40"
            ;;
        sha384)
            export hashDecLen="48"
            export hashByteLen="30"
            export hashWordLen="60"
            export hashBlockLen="100"
            export hashfun="sha384"
            ;;
        sha512)
            export hashDecLen="64"
            export hashByteLen="40"
            export hashWordLen="80"
            export hashBlockLen="100"
            export hashfun="sha512"
            ;;
    esac
}

set_network_versions "regtest"
set_hashfun_const "sha256"

export sources_root="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export BC_LINE_LENGTH=0
export BC_ENV_ARGS="-q\
 ${sources_root}/bc/00_config.bc\
 ${sources_root}/bc/99_hash.bc\
 ${sources_root}/bc/99_bitcoin.bc\
 ${sources_root}/bc/99_logic.bc\
 ${sources_root}/bc/01_math.bc\
 ${sources_root}/bc/02_ecmath.bc\
 ${sources_root}/bc/03_ecdsa.bc"\

source "${sources_root}/01_strings.sh"
source "${sources_root}/02_hash.sh"
source "${sources_root}/03_encode.sh"
source "${sources_root}/04_tx.sh"
source "${sources_root}/04_schnorr.sh"
source "${sources_root}/04_bip32.sh"
source "${sources_root}/05_borr.sh"
source "${sources_root}/99_script.sh"
