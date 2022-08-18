#!/bin/bash
pwd=$(pwd)
DATE=$(date +%Y%m%d)
dirzk=$(jcmd | grep zookeeper-solr | awk '{print$3}')
port_zk=$(grep clientPort $dirzk | cut -d "=" -f 2)
ip=$(hostname -I | awk '{print$1}')
solr_dir=$(ps -ef | grep "Dsolr.solr.home" | grep -v grep  | awk '{print$49}' | awk 'NR==1{print$1}' | cut -d "=" -f 2)
solr_port=$(ps -ef | grep -v grep | grep "Dsolr.jetty.https.port=" | awk '{print$41}' | cut -d '=' -f 2 | awk 'NR==1{print$1}')

echo "======================================================="
echo "----------------------please wait----------------------"
echo "======================================================="

#Sort SOLR collections
echo "1. sort all the collections into list.txt..."
$solr_dir/bin/solr zk ls zk:/configs/ -z localhost:$port_zk | sort > $pwd/list.txt

#pulling solrconfig.xml
echo "2. pulling solrconfig.xml from all collections..."
declare -a arr=(
`awk '1' $pwd/list.txt`
)

mkdir $pwd/solrconfig-bkp
for collections in "${arr[@]}"
do
        mkdir $pwd/solrconfig-bkp/$collections
        $solr_dir/bin/solr zk cp zk:/configs/$collections/solrconfig.xml $pwd/solrconfig-bkp/$collections -z $ip:$port_zk > /dev/null 2>&1
done
        cp -r $pwd/solrconfig-bkp $pwd/solrconfig-edited

#Beautify XML
echo "3. beautify solrconfig.xml..."
for collections in "${arr[@]}"
do
        xmllint --format $pwd/solrconfig-edited/$collections/solrconfig.xml > $pwd/solrconfig-edited/$collections/solrconfig-beauty.xml
done

#another necessary config
echo "4. another necessary config..."
for collections in "${arr[@]}"
do
        mv $pwd/solrconfig-edited/$collections/solrconfig-beauty.xml $pwd/solrconfig-edited/$collections/solrconfig.xml > /dev/null 2>&1
done

#Remove Some Config in solrconfig.xml
echo "5. removing suggestion request handler configuration in solrconfig.xml..."
for collections in "${arr[@]}"
do
        line_start=$(awk '/suggestion request handler/{ print NR; exit }' $pwd/solrconfig-edited/$collections/solrconfig.xml)
        line_end=$(expr $line_start + 24)
        sed -i "$line_start,$line_end d" $pwd/solrconfig-edited/$collections/solrconfig.xml > /dev/null 2>&1
done

#Checking...
echo "6. Checking..."
for collections in "${arr[@]}"
do
cek=$(grep "suggestion request handler" $pwd/solrconfig-edited/$collections/solrconfig.xml)
if [ -z "$cek" ]; then
sleep 0.1
else
echo "  --> suggestion request handler config has not been deleted in collection $collections!"
fi
done

echo "======================================================="
echo "---------------------process complete------------------"
echo "======================================================="
