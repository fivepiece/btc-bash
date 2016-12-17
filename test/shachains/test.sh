#!/bin/bash

unset i v16 v256 v16to2_256 v16to2_48 vseeds vleafs

#./gen_vectors.sh > vectors.sh
source ./vectors.sh
source ../../04_shachains.sh

t16to2()
{
    local i v16

    for i in ${!v16to2_48[@]}; do

        read v16 < <( hc_16to2 "${i}" 48 )
        [[ "${v16}" == "${v16to2_48[$i]}" ]] || echo "t16to2_48, ${v16} != ${v16to2_48[$i]}" #|| return 1
    done

    unset i v16 
    
    for i in ${!v16to2_256[@]}; do

        read v16 < <( hc_16to2 "${i}" 256 )
        [[ "${v16}" == "${v16to2_256[$i]}" ]] || echo "t16to2_256, ${v16} != ${v16to2_256[$i]}" #|| return 1
    done
}

t2to16()
{
    local i v256

    for i in ${!v2to16_48[@]}; do

        read v256 < <( hc_2to16 "${i}" 12 )
        [[ "${v256}" == "${v2to16_48[$i]}" ]] || echo "t2to16_48, ${v256} != ${v2to16_48[$i]}" #|| return 1
    done

    unset i v256
    
    for i in ${!v16to2_256[@]}; do

        read v256 < <( hc_2to16 "${i}" 64 )
        [[ "${v16}" == "${v2to16_256[$i]}" ]] || echo "t2to16_256, ${v256} != ${v2to16_256[$i]}" #|| return 1
    done
}

tgenerate_from_seed()
{
    for i in ${!vseeds[@]}; do

        vseed="${vseeds[$i]}"
        vidx="${vleafs[$i]}"
        read vleaf < <( hc_generate_from_seed "${vseeds[$i]}" "${vleafs[$i]}" )
        [[ "${vseeds[${vleaf}]}" == "${vseeds[$i]}" ]] && [[ "${vleafs[${vleaf}]}" == "${vleafs[$i]}" ]] || \
            echo "tgenerate_fromseed, [[ "${vseeds[${vleaf}]}" != "${vseeds[$i]}" ]] || [[ "${vleafs[${vleaf}]}" != "${vleafs[$i]}" ]]"
    done
}
#unset i i16 v16 v16to2_256 v16to2_48
#rm ./vectors.sh
