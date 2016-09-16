#!/bin/bash

script_run_op()
{
    local -a script=( ${1} ) subscript stack altstack
    local ptr="${script[0]}" opcode elem
    local -i size=0


