#!/bin/bash
help() {
        echo ""
        echo "Este script realiza a contagem de ONUs Up, Down e totais por porta PON e do OLT"
	echo "usage: $0 [-c <snmp community>][-i <olt ip address>][-h]"
        echo "Obs.: funciona apenas com OLTs DATACOM (https://www.datacom.com.br/pt/produtos/linha/gpon). Um profile SNMP deve com a configuracao o parametro 'if-oper-status' deve estar associado aos ONUs."
        echo ""
}

if [[ $# -eq 0 ]] ; then
    echo 'Por favor selecione uma opcao valida.' && help;
    exit 0
fi

while getopts c:i:h flag

do      case "${flag}" in
                c) community=${OPTARG};;
                i) ip=${OPTARG};;
                h) help ;;
                *) echo "Opcao invalida: -$flag." ;;
        esac
done

if [[ "$ip" != "" ]] && [[ "$community" != "" ]]; then
initial_date_time=$(date "+%Y-%m-%d %T");
initial_date_time_sec=$(date -u -d "$initial_date_time" +"%s");
##
olt_model=$(snmpget -v2c -c $community -One $ip .1.3.6.1.2.1.1.1.0 | sed 's#.1.3.6.1.2.1.1.1.0 = STRING: ##g' | sed 's#"##g');
hostname=$(snmpget -v2c -c $community -One $ip .1.3.6.1.2.1.1.5.0 | sed 's#.1.3.6.1.2.1.1.5.0 = STRING: ##g' | sed 's#"##g');
# coleta estado de todos os ONUs sem consultar as UNI e armazena em arquivo
snmpbulkwalk -v2c -c $community -One $ip .1.3.6.1.4.1.3709.3.6.2.1.1.7 | while IFS= read -r line; do
   echo $line >> get_pon_onu_"$ip".txt; 
   if [[ $line =~ .1.3.6.1.4.1.3709.3.6.2.1.1.7.33 ]]; then
       # Save the matched text and stop
       # printf "%s\n" "${BASH_REMATCH[0]}"
       break
    fi
done;
# armazena em arquivo ONUs com estado Up
$(cat get_pon_onu_"$ip".txt | grep " INTEGER: 1" > get_pon_onu_up_"$ip".txt);
# armazena em arquivo ONUs com estado Down
$(cat get_pon_onu_"$ip".txt | grep " INTEGER: 2" > get_pon_onu_down_"$ip".txt);
# quantidade de portas pon para percorrer nos lacos for
pon_item_max=16;
if [[ "$olt_model" =~ 'DM4610' ]]; then pon_item_max=8;fi
if [[ "$olt_model" =~ 'DM4611' ]]; then pon_item_max=8;fi
if [[ "$olt_model" =~ 'DM4612' ]]; then pon_item_max=8;fi
if [[ "$olt_model" =~ 'DM4615' ]]; then pon_item_max=16;fi
if [[ "$olt_model" =~ 'DM4618' ]]; then pon_item_max=64;fi
# inicia variveis contadoras com o valor 0 considerando o maximo de 64 PON
for ((pon_item=1; pon_item < 65; ++pon_item));
 do
 declare onu_count_pon$pon_item=0;
 declare onu_count_up_pon$pon_item=0;
 declare onu_count_down_pon$pon_item=0;
done;
# conta ONUs por porta PON
onu_count=$(cat get_pon_onu_"$ip".txt | grep -c .3709.3.6.2.1.1.7.16)
for ((onu_item=1; onu_item < $onu_count+1; ++onu_item));
 do
  onu_index=$(cat get_pon_onu_$ip.txt | sed 's#.1.3.6.1.4.1.3709.3.6.2.1.1.7.##g' | sed 's# = INTEGER: 1##g' | sed 's# = INTEGER: 2##g' | head -n $onu_item | tail -n 1);
  pon_id=$((($onu_index + 1)%256 | bc));
  for ((pon_item=1; pon_item < $pon_item_max+1; ++pon_item));
   do
   if [ $pon_id -eq $pon_item ]; then ((onu_count_pon$pon_item=onu_count_pon$pon_item+1));fi
  done;
done;
rm get_pon_onu_"$ip".txt;
# conta ONUs Up por porta PON
onu_count_up=$(cat get_pon_onu_up_"$ip".txt | grep -c .3709.3.6.2.1.1.7.16)
for ((onu_item=1; onu_item < $onu_count_up+1; ++onu_item));
 do
  onu_index=$(cat get_pon_onu_up_$ip.txt | sed 's#.1.3.6.1.4.1.3709.3.6.2.1.1.7.##g' | sed 's# = INTEGER: 1##g' | head -n $onu_item | tail -n 1);
  pon_id=$((($onu_index + 1)%256 | bc));
  for ((pon_item=1; pon_item < $pon_item_max+1; ++pon_item));
   do
   if [ $pon_id -eq $pon_item ]; then ((onu_count_up_pon$pon_item=onu_count_up_pon$pon_item+1));fi
  done;
done;
rm get_pon_onu_up_"$ip".txt;
# conta ONUs Down por porta PON
onu_count_down=$(cat get_pon_onu_down_"$ip".txt | grep -c .3709.3.6.2.1.1.7.16)
for ((onu_item=1; onu_item < $onu_count_down+1; ++onu_item));
 do
  onu_index=$(cat get_pon_onu_down_$ip.txt | sed 's#.1.3.6.1.4.1.3709.3.6.2.1.1.7.##g' | sed 's# = INTEGER: 2##g' | head -n $onu_item | tail -n 1);
  pon_id=$((($onu_index + 1)%256 | bc));
  for ((pon_item=1; pon_item < $pon_item_max+1; ++pon_item));
   do
   if [ $pon_id -eq $pon_item ]; then ((onu_count_down_pon$pon_item=onu_count_down_pon$pon_item+1));fi
  done;
done;
rm get_pon_onu_down_"$ip".txt;
# exibe hostname e modelo do OLT
echo "";
echo $hostname;
echo $olt_model;
# exibe total de ONUs
echo "";
echo "olt_onu_count = $onu_count"
echo "olt_onu_count_up = $onu_count_up"
echo "olt_onu_count_down = $onu_count_down"
# exibe quantidades de ONUs por porta PON
echo "";
if [[ "$onu_count_pon1" != 0 ]]; then echo "pon 1/1/1 onu_count = $onu_count_pon1";fi
if [[ "$onu_count_pon1" != 0 ]]; then echo "pon 1/1/1 onu_count_up = $onu_count_up_pon1";fi;
if [[ "$onu_count_pon1" != 0 ]]; then echo "pon 1/1/1 onu_count_down = $onu_count_down_pon1";echo "";fi;

if [[ "$onu_count_pon2" != 0 ]]; then echo "pon 1/1/2 onu_count = $onu_count_pon2";fi
if [[ "$onu_count_pon2" != 0 ]]; then echo "pon 1/1/2 onu_count_up = $onu_count_up_pon2";fi;
if [[ "$onu_count_pon2" != 0 ]]; then echo "pon 1/1/2 onu_count_down = $onu_count_down_pon2";echo "";fi;

if [[ "$onu_count_pon3" != 0 ]]; then echo "pon 1/1/3 onu_count = $onu_count_pon3";fi
if [[ "$onu_count_pon3" != 0 ]]; then echo "pon 1/1/3 onu_count_up = $onu_count_up_pon3";fi
if [[ "$onu_count_pon3" != 0 ]]; then echo "pon 1/1/3 onu_count_down = $onu_count_down_pon3";echo "";fi;

if [[ "$onu_count_pon4" != 0 ]]; then echo "pon 1/1/4 onu_count = $onu_count_pon4";fi
if [[ "$onu_count_pon4" != 0 ]]; then echo "pon 1/1/4 onu_count_up = $onu_count_up_pon4";fi
if [[ "$onu_count_pon4" != 0 ]]; then echo "pon 1/1/4 onu_count_down = $onu_count_down_pon4";echo "";fi;

if [[ "$onu_count_pon5" != 0 ]]; then echo "pon 1/1/5 onu_count = $onu_count_pon5";fi
if [[ "$onu_count_pon5" != 0 ]]; then echo "pon 1/1/5 onu_count_up = $onu_count_up_pon5";fi
if [[ "$onu_count_pon5" != 0 ]]; then echo "pon 1/1/5 onu_count_down = $onu_count_down_pon5";echo "";fi;

if [[ "$onu_count_pon6" != 0 ]]; then echo "pon 1/1/6 onu_count = $onu_count_pon6";fi
if [[ "$onu_count_pon6" != 0 ]]; then echo "pon 1/1/6 onu_count_up = $onu_count_up_pon6";fi
if [[ "$onu_count_pon6" != 0 ]]; then echo "pon 1/1/6 onu_count_down = $onu_count_down_pon6";echo "";fi;

if [[ "$onu_count_pon7" != 0 ]]; then echo "pon 1/1/7 onu_count = $onu_count_pon7";fi
if [[ "$onu_count_pon7" != 0 ]]; then echo "pon 1/1/7 onu_count_up = $onu_count_up_pon7";fi
if [[ "$onu_count_pon7" != 0 ]]; then echo "pon 1/1/7 onu_count_down = $onu_count_down_pon7";echo "";fi;

if [[ "$onu_count_pon8" != 0 ]]; then echo "pon 1/1/8 onu_count = $onu_count_pon8";fi
if [[ "$onu_count_pon8" != 0 ]]; then echo "pon 1/1/8 onu_count_up = $onu_count_up_pon8";fi
if [[ "$onu_count_pon8" != 0 ]]; then echo "pon 1/1/8 onu_count_down = $onu_count_down_pon8";echo "";fi;

if [[ "$onu_count_pon9" != 0 ]]; then echo "pon 1/1/9 onu_count = $onu_count_pon9";fi
if [[ "$onu_count_pon9" != 0 ]]; then echo "pon 1/1/9 onu_count_up = $onu_count_up_pon9";fi
if [[ "$onu_count_pon9" != 0 ]]; then echo "pon 1/1/9 onu_count_down = $onu_count_down_pon9";echo "";fi;

if [[ "$onu_count_pon10" != 0 ]]; then echo "pon 1/1/10 onu_count = $onu_count_pon10";fi
if [[ "$onu_count_pon10" != 0 ]]; then echo "pon 1/1/10 onu_count_up = $onu_count_up_pon10";fi
if [[ "$onu_count_pon10" != 0 ]]; then echo "pon 1/1/10 onu_count_down = $onu_count_down_pon10";echo "";fi;

if [[ "$onu_count_pon11" != 0 ]]; then echo "pon 1/1/11 onu_count = $onu_count_pon11";fi
if [[ "$onu_count_pon11" != 0 ]]; then echo "pon 1/1/11 onu_count_up = $onu_count_up_pon11";fi
if [[ "$onu_count_pon11" != 0 ]]; then echo "pon 1/1/11 onu_count_down = $onu_count_down_pon11";echo "";fi;

if [[ "$onu_count_pon12" != 0 ]]; then echo "pon 1/1/12 onu_count = $onu_count_pon12";fi
if [[ "$onu_count_pon12" != 0 ]]; then echo "pon 1/1/12 onu_count_up = $onu_count_up_pon12";fi
if [[ "$onu_count_pon12" != 0 ]]; then echo "pon 1/1/12 onu_count_down = $onu_count_down_pon12";echo "";fi;

if [[ "$onu_count_pon13" != 0 ]]; then echo "pon 1/1/13 onu_count = $onu_count_pon13";fi
if [[ "$onu_count_pon13" != 0 ]]; then echo "pon 1/1/13 onu_count_up = $onu_count_up_pon13";fi
if [[ "$onu_count_pon13" != 0 ]]; then echo "pon 1/1/13 onu_count_down = $onu_count_down_pon13";echo "";fi;

if [[ "$onu_count_pon14" != 0 ]]; then echo "pon 1/1/14 onu_count = $onu_count_pon14";fi
if [[ "$onu_count_pon14" != 0 ]]; then echo "pon 1/1/14 onu_count_up = $onu_count_up_pon14";fi
if [[ "$onu_count_pon14" != 0 ]]; then echo "pon 1/1/14 onu_count_down = $onu_count_down_pon14";echo "";fi;

if [[ "$onu_count_pon15" != 0 ]]; then echo "pon 1/1/15 onu_count = $onu_count_pon15";fi
if [[ "$onu_count_pon15" != 0 ]]; then echo "pon 1/1/15 onu_count_up = $onu_count_up_pon15";fi
if [[ "$onu_count_pon15" != 0 ]]; then echo "pon 1/1/15 onu_count_down = $onu_count_down_pon15";echo "";fi;

if [[ "$onu_count_pon16" != 0 ]]; then echo "pon 1/1/16 onu_count = $onu_count_pon16";fi
if [[ "$onu_count_pon16" != 0 ]]; then echo "pon 1/1/16 onu_count_up = $onu_count_up_pon16";fi
if [[ "$onu_count_pon16" != 0 ]]; then echo "pon 1/1/16 onu_count_down = $onu_count_down_pon16";echo "";fi;

if [[ "$onu_count_pon17" != 0 ]]; then echo "pon 1/1/17 onu_count = $onu_count_pon17";fi
if [[ "$onu_count_pon17" != 0 ]]; then echo "pon 1/1/17 onu_count_up = $onu_count_up_pon17";fi;
if [[ "$onu_count_pon17" != 0 ]]; then echo "pon 1/1/17 onu_count_down = $onu_count_down_pon17";echo "";fi;

if [[ "$onu_count_pon18" != 0 ]]; then echo "pon 1/1/18 onu_count = $onu_count_pon18";fi
if [[ "$onu_count_pon18" != 0 ]]; then echo "pon 1/1/18 onu_count_up = $onu_count_up_pon18";fi;
if [[ "$onu_count_pon18" != 0 ]]; then echo "pon 1/1/18 onu_count_down = $onu_count_down_pon18";echo "";fi;

if [[ "$onu_count_pon19" != 0 ]]; then echo "pon 1/1/19 onu_count = $onu_count_pon19";fi
if [[ "$onu_count_pon19" != 0 ]]; then echo "pon 1/1/19 onu_count_up = $onu_count_up_pon19";fi
if [[ "$onu_count_pon19" != 0 ]]; then echo "pon 1/1/19 onu_count_down = $onu_count_down_pon19";echo "";fi;

if [[ "$onu_count_pon20" != 0 ]]; then echo "pon 1/1/20 onu_count = $onu_count_pon20";fi
if [[ "$onu_count_pon20" != 0 ]]; then echo "pon 1/1/20 onu_count_up = $onu_count_up_pon20";fi
if [[ "$onu_count_pon20" != 0 ]]; then echo "pon 1/1/20 onu_count_down = $onu_count_down_pon20";echo "";fi;

if [[ "$onu_count_pon21" != 0 ]]; then echo "pon 1/1/21 onu_count = $onu_count_pon21";fi
if [[ "$onu_count_pon21" != 0 ]]; then echo "pon 1/1/21 onu_count_up = $onu_count_up_pon21";fi
if [[ "$onu_count_pon21" != 0 ]]; then echo "pon 1/1/21 onu_count_down = $onu_count_down_pon21";echo "";fi;

if [[ "$onu_count_pon22" != 0 ]]; then echo "pon 1/1/22 onu_count = $onu_count_pon22";fi
if [[ "$onu_count_pon22" != 0 ]]; then echo "pon 1/1/22 onu_count_up = $onu_count_up_pon22";fi
if [[ "$onu_count_pon22" != 0 ]]; then echo "pon 1/1/22 onu_count_down = $onu_count_down_pon22";echo "";fi;

if [[ "$onu_count_pon23" != 0 ]]; then echo "pon 1/1/23 onu_count = $onu_count_pon23";fi
if [[ "$onu_count_pon23" != 0 ]]; then echo "pon 1/1/23 onu_count_up = $onu_count_up_pon23";fi
if [[ "$onu_count_pon23" != 0 ]]; then echo "pon 1/1/23 onu_count_down = $onu_count_down_pon23";echo "";fi;

if [[ "$onu_count_pon24" != 0 ]]; then echo "pon 1/1/24 onu_count = $onu_count_pon24";fi
if [[ "$onu_count_pon24" != 0 ]]; then echo "pon 1/1/24 onu_count_up = $onu_count_up_pon24";fi
if [[ "$onu_count_pon24" != 0 ]]; then echo "pon 1/1/24 onu_count_down = $onu_count_down_pon24";echo "";fi;

if [[ "$onu_count_pon25" != 0 ]]; then echo "pon 1/1/25 onu_count = $onu_count_pon25";fi
if [[ "$onu_count_pon25" != 0 ]]; then echo "pon 1/1/25 onu_count_up = $onu_count_up_pon25";fi
if [[ "$onu_count_pon25" != 0 ]]; then echo "pon 1/1/25 onu_count_down = $onu_count_down_pon25";echo "";fi;

if [[ "$onu_count_pon26" != 0 ]]; then echo "pon 1/1/26 onu_count = $onu_count_pon26";fi
if [[ "$onu_count_pon26" != 0 ]]; then echo "pon 1/1/26 onu_count_up = $onu_count_up_pon26";fi
if [[ "$onu_count_pon26" != 0 ]]; then echo "pon 1/1/26 onu_count_down = $onu_count_down_pon26";echo "";fi;

if [[ "$onu_count_pon27" != 0 ]]; then echo "pon 1/1/27 onu_count = $onu_count_pon27";fi
if [[ "$onu_count_pon27" != 0 ]]; then echo "pon 1/1/27 onu_count_up = $onu_count_up_pon27";fi
if [[ "$onu_count_pon27" != 0 ]]; then echo "pon 1/1/27 onu_count_down = $onu_count_down_pon27";echo "";fi;

if [[ "$onu_count_pon28" != 0 ]]; then echo "pon 1/1/28 onu_count = $onu_count_pon28";fi
if [[ "$onu_count_pon28" != 0 ]]; then echo "pon 1/1/28 onu_count_up = $onu_count_up_pon28";fi
if [[ "$onu_count_pon28" != 0 ]]; then echo "pon 1/1/28 onu_count_down = $onu_count_down_pon28";echo "";fi;

if [[ "$onu_count_pon29" != 0 ]]; then echo "pon 1/1/29 onu_count = $onu_count_pon29";fi
if [[ "$onu_count_pon29" != 0 ]]; then echo "pon 1/1/29 onu_count_up = $onu_count_up_pon29";fi
if [[ "$onu_count_pon29" != 0 ]]; then echo "pon 1/1/29 onu_count_down = $onu_count_down_pon29";echo "";fi;

if [[ "$onu_count_pon30" != 0 ]]; then echo "pon 1/1/30 onu_count = $onu_count_pon30";fi
if [[ "$onu_count_pon30" != 0 ]]; then echo "pon 1/1/30 onu_count_up = $onu_count_up_pon30";fi
if [[ "$onu_count_pon30" != 0 ]]; then echo "pon 1/1/30 onu_count_down = $onu_count_down_pon30";echo "";fi;

if [[ "$onu_count_pon31" != 0 ]]; then echo "pon 1/1/31 onu_count = $onu_count_pon31";fi
if [[ "$onu_count_pon31" != 0 ]]; then echo "pon 1/1/31 onu_count_up = $onu_count_up_pon31";fi
if [[ "$onu_count_pon31" != 0 ]]; then echo "pon 1/1/31 onu_count_down = $onu_count_down_pon31";echo "";fi;

if [[ "$onu_count_pon32" != 0 ]]; then echo "pon 1/1/32 onu_count = $onu_count_pon32";fi
if [[ "$onu_count_pon32" != 0 ]]; then echo "pon 1/1/32 onu_count_up = $onu_count_up_pon32";fi
if [[ "$onu_count_pon32" != 0 ]]; then echo "pon 1/1/32 onu_count_down = $onu_count_down_pon32";echo "";fi;

if [[ "$onu_count_pon33" != 0 ]]; then echo "pon 1/2/1 onu_count = $onu_count_pon33";fi
if [[ "$onu_count_pon33" != 0 ]]; then echo "pon 1/2/1 onu_count_up = $onu_count_up_pon33";fi;
if [[ "$onu_count_pon33" != 0 ]]; then echo "pon 1/2/1 onu_count_down = $onu_count_down_pon33";echo "";fi;

if [[ "$onu_count_pon34" != 0 ]]; then echo "pon 1/2/2 onu_count = $onu_count_pon34";fi
if [[ "$onu_count_pon34" != 0 ]]; then echo "pon 1/2/2 onu_count_up = $onu_count_up_pon34";fi;
if [[ "$onu_count_pon34" != 0 ]]; then echo "pon 1/2/2 onu_count_down = $onu_count_down_pon34";echo "";fi;

if [[ "$onu_count_pon35" != 0 ]]; then echo "pon 1/2/3 onu_count = $onu_count_pon35";fi
if [[ "$onu_count_pon35" != 0 ]]; then echo "pon 1/2/3 onu_count_up = $onu_count_up_pon35";fi
if [[ "$onu_count_pon35" != 0 ]]; then echo "pon 1/2/3 onu_count_down = $onu_count_down_pon35";echo "";fi;

if [[ "$onu_count_pon36" != 0 ]]; then echo "pon 1/2/4 onu_count = $onu_count_pon36";fi
if [[ "$onu_count_pon36" != 0 ]]; then echo "pon 1/2/4 onu_count_up = $onu_count_up_pon36";fi
if [[ "$onu_count_pon36" != 0 ]]; then echo "pon 1/2/4 onu_count_down = $onu_count_down_pon36";echo "";fi;

if [[ "$onu_count_pon37" != 0 ]]; then echo "pon 1/2/5 onu_count = $onu_count_pon37";fi
if [[ "$onu_count_pon37" != 0 ]]; then echo "pon 1/2/5 onu_count_up = $onu_count_up_pon37";fi
if [[ "$onu_count_pon37" != 0 ]]; then echo "pon 1/2/5 onu_count_down = $onu_count_down_pon37";echo "";fi;

if [[ "$onu_count_pon38" != 0 ]]; then echo "pon 1/2/6 onu_count = $onu_count_pon38";fi
if [[ "$onu_count_pon38" != 0 ]]; then echo "pon 1/2/6 onu_count_up = $onu_count_up_pon38";fi
if [[ "$onu_count_pon38" != 0 ]]; then echo "pon 1/2/6 onu_count_down = $onu_count_down_pon38";echo "";fi;

if [[ "$onu_count_pon39" != 0 ]]; then echo "pon 1/2/7 onu_count = $onu_count_pon39";fi
if [[ "$onu_count_pon39" != 0 ]]; then echo "pon 1/2/7 onu_count_up = $onu_count_up_pon39";fi
if [[ "$onu_count_pon39" != 0 ]]; then echo "pon 1/2/7 onu_count_down = $onu_count_down_pon39";echo "";fi;

if [[ "$onu_count_pon40" != 0 ]]; then echo "pon 1/2/8 onu_count = $onu_count_pon40";fi
if [[ "$onu_count_pon40" != 0 ]]; then echo "pon 1/2/8 onu_count_up = $onu_count_up_pon40";fi
if [[ "$onu_count_pon40" != 0 ]]; then echo "pon 1/2/8 onu_count_down = $onu_count_down_pon40";echo "";fi;

if [[ "$onu_count_pon41" != 0 ]]; then echo "pon 1/2/9 onu_count = $onu_count_pon41";fi
if [[ "$onu_count_pon41" != 0 ]]; then echo "pon 1/2/9 onu_count_up = $onu_count_up_pon41";fi
if [[ "$onu_count_pon41" != 0 ]]; then echo "pon 1/2/9 onu_count_down = $onu_count_down_pon41";echo "";fi;

if [[ "$onu_count_pon42" != 0 ]]; then echo "pon 1/2/10 onu_count = $onu_count_pon42";fi
if [[ "$onu_count_pon42" != 0 ]]; then echo "pon 1/2/10 onu_count_up = $onu_count_up_pon42";fi
if [[ "$onu_count_pon42" != 0 ]]; then echo "pon 1/2/10 onu_count_down = $onu_count_down_pon42";echo "";fi;

if [[ "$onu_count_pon43" != 0 ]]; then echo "pon 1/2/11 onu_count = $onu_count_pon43";fi
if [[ "$onu_count_pon43" != 0 ]]; then echo "pon 1/2/11 onu_count_up = $onu_count_up_pon43";fi
if [[ "$onu_count_pon43" != 0 ]]; then echo "pon 1/2/11 onu_count_down = $onu_count_down_pon43";echo "";fi;

if [[ "$onu_count_pon44" != 0 ]]; then echo "pon 1/2/12 onu_count = $onu_count_pon44";fi
if [[ "$onu_count_pon44" != 0 ]]; then echo "pon 1/2/12 onu_count_up = $onu_count_up_pon44";fi
if [[ "$onu_count_pon44" != 0 ]]; then echo "pon 1/2/12 onu_count_down = $onu_count_down_pon44";echo "";fi;

if [[ "$onu_count_pon45" != 0 ]]; then echo "pon 1/2/13 onu_count = $onu_count_pon45";fi
if [[ "$onu_count_pon45" != 0 ]]; then echo "pon 1/2/13 onu_count_up = $onu_count_up_pon45";fi
if [[ "$onu_count_pon45" != 0 ]]; then echo "pon 1/2/13 onu_count_down = $onu_count_down_pon45";echo "";fi;

if [[ "$onu_count_pon46" != 0 ]]; then echo "pon 1/2/14 onu_count = $onu_count_pon46";fi
if [[ "$onu_count_pon46" != 0 ]]; then echo "pon 1/2/14 onu_count_up = $onu_count_up_pon46";fi
if [[ "$onu_count_pon46" != 0 ]]; then echo "pon 1/2/14 onu_count_down = $onu_count_down_pon46";echo "";fi;

if [[ "$onu_count_pon47" != 0 ]]; then echo "pon 1/2/15 onu_count = $onu_count_pon47";fi
if [[ "$onu_count_pon47" != 0 ]]; then echo "pon 1/2/15 onu_count_up = $onu_count_up_pon47";fi
if [[ "$onu_count_pon47" != 0 ]]; then echo "pon 1/2/15 onu_count_down = $onu_count_down_pon47";echo "";fi;

if [[ "$onu_count_pon48" != 0 ]]; then echo "pon 1/2/16 onu_count = $onu_count_pon48";fi
if [[ "$onu_count_pon48" != 0 ]]; then echo "pon 1/2/16 onu_count_up = $onu_count_up_pon48";fi
if [[ "$onu_count_pon48" != 0 ]]; then echo "pon 1/2/16 onu_count_down = $onu_count_down_pon48";echo "";fi;

if [[ "$onu_count_pon49" != 0 ]]; then echo "pon 1/2/17 onu_count = $onu_count_pon49";fi
if [[ "$onu_count_pon49" != 0 ]]; then echo "pon 1/2/17 onu_count_up = $onu_count_up_pon49";fi;
if [[ "$onu_count_pon49" != 0 ]]; then echo "pon 1/2/17 onu_count_down = $onu_count_down_pon49";echo "";fi;

if [[ "$onu_count_pon50" != 0 ]]; then echo "pon 1/2/18 onu_count = $onu_count_pon50";fi
if [[ "$onu_count_pon50" != 0 ]]; then echo "pon 1/2/18 onu_count_up = $onu_count_up_pon50";fi;
if [[ "$onu_count_pon50" != 0 ]]; then echo "pon 1/2/18 onu_count_down = $onu_count_down_pon50";echo "";fi;

if [[ "$onu_count_pon51" != 0 ]]; then echo "pon 1/2/19 onu_count = $onu_count_pon51";fi
if [[ "$onu_count_pon51" != 0 ]]; then echo "pon 1/2/19 onu_count_up = $onu_count_up_pon51";fi
if [[ "$onu_count_pon51" != 0 ]]; then echo "pon 1/2/19 onu_count_down = $onu_count_down_pon51";echo "";fi;

if [[ "$onu_count_pon52" != 0 ]]; then echo "pon 1/2/20 onu_count = $onu_count_pon52";fi
if [[ "$onu_count_pon52" != 0 ]]; then echo "pon 1/2/20 onu_count_up = $onu_count_up_pon52";fi
if [[ "$onu_count_pon52" != 0 ]]; then echo "pon 1/2/20 onu_count_down = $onu_count_down_pon52";echo "";fi;

if [[ "$onu_count_pon53" != 0 ]]; then echo "pon 1/2/21 onu_count = $onu_count_pon53";fi
if [[ "$onu_count_pon53" != 0 ]]; then echo "pon 1/2/21 onu_count_up = $onu_count_up_pon53";fi
if [[ "$onu_count_pon53" != 0 ]]; then echo "pon 1/2/21 onu_count_down = $onu_count_down_pon53";echo "";fi;

if [[ "$onu_count_pon54" != 0 ]]; then echo "pon 1/2/22 onu_count = $onu_count_pon54";fi
if [[ "$onu_count_pon54" != 0 ]]; then echo "pon 1/2/22 onu_count_up = $onu_count_up_pon54";fi
if [[ "$onu_count_pon54" != 0 ]]; then echo "pon 1/2/22 onu_count_down = $onu_count_down_pon54";echo "";fi;

if [[ "$onu_count_pon55" != 0 ]]; then echo "pon 1/2/23 onu_count = $onu_count_pon55";fi
if [[ "$onu_count_pon55" != 0 ]]; then echo "pon 1/2/23 onu_count_up = $onu_count_up_pon55";fi
if [[ "$onu_count_pon55" != 0 ]]; then echo "pon 1/2/23 onu_count_down = $onu_count_down_pon55";echo "";fi;

if [[ "$onu_count_pon56" != 0 ]]; then echo "pon 1/2/24 onu_count = $onu_count_pon56";fi
if [[ "$onu_count_pon56" != 0 ]]; then echo "pon 1/2/24 onu_count_up = $onu_count_up_pon56";fi
if [[ "$onu_count_pon56" != 0 ]]; then echo "pon 1/2/24 onu_count_down = $onu_count_down_pon56";echo "";fi;

if [[ "$onu_count_pon57" != 0 ]]; then echo "pon 1/2/25 onu_count = $onu_count_pon57";fi
if [[ "$onu_count_pon57" != 0 ]]; then echo "pon 1/2/25 onu_count_up = $onu_count_up_pon57";fi
if [[ "$onu_count_pon57" != 0 ]]; then echo "pon 1/2/25 onu_count_down = $onu_count_down_pon57";echo "";fi;

if [[ "$onu_count_pon58" != 0 ]]; then echo "pon 1/2/26 onu_count = $onu_count_pon58";fi
if [[ "$onu_count_pon58" != 0 ]]; then echo "pon 1/2/26 onu_count_up = $onu_count_up_pon58";fi
if [[ "$onu_count_pon58" != 0 ]]; then echo "pon 1/2/26 onu_count_down = $onu_count_down_pon58";echo "";fi;

if [[ "$onu_count_pon59" != 0 ]]; then echo "pon 1/2/27 onu_count = $onu_count_pon59";fi
if [[ "$onu_count_pon59" != 0 ]]; then echo "pon 1/2/27 onu_count_up = $onu_count_up_pon59";fi
if [[ "$onu_count_pon59" != 0 ]]; then echo "pon 1/2/27 onu_count_down = $onu_count_down_pon59";echo "";fi;

if [[ "$onu_count_pon60" != 0 ]]; then echo "pon 1/2/28 onu_count = $onu_count_pon60";fi
if [[ "$onu_count_pon60" != 0 ]]; then echo "pon 1/2/28 onu_count_up = $onu_count_up_pon60";fi
if [[ "$onu_count_pon60" != 0 ]]; then echo "pon 1/2/28 onu_count_down = $onu_count_down_pon60";echo "";fi;

if [[ "$onu_count_pon61" != 0 ]]; then echo "pon 1/2/29 onu_count = $onu_count_pon61";fi
if [[ "$onu_count_pon61" != 0 ]]; then echo "pon 1/2/29 onu_count_up = $onu_count_up_pon61";fi
if [[ "$onu_count_pon61" != 0 ]]; then echo "pon 1/2/29 onu_count_down = $onu_count_down_pon61";echo "";fi;

if [[ "$onu_count_pon62" != 0 ]]; then echo "pon 1/2/30 onu_count = $onu_count_pon62";fi
if [[ "$onu_count_pon62" != 0 ]]; then echo "pon 1/2/30 onu_count_up = $onu_count_up_pon62";fi
if [[ "$onu_count_pon62" != 0 ]]; then echo "pon 1/2/30 onu_count_down = $onu_count_down_pon62";echo "";fi;

if [[ "$onu_count_pon63" != 0 ]]; then echo "pon 1/2/31 onu_count = $onu_count_pon63";fi
if [[ "$onu_count_pon63" != 0 ]]; then echo "pon 1/2/31 onu_count_up = $onu_count_up_pon63";fi
if [[ "$onu_count_pon63" != 0 ]]; then echo "pon 1/2/31 onu_count_down = $onu_count_down_pon63";echo "";fi;

if [[ "$onu_count_pon64" != 0 ]]; then echo "pon 1/2/32 onu_count = $onu_count_pon64";fi
if [[ "$onu_count_pon64" != 0 ]]; then echo "pon 1/2/32 onu_count_up = $onu_count_up_pon64";fi
if [[ "$onu_count_pon64" != 0 ]]; then echo "pon 1/2/32 onu_count_down = $onu_count_down_pon64";echo "";fi;
##
final_date_time=$(date "+%Y-%m-%d %T");
final_date_time_sec=$(date -u -d "$final_date_time" +"%s");
get_pon_onu_duration_sec=$(($final_date_time_sec-$initial_date_time_sec));
echo "A consulta e processamento das informacoes levou $get_pon_onu_duration_sec segundos.";echo "";
fi;
