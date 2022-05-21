#!/bin/bash

function getHash()
{
    wget $1 -q -O temp
    hash=$(openssl dgst -sha256 -binary temp | openssl base64 -A)
    rm -rf temp
    echo $hash
}

function testCDN()
{
    sourceHash=$1
    source=$2
    target=$3
    #fastly jsdelivr
    if [ "$target" == "fastly" ];then
        host="$target.jsdelivr.net"
        #如果是cdn.jsdelivr.net
        target=$(echo $source | sed -r "s/https:\/\/cdn.jsdelivr.net\/npm\/([^\s]*)/https:\/\/$host\/npm\/\1/")
        #如果是cdn.jsdelivr.net（Github）
        target=$(echo $target | sed -r "s/https:\/\/cdn.jsdelivr.net\/gh\/([^\s]*)/https:\/\/$host\/gh\/\1/")
        #如果是unpkg.com
        target=$(echo $target | sed -r "s/https:\/\/unpkg.com\/([^\s]*)/https:\/\/$host\/npm\/\1/")
    fi
    #unpkg
    if [ "$target" == "unpkg" ];then
        host="unpkg.com"
        #如果是*.jsdelivr.net
        target=$(echo $source | sed -r "s/https:\/\/([^\s]*).jsdelivr.net\/npm\/([^\s]*)/https:\/\/$host\/\2/")
    fi
    #bootcdn
    if [ "$target" == "bootcdn" ];then
        host="cdn.bootcdn.net"
        #如果是*.jsdelivr.net带版本
        target=$(echo $source | sed -r "s/https:\/\/([^\s]*).jsdelivr.net\/npm\/(.*?)@(.*?)\/(.*?)/https:\/\/$host\/ajax\/libs\/\2\/\3\/\4/")
    fi
    if [ -z "$2" ];then
        source=""
    fi
    if [ "$target" != "$source" ];then
        targetHash=$(getHash $target)
        if [ "$targetHash" == "$sourceHash" ];then
            echo $target
        fi
    fi
}

function getCDN()
{
    hash=$(getHash $1)
    echo "Get：$1"
    echo "【Hash】$hash"
    cdns=("fastly" "unpkg" "bootcdn")
    urls=()
    for cdn in ${cdns[*]}
    do
        url=$(testCDN $hash $1 $cdn)
        if [ -n "$url" ];then
            echo "【CDN】【$cdn】：$url"
            urls+=($url)
        fi
    done
    if [ ${#urls[@]} > 0  ];then
        echo -e "$1" >> freecdn-manifest.txt
        for url in ${urls[*]}
        do
            echo -e "\t$url" >> freecdn-manifest.txt
        done
    fi
    echo ""
    # cdn1=$(testCDN $hash $1 fastly)
    # cdn2=$(testCDN $hash $1 unpkg)
    # cdn3=$(testCDN $hash $1 bootcdn)
    # echo "【CDN】fastly url:$cdn1"
    # echo "【CDN】unpkg url:$cdn2"
    # echo "【CDN】bootcdn url:$cdn3"
    # echo ""
    # if [ -n "$cdn1" ] || [ -n "$cdn2" ] || [ -n "$cdn3" ] ; then
    #     echo -e "$1" >> freecdn-manifest.txt
    #     if [ "$cdn1" ];then
    #         echo -e "\t$cdn1" >> freecdn-manifest.txt
    #      fi
    #     if [ "$cdn2" ];then
    #         echo -e "\t$cdn2" >> freecdn-manifest.txt
    #     fi
    #     if [ "$cdn3" ];then
    #         echo -e "\t$cdn3" >> freecdn-manifest.txt
    #     fi
    #     echo -e "\thash=$hash" >> freecdn-manifest.txt
    # fi
}

if [ -z "$1" ];then
    echo "请传入链接列表文件，以便生成清单"
else
    rm -rf freecdn-manifest.txt
    for line in $(cat $1)
    do
        if [[ $line != "#"* ]] && [ "$line" ];then
            getCDN $line
            echo "" >> freecdn-manifest.txt
        fi
    done
fi