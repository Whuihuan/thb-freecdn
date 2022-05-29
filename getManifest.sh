#!/bin/bash
#set -eo pipefail

urlPath=$1
outPath=$2
if [ -z "$outPath" ];then
    outPath=""
fi

function getHash()
{
    #set -eo pipefail
    if [ ! -d "temp" ];then
        mkdir temp
    fi
    wget $1 -q -t 3 -T 10 -O temp/temp
    hash=$(openssl dgst -sha256 -binary temp/temp | openssl base64 -A)
    echo $hash
}

function cleanTemp()
{
    #set -eo pipefail
    rm -rf temp
}

function writeTxt()
{
    #set -eo pipefail
    echo -e "$1" >> ${outPath}freecdn-manifest.txt
}

function wirteFile()
{
    #set -eo pipefail
    cat  $1 >> ${outPath}freecdn-manifest.txt
}


function cleanTxt()
{
    #set -eo pipefail
    rm -rf ${outPath}freecdn-manifest.txt
}

function testCDN()
{
    #set -eo pipefail
    sourceHash=$1
    source=$2
    target=$3
    targetUrl=""

    ####### CDN #######

    # fastly jsdelivr
    if [ "$target" == "fastly" ];then
        host="$target.jsdelivr.net"
        # cdn.jsdelivr.net
        targetUrl=$(echo $source | sed -r "s/https:\/\/cdn.jsdelivr.net\/npm\/([^\s]*)/https:\/\/$host\/npm\/\1/")
        # cdn.jsdelivr.net (github)
        targetUrl=$(echo $targetUrl | sed -r "s/https:\/\/cdn.jsdelivr.net\/gh\/([^\s]*)/https:\/\/$host\/gh\/\1/")
        # unpkg.com
        targetUrl=$(echo $targetUrl | sed -r "s/https:\/\/unpkg.com\/([^\s]*)/https:\/\/$host\/npm\/\1/")
    fi

    # unpkg
    if [ "$target" == "unpkg" ];then
        host="unpkg.com"
        # *.jsdelivr.net
        targetUrl=$(echo $source | sed -r "s/https:\/\/([^\s]*).jsdelivr.net\/npm\/([^\s]*)/https:\/\/$host\/\2/")
    fi

    # elemecdn
    if [ "$target" == "elemecdn" ];then
        host="npm.elemecdn.com"
        # *.jsdelivr.net
        targetUrl=$(echo $source | sed -r "s/https:\/\/([^\s]*).jsdelivr.net\/npm\/([^\s]*)/https:\/\/$host\/\2/")
        # unpkg.com
        targetUrl=$(echo $targetUrl | sed -r "s/https:\/\/unpkg.com\/([^\s]*)/https:\/\/$host\/\1/")
    fi

    # bootcdn
    if [ "$target" == "bootcdn" ];then
        host="cdn.bootcdn.net"
        # *.jsdelivr.net with version
        targetUrl=$(echo $source | sed -r "s/https:\/\/([^\s]*).jsdelivr.net\/npm\/(.*?)@(.*?)\/(.*?)/https:\/\/$host\/ajax\/libs\/\2\/\3\/\4/")
        # unpkg.com with version
        targetUrl=$(echo $targetUrl | sed -r "s/https:\/\/unpkg.com\/(.*?)@(.*?)\/(.*?)/https:\/\/$host\/ajax\/libs\/\1\/\2\/\3/")
    fi

    # staticfile
    if [ "$target" == "staticfile" ];then
        host="cdn.staticfile.org"
        # *.jsdelivr.net with version
        targetUrl=$(echo $source | sed -r "s/https:\/\/([^\s]*).jsdelivr.net\/npm\/(.*?)@(.*?)\/(.*?)/https:\/\/$host\/\2\/\3\/\4/")
        # unpkg.com with version
        targetUrl=$(echo $targetUrl | sed -r "s/https:\/\/unpkg.com\/(.*?)@(.*?)\/(.*?)/https:\/\/$host\/\1\/\2\/\3/")
    fi

    # loli
    if [ "$target" == "loli" ];then
        host="cdnjs.loli.net"
        # *.jsdelivr.net with version
        targetUrl=$(echo $source | sed -r "s/https:\/\/([^\s]*).jsdelivr.net\/npm\/(.*?)@(.*?)\/(.*?)/https:\/\/$host\/ajax\/libs\/\2\/\3\/\4/")
        # unpkg.com with version
        targetUrl=$(echo $targetUrl | sed -r "s/https:\/\/unpkg.com\/(.*?)@(.*?)\/(.*?)/https:\/\/$host\/ajax\/libs\/\1\/\2\/\3/")
    fi

    # cloudflare
    if [ "$target" == "cloudflare" ];then
        host="cdnjs.cloudflare.com"
        # *.jsdelivr.net with version
        targetUrl=$(echo $source | sed -r "s/https:\/\/([^\s]*).jsdelivr.net\/npm\/(.*?)@(.*?)\/(.*?)/https:\/\/$host\/ajax\/libs\/\2\/\3\/\4/")
        # unpkg.com with version
        targetUrl=$(echo $targetUrl | sed -r "s/https:\/\/unpkg.com\/(.*?)@(.*?)\/(.*?)/https:\/\/$host\/ajax\/libs\/\1\/\2\/\3/")
    fi

    ####### END #######

    if [ -z "$2" ];then
        source=""
    fi
    if [ "$targetUrl" != "$source" ] && [ -n "$targetUrl" ];then
        if [ "$target" != "fastly" ] && [ "$target" != "unpkg" ] && [ "$target" != "elemecdn" ];then
            targetUrl=$(echo $targetUrl | sed 's/dist\///g')
        fi
        targetHash=$(getHash $targetUrl)
        if [ "$targetHash" == "$sourceHash" ];then
            echo $targetUrl
        fi
    fi
}

function getCDN()
{
    #set -eo pipefail
    getCDNStart=`date "+%Y-%m-%d %H:%M:%S"`
    origin=$1
    originArr=$(echo "$origin" | awk '{split($0,arr,",");for(i in arr) print arr[i]}')
    originArr=($originArr)
    if [ -z "${originArr[0]}" ];then
        echo "Error resource url."
    else
        resUrl=${originArr[0]}
        echo "Get：$resUrl"
        hash=$(getHash $resUrl)
        echo "【Hash】$hash"
        cdns=("fastly" "unpkg" "elemecdn" "bootcdn" "staticfile" "loli" "cloudflare")
        urls=()
        for cdn in ${cdns[*]}
        do
            url=$(testCDN $hash $resUrl $cdn)
            if [ -n "$url" ];then
                echo "【CDN】【$cdn】：$url"
                urls+=($url)
            fi
        done
        if [ ${#urls[@]} -gt 0  ];then
            writeTxt "$resUrl"
            for url in ${urls[*]}
            do
                writeTxt "\t$url"
            done
            for i in $(seq 0 ${#originArr[@]})
            do
                if [ "$i" == "0" ];then
                    continue
                fi
                param=${originArr[$i]}
                if [ -n "$param" ];then
                    writeTxt "\t$param"
                fi
            done
            writeTxt "\thash=$hash"
        fi
        getCDNEnd=`date "+%Y-%m-%d %H:%M:%S"`
        getCDNDuration=`echo $(($(date +%s -d "${getCDNEnd}") - $(date +%s -d "${getCDNStart}"))) | awk '{t=split("60 s 60 m 24 h 999 d",a);for(n=1;n<t;n+=2){if($1==0)break;s=$1%a[n]a[n+1]s;$1=int($1/a[n])}print s}'`
        echo "【TIME】： $getCDNDuration"
        echo ""
    fi
}

if [ -z "$urlPath" ];then
    echo "No url list readed."
else
    getStart=`date "+%Y-%m-%d %H:%M:%S"`
    cleanTxt
    for line in $(cat $urlPath)
    do
        if [[ $line != "#"* ]] && [ "$line" ];then
            getCDN $line
            writeTxt ""
        fi
    done
    wirteFile params.txt
    cleanTemp
    echo ""
    getEnd=`date "+%Y-%m-%d %H:%M:%S"`
    getDuration=`echo $(($(date +%s -d "${getEnd}") - $(date +%s -d "${getStart}"))) | awk '{t=split("60 s 60 m 24 h 999 d",a);for(n=1;n<t;n+=2){if($1==0)break;s=$1%a[n]a[n+1]s;$1=int($1/a[n])}print s}'`
    echo "【TIME】： $getDuration"
fi