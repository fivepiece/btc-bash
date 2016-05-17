#!/bin/bash

declare -A _stringCode
_stringCode=([A]=09 [B]=10 [C]=11 [D]=12 [E]=13 [F]=14 [G]=15 [H]=16 \
	     [J]=17 [K]=18 [L]=19 [M]=20 [N]=21 [P]=22 [Q]=23 [R]=24 \
	     [S]=25 [T]=26 [U]=27 [V]=28 [W]=29 [X]=30 [Y]=31 [Z]=32 \
	     [a]=33 [b]=34 [c]=35 [d]=36 [e]=37 [f]=38 [g]=39 [h]=40 \
	     [i]=41 [j]=42 [k]=43 [m]=44 [n]=45 [o]=46 [p]=47 [q]=48 \
	     [1]=00 [r]=49 [2]=1 [s]=50 [3]=2 [t]=51 [4]=3 [u]=52 [5]=4 \
	     [v]=53 [6]=5 [w]=54 [7]=6 [x]=55 [8]=7 [y]=56 [9]=8 [z]=57)

_codeString=(1 2 3 4 5 6 7 8 9 A B C D E F G H J K \
	     L M N P Q R S T U V W X Y Z a b c d e \
	     f g h i j k m n o p q r s t u v w x y z)

activevers(){

	privkeyVer="${sprivkeyVer}"
	p2pkhVer="${sp2pkhVer}"
	p2shVer="${sp2shVer}"
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
}

bitcoinvers
bitcoinlens
activevers
source '/home/esh/software/git/bitcoin-bash/01_strings.sh'
source '/home/esh/software/git/bitcoin-bash/02_hash.sh'
source '/home/esh/software/git/bitcoin-bash/03_encode.sh'
source '/home/esh/software/git/bitcoin-bash/04_tx.sh'
source '/home/esh/software/git/bitcoin-bash/99_script.sh'
