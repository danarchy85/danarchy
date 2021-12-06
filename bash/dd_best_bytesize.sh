#!/bin/bash
outfile=$([[ ${1} ]] && echo ${1} || echo '/tmp/outfile' )
verbose=1
best_bs=''
best_speed=100.0

echo 'Testing bytesizes: 1k 2k 4k 8k 16k 32k 64k 128k 256k 512k 1M 2M 4M 8M'
for bs in 1k 2k 4k 8k 16k 32k 64k 128k 256k 512k 1M 2M 4M 8M ; do
    speed=$(dd if=/dev/zero ibs=1M count=32 of=${outfile} obs=${bs} 2>&1 | awk '/bytes/ {print$8}')

    if [[ $(bc <<< "${speed} <= ${best_speed}") -eq 1 ]]; then
        echo "Found new best speed: ${speed} | bs=${bs}"
        best_speed=${speed}
        best_bs=${bs}
    elif [[ ${verbose} == 1 ]]; then
        echo "Found slower speed:   ${speed} | bs=${bs}"
    fi
done

echo -e "---\nRun dd with bs=${best_bs}"
rm ${outfile}
