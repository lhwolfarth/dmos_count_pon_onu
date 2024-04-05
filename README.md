# dmos_count_pon_onu
Este script realiza a contagem de ONUs Up, Down e totais por porta PON e do OLT
usage: ./dmos_count_pon_onu.sh [-c <snmp community>][-i <olt ip address>][-h]
Obs.: funciona apenas com OLTs DATACOM (https://www.datacom.com.br/pt/produtos/linha/gpon). Um profile SNMP deve com a configuracao o parametro 'if-oper-status' deve estar associado aos ONUs.

Devem ser passados os parametros -i <ip_address_do_olt> -c <comunidade_snmp>.
Apenas os ONUs com SNMP profile aplicado que contenha o objeto oper-status configurado serão lidos pelo script.

Exemplo de uso:
---
wolf@fileserver:~$ sudo ./get_pon_onu.sh -i 172.24.18.200 -c public

DM4610-8GPON-HW2-18-200
DM4610 8GPON+8GX+4GT+2XS (DmOS version 9.4.0-327-1-g88ada7b897)

olt_onu_count = 14
olt_onu_count_up = 13
olt_onu_count_down = 1

pon 1/1/1 onu_count = 5
pon 1/1/1 onu_count_up = 4
pon 1/1/1 onu_count_down = 1

pon 1/1/8 onu_count = 9
pon 1/1/8 onu_count_up = 9
pon 1/1/8 onu_count_down = 0

A consulta e processamento das informacoes levou 1 segundos.
---
