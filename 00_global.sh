#!/bin/bash

activevers(){

	privkeyVer="${mprivkeyVer}"
	p2pkhVer="${mp2pkhVer}"
	p2shVer="${mp2shVer}"
}


bitcoinvers() {

	# mainnet
	
	export mprivkeyVer="80"
	export mp2pkhVer="00"
	export mp2shVer="05"
	export mxpubVer="0488B21E"
	export mxprvVer="0488ADE4"

	# testnet

	export tprivkeyVer="EF"
	export tp2pkhVer="6F"
	export tp2shVer="C4"
	export txpubVer="043587CF"
	export txprvVer="04358394"

	# segnet

	export sprivkeyVer="9E"
	export sp2pkhVer="1E"
	export sp2shVer="32"
}

bitcoinlens() {

	export hlen="20"      # hash digest size in bytes
	export keysize="40"   # key size in words
	export hashblock="80" # hash block size words

	export vsize="32"     # v,k size in bytes, base 10

	export hashfun="sha256"
}

bitcoinvers
bitcoinlens
activevers

export sources_root="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export BC_LINE_LENGTH=0
export BC_ENV_ARGS="-q\
 ${sources_root}/bc/00_config.bc\
 ${sources_root}/bc/99_hash.bc\
 ${sources_root}/bc/99_bitcoin.bc\
 ${sources_root}/bc/01_math.bc\
 ${sources_root}/bc/02_ecmath.bc\
 ${sources_root}/bc/03_ecdsa.bc"

source "${sources_root}/01_strings.sh"
source "${sources_root}/02_hash.sh"
source "${sources_root}/03_encode.sh"
source "${sources_root}/04_tx.sh"
source "${sources_root}/04_schnorr.sh"
source "${sources_root}/05_borr.sh"
source "${sources_root}/99_script.sh"
