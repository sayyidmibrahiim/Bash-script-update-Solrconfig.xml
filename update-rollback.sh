#!/bin/bash
pwd=$(pwd)
DATE=$(date +%Y%m%d)
dirzk=$(jcmd | grep zookeeper-solr | awk '{print$3}')
port_zk=$(grep clientPort $dirzk | cut -d "=" -f 2)
ip=$(hostname -I | awk '{print$1}')
solr_dir=$(ps -ef | grep "Dsolr.solr.home" | grep -v grep  | awk '{print$49}' | awk 'NR==1{print$1}' | cut -d "=" -f 2)
solr_port=$(ps -ef | grep -v grep | grep "Dsolr.jetty.https.port=" | awk '{print$41}' | cut -d '=' -f 2 | awk 'NR==1{print$1}')
action=$1

if [ -z "$action" ]; then
        echo "================================================================="
        echo "How to user this script:"
        echo "./upload-rollback.sh update = for update new solrconfig.xml"
        echo "./upload-rollback.sh rollback = for rollback old solrconfig.xml"
        echo "================================================================="
        exit
elif [[ "$action" == "upload" ]] || [[ "$action" == "reload" ]]; then
        echo "================================================================="
        echo "---------------------please wait the process---------------------"
        echo "================================================================="
else
        echo "================================================================="
        echo "Cara pake scriptnya:"
        echo "./upload-rollback.sh update = untuk update"
        echo "./upload-rollback.sh rollback = untuk rollback"
        echo "================================================================="
        exit
fi

declare -a arr=(
`awk '1' $pwd/list.txt`
)

if [[ "$action" == "update" ]]; then
        echo "----------------Updateing new solrconfig.xml---------------------"
        echo "================================================================="
        for collections in "${arr[@]}"
        do
                echo "--> update solrconfig.xml for collection $collections"
                $solr_dir/bin/solr zk cp $pwd/solrconfig-edited/$collections/solrconfig.xml zk:/configs/$collections/ -z $ip:$port_zk
                echo "--> reload collection $collections"
                curl --user {username}:{password} "http://$ip:$solr_port/solr/admin/collections?action=RELOAD&name=$collections" > /dev/null 2>&1
        done
elif [[ "$action" == "rollback" ]]; then
        echo "-------------------Rollback old solrconfig.xml-------------------"
        echo "================================================================="
        for collections in "${arr[@]}"
        do
                echo "--> rollback solrconfig.xml for collection $collections"
                $solr_dir/solr/bin/solr zk cp $pwd/solrconfig-bkp/$collections/solrconfig.xml zk:/configs/$collections/ -z $ip:$port_zk
                echo "--> reload collection $collections"
                curl --user {username}:{password} "http://$ip:$solr_port/solr/admin/collections?action=RELOAD&name=$collections" > /dev/null 2>&1
        done
fi
