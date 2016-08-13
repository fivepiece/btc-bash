#!/bin/bash

declare -A output_ser
output_ser[amount]=""
output_ser[scriptlen]=""
output_ser[script]=""

declare -A input_obj
input_obj[txid]=""
input_obj[vout]=""
input_obj[scriptPubKey]=""
input_obj[redeemScript]=""
input_obj[amount]=""

declare -A tx_wit
tx_wit[npush]=""
tx_wit[serwit]=""

declare -A wit_ser
wit_ser[witlen]=""
wit_ser[witness]=""

declare -A tx_ver
tx_ver[version]=""
tx_ver[witdummy]=""
tx_ver[witflags]=""

declare -A tx_ser
tx_ser[version]=""
tx_ser[vins]=""
tx_ser[inputs]=""
tx_ser[vouts]=""
tx_ser[outputs]=""
tx_ser[vwits]=""
tx_ser[witness]=""
tx_ser[nlocktime]=""

declare -A tx_in
tx_in[serin]=""
tx_in[amount]=""

source ./script.sh
source ./wallet.sh
source ./transaction.sh
source ./script_num.sh
