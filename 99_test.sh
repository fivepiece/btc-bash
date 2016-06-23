#!/bin/bash

testhmac() {

	local -u key data

	key="0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B"
	read data < <( echo -n "Hi There" | str2bytes | bytes2hexstr )
#	data="4869205468657265"
	hmac "${key}" "${data}"

	read key < <( echo -n "Jefe" | str2bytes | bytes2hexstr )
#	key="4A656665"
	read data < <( echo -n "what do ya want for nothing?" | str2bytes | bytes2hexstr )
#	data="7768617420646F2079612077616E7420666F72206E6F7468696E673F"	
	hmac "${key}" "${data}"

	key="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
	data="DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD"
	hmac "${key}" "${data}"

	key="0102030405060708090A0B0C0D0E0F10111213141516171819"
	data="CDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCDCD"
	hmac "${key}" "${data}"

	key="0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C0C"
	read data < <( echo -n "Test With Truncation" | str2bytes | bytes2hexstr )
#	data="546573742057697468205472756E636174696F6E"
	hmac "${key}" "${data}"

	key="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
	read data < <( echo -n "Test Using Larger Than Block-Size Key - Hash Key First" | str2bytes | bytes2hexstr )
#	data="54657374205573696E67204C6172676572205468616E20426C6F636B2D53697A65204B6579202D2048617368204B6579204669727374"
	hmac "${key}" "${data}"

	key="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
	read data < <( echo -n "This is a test using a larger than block-size key and a larger than block-size data. The key needs to be hashed before being used by the HMAC algorithm." | str2bytes | bytes2hexstr )
#	data="5468697320697320612074657374207573696E672061206C6172676572207468616E20626C6F636B2D73697A65206B657920616E642061206C6172676572207468616E20626C6F636B2D73697A6520646174612E20546865206B6579206E6565647320746F20626520686173686564206265666F7265206265696E6720757365642062792074686520484D414320616C676F726974686D2E"
	hmac "${key}" "${data}"
}

testrfc6979(){

	local -u key data msg
	local -au kval

	key="1"
	read data < <( echo -n "Satoshi Nakamoto" | str2bytes | bytes2hexstr )
#	data="5361746F736869204E616B616D6F746F"	
	read msg < <( sha256 "${data}" )
	readarray -t kval < <( sigk "${key}" "${data}" )
	bc <<<"sign(${kval[1]},${kval[0]},${msg},${key},nn)"

	key="1"
	read data < <( echo -n "All those moments will be lost in time, like tears in rain. Time to die..." | str2bytes | bytes2hexstr )
#	data="416C6C2074686F7365206D6F6D656E74732077696C6C206265206C6F737420696E2074696D652C206C696B6520746561727320696E207261696E2E2054696D6520746F206469652E2E2E"
	read msg < <( sha256 "${data}" )
	readarray -t kval < <( sigk "${key}" "${data}" )
	bc <<<"sign(${kval[1]},${kval[0]},${msg},${key},nn)"

	key="FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364140"
	read data < <( echo -n "Satoshi Nakamoto" | str2bytes | bytes2hexstr )
#       data="5361746F736869204E616B616D6F746F"
	read msg < <( sha256 "${data}" )
	readarray -t kval < <( sigk "${key}" "${data}" )
	bc <<<"sign(${kval[1]},${kval[0]},${msg},${key},nn)"

	key="F8B8AF8CE3C7CCA5E300D33939540C10D45CE001B8F252BFBC57BA0342904181"
	read data < <( echo -n "Alan Turing" | str2bytes | bytes2hexstr )
#	data="416C616E20547572696E67"
	read msg < <( sha256 "${data}" )
	readarray -t kval < <( sigk "${key}" "${data}" )
	bc <<<"sign(${kval[1]},${kval[0]},${msg},${key},nn)"
}
