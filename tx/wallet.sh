#!/bin/bash

core_gen_keychain () 
{ 
    local addr privkey;
    local -u pubkey;
    rm ./addrs.list ./pubkeys.list ./privkeys.list;
    while read -r line; do
        if [[ ! "${line}" =~ "addr" ]]; then
            continue;
        fi;
        addr="${line#*addr=}";
        addr="${addr% *}";
        read pubkey < <( core_addr2pubkey "${addr}" );
        read privkey < <( core_addr2privkey "${addr}" );
        echo "${addr}" >> addrs.list;
        echo "${pubkey}" >> pubkeys.list;
        echo "${privkey}" >> privkeys.list;
    done < "./corewallet.txt"
}


core_dump_wallet () 
{ 
    "${clientname}"-cli dumpwallet "${PWD}/corewallet.txt"
}


core_get_inputs () 
{ 
    "${clientname}"-cli listunspent > inputs.json
}


core_json_rhs () 
{ 
    local rhs;
    rhs="${1//[ ^\",]/}";
    echo -n "${rhs#*:}"
}


inputs_get_balance () 
{ 
    local balance total="0";
    while read -r line; do
        if [[ ! "${line}" =~ "amount" ]]; then
            continue;
        fi;
        read balance < <( core_json_rhs "${line}" );
        read total < <( BC_ENV_ARGS="" bc <<<"scale=8; \
                                              total=${total}+${balance}; \
                                              total;" );
    done < "./inputs.json";
    echo "${total}"
}


inputs_reduce_balance () 
{ 
    BC_ENV_ARGS="" bc <<< "scale=8; ${1} - ${2};"
}


core_addr2privkey () 
{ 
    "${clientname}"-cli dumpprivkey "${1}"
}


core_addr2pubkey () 
{ 
    local -a retjson;
    readarray retjson < <( "${clientname}"-cli validateaddress "${1}" );
    while read -r line; do
        if [[ ! "${line}" =~ "pubkey" ]]; then
            continue;
        fi;
        core_json_rhs "${line^^}";
    done <<< "${retjson[@]}"
}


key_addr2hash160 () 
{ 
    local -u pubhash;
    read pubhash < <( base58dec "${1}" );
    echo "${pubhash:2:40}"
}


key_hash1602addr () 
{ 
    local -u checksum;
    read checksum < <( hash256 "${p2pkhVer}${1}" );
    base58enc "${p2pkhVer}${1}${checksum:0:8}";
    echo
}


key_priv2pub () 
{ 
    local -u pubkey;
    bc <<< "ecmulcurve("${1}",ggx,ggy,nn,pp); \
            compresspoint(tx,ty);"
}


key_pub2addr () 
{ 
    local addr;
    local -u pubhash;
    read pubhash < <( hash160 "${1}" );
    read checksum < <( hash256 "${p2pkhVer}${pubhash}" );
    base58enc "${p2pkhVer}${pubhash}${checksum:0:8}";
    echo
}


key_wif2priv () 
{ 
    local -u privhex;
    read privhex < <( base58dec "${1}" );
    echo "${privhex:2:64}"
}


key_wif2pub () 
{ 
    local -u privkey pubkey;
    read privkey < <( key_wif2priv "${1}" );
    key_priv2pub "${privkey}"
}
