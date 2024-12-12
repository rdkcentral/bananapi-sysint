#!/bin/sh
#######################################################################################
# If not stated otherwise in this file or this component's LICENSE file the
# following copyright and licenses apply:

#  Copyright 2024 RDK Management

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

# http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#######################################################################################

UTOPIA_PATH="/etc/utopia/service.d"
TAD_PATH="/usr/ccsp/tad"
RDKLOGGER_PATH="/rdklogger"
PRIVATE_LAN="brlan0"
source $TAD_PATH/corrective_action.sh
SELFHEAL_TYPE="BASE"

case $SELFHEAL_TYPE in
    "BASE")
        grePrefix="gretap0"
        brlanPrefix="brlan"
    ;;
    "SYSTEMD")
        ADVSEC_PATH="/usr/ccsp/advsec/usr/libexec/advsec.sh"
    ;;
esac

ping_failed=0
ping_success=0
SyseventdCrashed="/rdklogs/syseventd_crashed"
WAN_INTERFACE=`sysevent get current_wan_ifname`
if [ "$WAN_INTERFACE" = "" ]
then	
     WAN_INTERFACE="erouter0"
fi     
IDLE_TIMEOUT=60
CCSP_ERR_TIMEOUT=191
CCSP_ERR_NOT_EXIST=192

exec 3>&1 4>&2 >>$SELFHEALFILE 2>&1

# set thisREADYFILE for several tests below:
case $SELFHEAL_TYPE in
    "BASE")
    ;;
    "SYSTEMD")
        thisREADYFILE="/tmp/.qtn_ready"
    ;;
esac

# set thisIS_BCI for several tests below:
# 'thisIS_BCI' is used where 'IS_BCI' was added in recent changes (c.6/2019)
# 'IS_BCI' is still used when appearing in earlier code.
# TBD: may be able to set 'thisIS_BCI=$IS_BCI' for ALL devices?
case $SELFHEAL_TYPE in
    "BASE")
        thisIS_BCI="$IS_BCI"
    ;;
    "SYSTEMD")
        thisIS_BCI="no"
    ;;
esac

rebootDeviceNeeded=0

LIGHTTPD_CONF="/var/lighttpd.conf"

# Checking PSM's PID
PSM_PID=`pidof PsmSsp`
if [ "$PSM_PID" = "" ]; then
    case $SELFHEAL_TYPE in
        "BASE")
            echo_t "RDKB_PROCESS_CRASHED : PSM_process is not running, need restart"
            resetNeeded psm PsmSsp
        ;;
        "SYSTEMD")
        ;;
    esac
else
    psm_name=`dmcli eRT getv com.cisco.spvtg.ccsp.psm.Name`
    psm_name_timeout=`echo $psm_name | grep "$CCSP_ERR_TIMEOUT"`
    psm_name_notexist=`echo $psm_name | grep "$CCSP_ERR_NOT_EXIST"`
    if [ "$psm_name_timeout" != "" ] || [ "$psm_name_notexist" != "" ]; then
        psm_health=`dmcli eRT getv com.cisco.spvtg.ccsp.psm.Health`
        psm_health_timeout=`echo $psm_health | grep "$CCSP_ERR_TIMEOUT"`
        psm_health_notexist=`echo $psm_health | grep "$CCSP_ERR_NOT_EXIST"`
        if [ "$psm_health_timeout" != "" ] || [ "$psm_health_notexist" != "" ]; then
            echo_t "RDKB_PROCESS_CRASHED : PSM_process is in hung state, need restart"
            case $SELFHEAL_TYPE in
                "BASE")
                    kill -9 `pidof PsmSsp`
                    resetNeeded psm PsmSsp
                ;;
                "SYSTEMD")
                    systemctl restart PsmSsp.service
                ;;
            esac
        fi
    fi
fi

case $SELFHEAL_TYPE in
    "BASE")
	WiFi_Flag=false                                                                                                   
        # Checking Wifi's PID                                                                                           
        WIFI_PID=`pidof OneWifi`                                                                                                           
        if [ "$WIFI_PID" = "" ]; then                                                                             
            # Remove the wifi initialized flag                                                                                                 
            rm -rf /tmp/wifi_initialized                                                                                  
            echo_t "RDKB_PROCESS_CRASHED : WIFI_process is not running, need restart"                                                          
            resetNeeded wifi OneWifi                                                                                                       
        else                                                                                                      
            radioenable=`dmcli eRT getv Device.WiFi.Radio.1.Enable`                                               
            radioenable_timeout=`echo $radioenable | grep "$CCSP_ERR_TIMEOUT"`                                            
            radioenable_notexist=`echo $radioenable | grep "$CCSP_ERR_NOT_EXIST"`                                                              
            if [ "$radioenable_timeout" != "" ] || [ "$radioenable_notexist" != "" ]; then                                                     
                wifi_name=`dmcli eRT getv com.cisco.spvtg.ccsp.wifi.Name`                                                
                wifi_name_timeout=`echo $wifi_name | grep "$CCSP_ERR_TIMEOUT"`                                       
                wifi_name_notexist=`echo $wifi_name | grep "$CCSP_ERR_NOT_EXIST"`                                         
                if [ "$wifi_name_timeout" != "" ] || [ "$wifi_name_notexist" != "" ]; then                               
                    echo_t "[RDKB_PLATFORM_ERROR] : onewifi  process is restarting"                                                         
                    # Remove the wifi initialized flag                                                                    
                    rm -rf /tmp/wifi_initialized                                                                  
                    resetNeeded wifi OneWifi                                                                          
                    WiFi_Flag=true                                                                                        
                fi                                                                                                                             
            fi                                                                                                    
        fi     

        PAM_PID=`pidof CcspPandMSsp`
        if [ "$PAM_PID" = "" ]; then
            # Remove the P&M initialized flag
            rm -rf /tmp/pam_initialized
            echo_t "RDKB_PROCESS_CRASHED : PAM_process is not running, need restart"
            resetNeeded pam CcspPandMSsp
        fi

        TR69_PID=`pidof CcspTr069PaSsp`
        if [ "$TR69_PID" = "" ]; then
             echo_t "RDKB_PROCESS_CRASHED : TR69_process is not running, need restart"
             resetNeeded TR69 CcspTr069PaSsp
        fi

        # Checking Test adn Daignostic's PID
        TandD_PID=`pidof CcspTandDSsp`
        if [ "$TandD_PID" = "" ]; then
            echo_t "RDKB_PROCESS_CRASHED : TandD_process is not running, need restart"
            resetNeeded tad CcspTandDSsp
        fi

        # Checking Lan Manager PID
        LM_PID=`pidof CcspLMLite`
        if [ "$LM_PID" = "" ]; then
            echo_t "RDKB_PROCESS_CRASHED : LanManager_process is not running, need restart"
            resetNeeded lm CcspLMLite
        else
            cr_query=`dmcli eRT getv com.cisco.spvtg.ccsp.lmlite.Name`
            cr_timeout=`echo $cr_query | grep "$CCSP_ERR_TIMEOUT"`
            cr_lmlite_notexist=`echo $cr_query | grep "$CCSP_ERR_NOT_EXIST"`
            if [ "$cr_timeout" != "" ] || [ "$cr_lmlite_notexist" != "" ]; then
                echo_t "[RDKB_PLATFORM_ERROR] : LMlite process is not responding. Restarting it"
                kill -9 `pidof CcspLMLite`
                resetNeeded lm CcspLMLite
            fi
        fi


        # Checking XdnsSsp PID
        XDNS_PID=`pidof CcspXdnsSsp`
        if [ "$XDNS_PID" = "" ] && [ "$Box_Type" != "bpi" ]; then
            echo_t "RDKB_PROCESS_CRASHED : CcspXdnsSsp_process is not running, need restart"
            resetNeeded xdns CcspXdnsSsp

        fi

        # Checking CcspEthAgent PID
        ETHAGENT_PID=`pidof CcspEthAgent`
        if [ "$ETHAGENT_PID" = "" ]; then
            echo_t "RDKB_PROCESS_CRASHED : CcspEthAgent_process is not running, need restart"
            resetNeeded ethagent CcspEthAgent

        fi

        # Checking snmp v2 subagent PID
        SNMP_PID=`ps ww | grep snmp_subagent | grep -v cm_snmp_ma_2 | grep -v grep | awk '{print $1}'`
        if [ "$SNMP_PID" = "" ]; then
            if [ -f /tmp/.snmp_agent_restarting ]; then
                echo_t "[RDKB_SELFHEAL] : snmp process is restarted through maintanance window"
            else
                SNMPv2_RDKB_MIBS_SUPPORT=`syscfg get V2Support`
                if [[ "$SNMPv2_RDKB_MIBS_SUPPORT" = "true" || "$SNMPv2_RDKB_MIBS_SUPPORT" = "" ]];then
                    echo_t "RDKB_PROCESS_CRASHED : snmp process is not running, need restart"
                    resetNeeded snmp snmp_subagent
                fi
            fi
        fi

    ;;
    "SYSTEMD")
    ;;
esac

case $SELFHEAL_TYPE in
    "BASE")
    ;;
    "SYSTEMD")
        WiFi_Flag=false
        WiFi_PID=`pidof OneWifi`
        if [ "$WiFi_PID" != "" ]; then
            radioenable=`dmcli eRT getv Device.WiFi.Radio.1.Enable`
            radioenable_timeout=`echo $radioenable | grep "$CCSP_ERR_TIMEOUT"`
            radioenable_notexist=`echo $radioenable | grep "$CCSP_ERR_NOT_EXIST"`
            if [ "$radioenable_timeout" != "" ] || [ "$radioenable_notexist" != "" ]; then
                wifi_name=`dmcli eRT getv com.cisco.spvtg.ccsp.wifi.Name`
                wifi_name_timeout=`echo $wifi_name | grep "$CCSP_ERR_TIMEOUT"`
                wifi_name_notexist=`echo $wifi_name | grep "$CCSP_ERR_NOT_EXIST"`
                if [ "$wifi_name_timeout" != "" ] || [ "$wifi_name_notexist" != "" ]; then
                        echo_t "[RDKB_PLATFORM_ERROR] : onewifi process is hung , restarting it"
                        systemctl restart onewifi
                        WiFi_Flag=true
                fi
            fi
        fi
    ;;
esac

HOTSPOT_ENABLE=`dmcli eRT getv Device.DeviceInfo.X_COMCAST_COM_xfinitywifiEnable | grep value | cut -f3 -d : | cut -f2 -d" "`

if [ "$HOTSPOT_ENABLE" = "true" ]
then
    DHCP_ARP_PID=`pidof hotspot_arpd`
    if [ "$DHCP_ARP_PID" = "" ] && [ -f /tmp/hotspot_arpd_up ]; then
        echo_t "RDKB_PROCESS_CRASHED : DhcpArp_process is not running, need restart"
        resetNeeded "" hotspot_arpd
    fi
    
    HOTSPOT_PID=`pidof CcspHotspot`
	if [ "$HOTSPOT_PID" = "" ]; then
		echo_t "RDKB_PROCESS_CRASHED : CcspHotspot_process is not running, need restart"
		resetNeeded "" CcspHotspot
	fi
fi

case $SELFHEAL_TYPE in
    "BASE")
        if [ "$HOTSPOT_ENABLE" = "true" ]
        then
            #When Xfinitywifi is enabled, l2sd0.102 and l2sd0.103 should be present.
            #If they are not present below code shall re-create them
            #l2sd0.102 case , also adding a strict rule that they are up, since some
            #devices we observed l2sd0 not up


            ifconfig | grep l2sd0.102
            if [ $? == 1 ]; then
                echo_t "XfinityWifi is enabled, but l2sd0.102 interface is not created try creating it"

                Interface=`psmcli get dmsb.l2net.3.Members.WiFi`
                if [ "$Interface" == "" ]; then
                    echo_t "PSM value(ath4) is missing for l2sd0.102"
                    psmcli set dmsb.l2net.3.Members.WiFi ath4
                fi

                sysevent set multinet_3-status stopped
                $UTOPIA_PATH/service_multinet_exec multinet-start 3
                ifconfig l2sd0.102 up
                ifconfig | grep l2sd0.102
                if [ $? == 1 ]; then
                    echo_t "l2sd0.102 is not created at First Retry, try again after 2 sec"
                    sleep 2
                    sysevent set multinet_3-status stopped
                    $UTOPIA_PATH/service_multinet_exec multinet-start 3
                    ifconfig l2sd0.102 up
                    ifconfig | grep l2sd0.102
                    if [ $? == 1 ]; then
                        echo_t "[RDKB_PLATFORM_ERROR] : l2sd0.102 is not created after Second Retry, no more retries !!!"
                    fi
                else
                    echo_t "[RDKB_PLATFORM_ERROR] : l2sd0.102 created at First Retry itself"
                fi
            else
                echo_t "XfinityWifi is enabled and l2sd0.102 is present"
            fi

            #l2sd0.103 case


            ifconfig | grep l2sd0.103
            if [ $? == 1 ]; then
                echo_t "XfinityWifi is enabled, but l2sd0.103 interface is not created try creatig it"

                Interface=`psmcli get dmsb.l2net.4.Members.WiFi`
                if [ "$Interface" == "" ]; then
                    echo_t "PSM value(ath5) is missing for l2sd0.103"
                    psmcli set dmsb.l2net.4.Members.WiFi ath5
                fi

                sysevent set multinet_4-status stopped
                $UTOPIA_PATH/service_multinet_exec multinet-start 4
                ifconfig l2sd0.103 up
                ifconfig | grep l2sd0.103
                if [ $? == 1 ]; then
                    echo_t "l2sd0.103 is not created at First Retry, try again after 2 sec"
                    sleep 2
                    sysevent set multinet_4-status stopped
                    $UTOPIA_PATH/service_multinet_exec multinet-start 4
                    ifconfig l2sd0.103 up
                    ifconfig | grep l2sd0.103
                    if [ $? == 1 ]; then
                        echo_t "[RDKB_PLATFORM_ERROR] : l2sd0.103 is not created after Second Retry, no more retries !!!"
                    fi
                else
                    echo_t "[RDKB_PLATFORM_ERROR] : l2sd0.103 created at First Retry itself"
                fi
            else
                echo_t "Xfinitywifi is enabled and l2sd0.103 is present"
            fi

            #RDKB-16889: We need to make sure Xfinity hotspot Vlan IDs are attached to the bridges
            #if found not attached , then add the device to bridges
            for index in 2 3 4 5
            do
                grePresent=`ifconfig -a | grep $grePrefix.10$index`
                if [ -n "$grePresent" ]; then
                    vlanAdded=`brctl show $brlanPrefix$index | grep $l2sd0Prefix.10$index`
                    if [ -z "$vlanAdded" ]; then
                        echo_t "[RDKB_PLATFORM_ERROR] : Vlan not added $l2sd0Prefix.10$index"
                        brctl addif $brlanPrefix$index $l2sd0Prefix.10$index
                    fi
                fi
            done

            SECURED_24=`dmcli eRT getv Device.WiFi.SSID.9.Enable | grep value | cut -f3 -d : | cut -f2 -d" "`
            SECURED_5=`dmcli eRT getv Device.WiFi.SSID.10.Enable | grep value | cut -f3 -d : | cut -f2 -d" "`

            #Check for Secured Xfinity hotspot briges and associate them properly if
            #not proper
            #l2sd0.103 case

            #Secured Xfinity 2.4
            grePresent=`ifconfig -a | grep $grePrefix.104`
            if [ -n "$grePresent" ]; then
                ifconfig | grep l2sd0.104
                if [ $? == 1 ]; then
                    echo_t "XfinityWifi is enabled Secured gre created, but l2sd0.104 interface is not created try creatig it"
                    sysevent set multinet_7-status stopped
                    $UTOPIA_PATH/service_multinet_exec multinet-start 7
                    ifconfig l2sd0.104 up
                    ifconfig | grep l2sd0.104
                    if [ $? == 1 ]; then
                        echo_t "l2sd0.104 is not created at First Retry, try again after 2 sec"
                        sleep 2
                        sysevent set multinet_7-status stopped
                        $UTOPIA_PATH/service_multinet_exec multinet-start 7
                        ifconfig l2sd0.104 up
                        ifconfig | grep l2sd0.104
                        if [ $? == 1 ]; then
                            echo_t "[RDKB_PLATFORM_ERROR] : l2sd0.104 is not created after Second Retry, no more retries !!!"
                        fi
                    else
                        echo_t "[RDKB_PLATFORM_ERROR] : l2sd0.104 created at First Retry itself"
                    fi
                else
                    echo_t "Xfinitywifi is enabled and l2sd0.104 is present"
                fi
            else
                #RDKB-17221: In some rare devices we found though Xfinity secured ssid enabled, but it did'nt create the gre tunnels
                #but all secured SSIDs Vaps were up and system remained in this state for long not allowing clients to
                #connect
                if [ "$SECURED_24" = "true" ]; then
                    echo_t "[RDKB_PLATFORM_ERROR] :XfinityWifi: Secured SSID 2.4 is enabled but gre tunnels not present, restoring it"
                    sysevent set multinet_7-status stopped
                    $UTOPIA_PATH/service_multinet_exec multinet-start 7
                fi
            fi

            #Secured Xfinity 5
            grePresent=`ifconfig -a | grep $grePrefix.105`
            if [ -n "$grePresent" ]; then
                ifconfig | grep l2sd0.105
                if [ $? == 1 ]; then
                    echo_t "XfinityWifi is enabled Secured gre created, but l2sd0.105 interface is not created try creatig it"
                    sysevent set multinet_8-status stopped
                    $UTOPIA_PATH/service_multinet_exec multinet-start 8
                    ifconfig l2sd0.105 up
                    ifconfig | grep l2sd0.105
                    if [ $? == 1 ]; then
                        echo_t "l2sd0.105 is not created at First Retry, try again after 2 sec"
                        sleep 2
                        sysevent set multinet_8-status stopped
                        $UTOPIA_PATH/service_multinet_exec multinet-start 8
                        ifconfig l2sd0.105 up
                        ifconfig | grep l2sd0.105
                        if [ $? == 1 ]; then
                            echo_t "[RDKB_PLATFORM_ERROR] : l2sd0.105 is not created after Second Retry, no more retries !!!"
                        fi
                    else
                        echo_t "[RDKB_PLATFORM_ERROR] : l2sd0.105 created at First Retry itself"
                    fi
                else
                    echo_t "Xfinitywifi is enabled and l2sd0.105 is present"
                fi
            else
                if [ "$SECURED_5" = "true" ]; then
                    echo_t "[RDKB_PLATFORM_ERROR] :XfinityWifi: Secured SSID 5GHz is enabled but gre tunnels not present, restoring it"
                    sysevent set multinet_8-status stopped
                    $UTOPIA_PATH/service_multinet_exec multinet-start 8
                fi
            fi
        fi  # [ "$WAN_TYPE" != "EPON" ] && [ "$HOTSPOT_ENABLE" = "true" ]
    ;;
    "SYSTEMD")
    ;;
esac

case $SELFHEAL_TYPE in
   "BASE"|"SYSTEMD")
        #Checking dropbear PID
        DROPBEAR_PID=`pidof dropbear`
        if [ "$DROPBEAR_PID" = "" ]; then
            echo_t "RDKB_PROCESS_CRASHED : dropbear_process is not running, restarting it"
            sh /etc/utopia/service.d/service_sshd.sh sshd-restart &
        fi
    ;;
esac

case $SELFHEAL_TYPE in
    "BASE"|"SYSTEMD")
        # Checking lighttpd PID
        LIGHTTPD_PID=`pidof lighttpd`
        if [ "$LIGHTTPD_PID" = "" ]; then
                echo_t "RDKB_PROCESS_CRASHED : lighttpd is not running, restarting it"
		rm /tmp/webgui_initialized
                sh /etc/webgui.sh
        fi
    ;;
esac

# Checking for parodus connection stuck issue
# Checking parodus PID
PARODUS_PID=`pidof parodus`
case $SELFHEAL_TYPE in
    "BASE")
        if [ "$PARODUS_PID" = "" ]; then
	     sh /lib/rdk/parodus_start.sh
        fi
	WEBPA_PID=`pidof webpa`
        if [ "$WEBPA_PID" = "" ]; then
	     /usr/bin/webpa &
        fi
    ;;
    "SYSTEMD")
        thisPARODUS_PID="$PARODUS_PID"
    ;;
esac


case $SELFHEAL_TYPE in
    "BASE"|"SYSTEMD")
        #Checking Wheteher any core is generated inside /tmp folder
        CORE_TMP=`ls /tmp | grep core.`
        if [ "$CORE_TMP" != "" ]; then
            echo_t "[PROCESS_CRASH] : core has been generated inside /tmp :  $CORE_TMP"
            CORE_COUNT=`ls /tmp | grep core. | wc -w`
            echo_t "[PROCESS_CRASH] : Number of cores created inside /tmp are : $CORE_COUNT"
        fi
    ;;
esac

# Checking syseventd PID
SYSEVENT_PID=`pidof syseventd`
if [ "$SYSEVENT_PID" == "" ]
then
    if [ ! -f "$SyseventdCrashed"  ]
    then
        echo_t "[RDKB_PROCESS_CRASHED] : syseventd is crashed, need to reboot the device in maintanance window."
        touch $SyseventdCrashed
        case $SELFHEAL_TYPE in
            "BASE"|"SYSTEMD")
                echo_t "Setting Last reboot reason"
                dmcli eRT setv Device.DeviceInfo.X_RDKCENTRAL-COM_LastRebootReason string Syseventd_crash
                dmcli eRT setv Device.DeviceInfo.X_RDKCENTRAL-COM_LastRebootCounter int 1
            ;;
        esac
    fi
    rebootDeviceNeeded=1
    reboot
fi

case $SELFHEAL_TYPE in
    "BASE")
        # Checking whether brlan0 and l2sd0.100 are created properly , if not recreate it
        check_device_mode=`dmcli eRT getv Device.X_CISCO_COM_DeviceControl.LanManagementEntry.1.LanMode`
        check_param_get_succeed=`echo $check_device_mode | grep "Execution succeed"`
        if [ "$check_param_get_succeed" != "" ]
        then
             check_device_in_router_mode=`echo $check_param_get_succeed | grep router`
             if [ "$check_device_in_router_mode" != "" ]
             then
                    check_if_brlan0_created=`ifconfig | grep brlan0`
                    check_if_brlan0_up=`ifconfig brlan0 | grep UP`
                    check_if_brlan0_hasip=`ifconfig brlan0 | grep "inet addr"`
                    if [ "$check_if_brlan0_created" = "" ] || [ "$check_if_brlan0_up" = "" ] || [ "$check_if_brlan0_hasip" = "" ]
                    then
                        echo_t "[RDKB_PLATFORM_ERROR] : Either brlan0 or l2sd0.100 is not completely up, setting event to recreate vlan and brlan0 interface"
                        echo_t "[RDKB_SELFHEAL_BOOTUP] : brlan0 o/p "
                        ifconfig brlan0; brctl show
                        logNetworkInfo

                        ipv4_status=`sysevent get ipv4_4-status`
                        lan_status=`sysevent get lan-status`

                        if [ "$lan_status" != "started" ]
                        then
                            if [ "$ipv4_status" = "" ] || [ "$ipv4_status" = "down" ]
                            then
                                echo_t "[RDKB_SELFHEAL] : ipv4_4-status is not set or lan is not started, setting lan-start event"
                                sysevent set lan-start
                                sleep 5
                            fi
                        fi
                    fi
                  fi  
                fi
    ;;
    "SYSTEMD")
    ;;
esac

Radio_5G_Enable_Check()
{
    radioenable_5=$(dmcli eRT getv Device.WiFi.Radio.2.Enable)
    isRadioExecutionSucceed_5=$(echo "$radioenable_5" | grep "Execution succeed")
    if [ "$isRadioExecutionSucceed_5" != "" ]; then
        isRadioEnabled_5=$(echo "$radioenable_5" | grep "false")
        if [ "$isRadioEnabled_5" != "" ]; then
            echo_t "[RDKB_SELFHEAL] : Both 5G Radio(Radio 2) and 5G Private SSID are in DISABLED state"
        else
            echo_t "[RDKB_SELFHEAL] : 5G Radio(Radio 2) is Enabled, only 5G Private SSID is DISABLED"
            fi
    else
        echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while checking 5G Radio status."
        echo "$radioenable_5"
    fi
}

#!!! TODO: merge this $SELFHEAL_TYPE block !!!
case $SELFHEAL_TYPE in
    "BASE")
        SSID_DISABLED=0
        BR_MODE=0
        ssidEnable=`dmcli eRT getv Device.WiFi.SSID.2.Enable`
        ssidExecution=`echo $ssidEnable | grep "Execution succeed"`
        if [ "$ssidExecution" != "" ]
        then
            isEnabled=`echo $ssidEnable | grep "false"`
            if [ "$isEnabled" != "" ]
            then
                Radio_5G_Enable_Check
                SSID_DISABLED=1
                echo_t "[RDKB_SELFHEAL] : SSID 5GHZ is disabled"
            fi
        else
            destinationError=`echo $ssidEnable | grep "Can't find destination component"`
            if [ "$destinationError" != "" ]
            then
                echo_t "[RDKB_PLATFORM_ERROR] : Parameter cannot be found on WiFi subsystem"
            else
                echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while checking 5G Enable"
                echo "$ssidEnable"
            fi
        fi
    ;;
    "SYSTEMD")
        #Selfheal will run after 15mins of bootup, then by now the WIFI initialization must have
        #completed, so if still wifi_initilization not done, we have to recover the WIFI
        #Restart the WIFI if initialization is not done with in 15mins of poweron.
        if [ "$WiFi_Flag" == "false" ]; then
            SSID_DISABLED=0
            BR_MODE=0
            if [ -f "/tmp/wifi_initialized" ]
            then
                echo_t "[RDKB_SELFHEAL] : WiFi Initialization done"
                ssidEnable=`dmcli eRT getv Device.WiFi.SSID.2.Enable`
                ssidExecution=`echo $ssidEnable | grep "Execution succeed"`
                if [ "$ssidExecution" != "" ]
                then
                    isEnabled=`echo $ssidEnable | grep "false"`
                    if [ "$isEnabled" != "" ]
                    then
                        SSID_DISABLED=1
                        echo_t "[RDKB_SELFHEAL] : SSID 5GHZ is disabled"
                    fi
                else
                    destinationError=`echo $ssidEnable | grep "Can't find destination component"`
                    if [ "$destinationError" != "" ]
                    then
                        echo_t "[RDKB_PLATFORM_ERROR] : Parameter cannot be found on WiFi subsystem"
                    else
                        echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while checking 5G Enable"
                        echo "$ssidEnable"
                    fi
                fi
            else
                echo_t  "[RDKB_PLATFORM_ERROR] : WiFi initialization not done"
                echo_t  "[RDKB_PLATFORM_ERROR] : restarting the OneWifi"
                systemctl stop onewifi
                systemctl start onewifi
            fi
        fi
    ;;
esac

bridgeMode=`dmcli eRT getv Device.X_CISCO_COM_DeviceControl.LanManagementEntry.1.LanMode`
# RDKB-6895
bridgeSucceed=`echo $bridgeMode | grep "Execution succeed"`
if [ "$bridgeSucceed" != "" ]
then
    isBridging=`echo $bridgeMode | grep router`
    if [ "$isBridging" = "" ]
    then
        BR_MODE=1
        echo_t "[RDKB_SELFHEAL] : Device in bridge mode"
    fi
else
    echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while checking bridge mode."
    echo_t "LanMode dmcli called failed with error $bridgeMode"
    isBridging=`syscfg get bridge_mode`
    if [ "$isBridging" != "0" ]
    then
        BR_MODE=1
        echo_t "[RDKB_SELFHEAL] : Device in bridge mode"
    fi

    case $SELFHEAL_TYPE in
        "BASE")
            pandm_timeout=`echo $bridgeMode | grep "$CCSP_ERR_TIMEOUT"`
            pandm_notexist=`echo $bridgeMode | grep "$CCSP_ERR_NOT_EXIST"`
            if [ "$pandm_timeout" != "" ] || [ "$pandm_notexist" != "" ]
            then
                echo_t "[RDKB_PLATFORM_ERROR] : pandm parameter timed out or failed to return"
                cr_query=`dmcli eRT getv com.cisco.spvtg.ccsp.pam.Name`
                cr_timeout=`echo $cr_query | grep "$CCSP_ERR_TIMEOUT"`
                cr_pam_notexist=`echo $cr_query | grep "$CCSP_ERR_NOT_EXIST"`
                if [ "$cr_timeout" != "" ] || [ "$cr_pam_notexist" != "" ]
                then
                    echo_t "[RDKB_PLATFORM_ERROR] : pandm process is not responding. Restarting it"
                    PANDM_PID=`pidof CcspPandMSsp`
                    if [ "$PANDM_PID" != "" ]; then
                        kill -9 $PANDM_PID
                    fi
                    case $SELFHEAL_TYPE in
                        "BASE")
                            rm -rf /tmp/pam_initialized
                            resetNeeded pam CcspPandMSsp
                        ;;
                        "SYSTEMD")
                        ;;
                    esac
                fi  # [ "$cr_timeout" != "" ] || [ "$cr_pam_notexist" != "" ]
            fi  # [ "$pandm_timeout" != "" ] || [ "$pandm_notexist" != "" ]
        ;;
        "SYSTEMD")
            pandm_timeout=`echo $bridgeMode | grep "$CCSP_ERR_TIMEOUT"`
            if [ "$pandm_timeout" != "" ]; then
                echo_t "[RDKB_PLATFORM_ERROR] : pandm parameter time out"
                cr_query=`dmcli eRT getv com.cisco.spvtg.ccsp.pam.Name`
                cr_timeout=`echo $cr_query | grep "$CCSP_ERR_TIMEOUT"`
                if [ "$cr_timeout" != "" ]; then
                    echo_t "[RDKB_PLATFORM_ERROR] : pandm process is not responding. Restarting it"
                    PANDM_PID=`pidof CcspPandMSsp`
                    rm -rf /tmp/pam_initialized
                    systemctl restart CcspPandMSsp.service
                fi
            else
                echo "$bridgeMode"
            fi
        ;;
    esac
fi  # [ "$bridgeSucceed" != "" ]

case $SELFHEAL_TYPE in
    "BASE")
        #check for PandM response
        bridgeMode=`dmcli eRT getv Device.X_CISCO_COM_DeviceControl.LanManagementEntry.1.LanMode`
        bridgeSucceed=`echo $bridgeMode | grep "Execution succeed"`
        if [ "$bridgeSucceed" == "" ]
        then
            echo_t "[RDKB_SELFHEAL_DEBUG] : bridge mode = $bridgeMode"
            serialNumber=`dmcli eRT getv Device.DeviceInfo.SerialNumber`
            echo_t "[RDKB_SELFHEAL_DEBUG] : SerialNumber = $serialNumber"
            modelName=`dmcli eRT getv Device.DeviceInfo.ModelName`
            echo_t "[RDKB_SELFHEAL_DEBUG] : modelName = $modelName"

            pandm_timeout=`echo $bridgeMode | grep "CCSP_ERR_TIMEOUT"`
            pandm_notexist=`echo $bridgeMode | grep "CCSP_ERR_NOT_EXIST"`
            if [ "$pandm_timeout" != "" ] || [ "$pandm_notexist" != "" ]
            then
                echo_t "[RDKB_PLATFORM_ERROR] : pandm parameter timed out or failed to return"
                cr_query=`dmcli eRT getv com.cisco.spvtg.ccsp.pam.Name`
                cr_timeout=`echo $cr_query | grep "CCSP_ERR_TIMEOUT"`
                cr_pam_notexist=`echo $cr_query | grep "CCSP_ERR_NOT_EXIST"`
                if [ "$cr_timeout" != "" ] || [ "$cr_pam_notexist" != "" ]
                then
                    echo_t "[RDKB_PLATFORM_ERROR] : pandm process is not responding. Restarting it"
                    PANDM_PID=`pidof CcspPandMSsp`
                    if [ "$PANDM_PID" != "" ]; then
                        kill -9 $PANDM_PID
                    fi
                    rm -rf /tmp/pam_initialized
                    resetNeeded pam CcspPandMSsp
                fi
            fi
        fi
    ;;
    "SYSTEMD")
    ;;
esac

if [ "$SELFHEAL_TYPE" = "BASE" ] || [ "$WiFi_Flag" == "false" ]; then
    # If bridge mode is not set and WiFI is not disabled by user,
    # check the status of SSID
    if [ $BR_MODE -eq 0 ] && [ $SSID_DISABLED -eq 0 ]
    then
        ssidStatus_5=`dmcli eRT getv Device.WiFi.SSID.2.Status`
        isExecutionSucceed=`echo $ssidStatus_5 | grep "Execution succeed"`
        if [ "$isExecutionSucceed" != "" ]
        then

            isUp=`echo $ssidStatus_5 | grep "Up"`
            if [ "$isUp" = "" ]
            then
                # We need to verify if it was a dmcli crash or is WiFi really down
                isDown=`echo $ssidStatus_5 | grep "Down"`
                if [ "$isDown" != "" ]; then
                    radioStatus_5=$(dmcli eRT getv Device.WiFi.Radio.2.Status)
                    isRadioExecutionSucceed_5=$(echo "$radioStatus_5" | grep "Execution succeed")
                    if [ "$isRadioExecutionSucceed_5" != "" ]; then
                        isRadioDown_5=$(echo "$radioStatus_5" | grep "Down")
                        if [ "$isRadioDown_5" != "" ]; then
                            echo_t "[RDKB_SELFHEAL] : Both 5G Radio(Radio 2) and 5G Private SSID are in DOWN state"
                        else
                            echo_t "[RDKB_SELFHEAL] : 5G Radio(Radio 2) is in up state, only 5G Private SSID is in DOWN state"
                        fi
                    else
                        echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while checking 5G Radio status."
                        echo "$radioStatus_5"
                    fi
                    echo_t "[RDKB_PLATFORM_ERROR] : 5G private SSID (wlan1) is off."
                else
                    echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while checking 5G status."
                    echo "$ssidStatus_5"
                fi
            fi
        else
            echo_t "[RDKB_PLATFORM_ERROR] : dmcli crashed or something went wrong while checking 5G status."
            echo "$ssidStatus_5"
        fi
    fi

    # Check the status if 2.4GHz Wifi SSID
    SSID_DISABLED_2G=0
    ssidEnable_2=`dmcli eRT getv Device.WiFi.SSID.1.Enable`
    ssidExecution_2=`echo $ssidEnable_2 | grep "Execution succeed"`

    if [ "$ssidExecution_2" != "" ]
    then
        isEnabled_2=`echo $ssidEnable_2 | grep "false"`
        if [ "$isEnabled_2" != "" ]
        then
            radioenable_2=$(dmcli eRT getv Device.WiFi.Radio.1.Enable)
            isRadioExecutionSucceed_2=$(echo "$radioenable_2" | grep "Execution succeed")
            if [ "$isRadioExecutionSucceed_2" != "" ]; then
               isRadioEnabled_2=$(echo "$radioenable_2" | grep "false")
               if [ "$isRadioEnabled_2" != "" ]; then
                   echo_t "[RDKB_SELFHEAL] : Both 2G Radio(Radio 1) and 2G Private SSID are in DISABLED state"
               else
                   echo_t "[RDKB_SELFHEAL] : 2G Radio(Radio 1) is Enabled, only 2G Private SSID is DISABLED"
               fi
            else
               echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while checking 2G Radio status."
               echo "$radioenable_2"
            fi
            SSID_DISABLED_2G=1
            echo_t "[RDKB_SELFHEAL] : SSID 2.4GHZ is disabled"
        fi
    else
        echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while checking 2.4G Enable"
        echo "$ssidEnable_2"
    fi

    # If bridge mode is not set and WiFI is not disabled by user,
    # check the status of SSID
    if [ $BR_MODE -eq 0 ] && [ $SSID_DISABLED_2G -eq 0 ]
    then
        ssidStatus_2=`dmcli eRT getv Device.WiFi.SSID.1.Status`
        isExecutionSucceed_2=`echo $ssidStatus_2 | grep "Execution succeed"`
        if [ "$isExecutionSucceed_2" != "" ]
        then

            isUp=`echo $ssidStatus_2 | grep "Up"`
            if [ "$isUp" = "" ]
            then
                # We need to verify if it was a dmcli crash or is WiFi really down
                isDown=`echo $ssidStatus_2 | grep "Down"`
                if [ "$isDown" != "" ]; then
                    radioStatus_2=$(dmcli eRT getv Device.WiFi.Radio.1.Status)
                    isRadioExecutionSucceed_2=$(echo "$radioStatus_2" | grep "Execution succeed")
                    if [ "$isRadioExecutionSucceed_2" != "" ]; then
                        isRadioDown_2=$(echo "$radioStatus_2" | grep "Down")
                        if [ "$isRadioDown_2" != "" ]; then
                            echo_t "[RDKB_SELFHEAL] : Both 2G Radio(Radio 1) and 2G Private SSID are in DOWN state"
                        else
                            echo_t "[RDKB_SELFHEAL] : 2G Radio(Radio 1) is in up state, only 2G Private SSID is in DOWN state"
                    fi
                    else
                        echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while checking 2G Radio status."
                        echo "$radioStatus_2"
                    fi
                    echo_t "[RDKB_PLATFORM_ERROR] : 2.4G private SSID (wlan0) is off."
                else
                    echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while checking 2.4G status."
                    echo "$ssidStatus_2"
                fi
            fi
        else
            echo_t "[RDKB_PLATFORM_ERROR] : dmcli crashed or something went wrong while checking 2.4G status."
            echo "$ssidStatus_2"
        fi
    fi
fi

FIREWALL_ENABLED=`syscfg get firewall_enabled`

echo_t "[RDKB_SELFHEAL] : BRIDGE_MODE is $BR_MODE"
echo_t "[RDKB_SELFHEAL] : FIREWALL_ENABLED is $FIREWALL_ENABLED"

#Check whether private SSID's are broadcasting during bridge-mode or not
#if broadcasting then we need to disable that SSID's for pseduo mode(2)
#if device is in full bridge-mode(3) then we need to disable both radio and SSID's
if [ $BR_MODE -eq 1 ]; then

    isBridging=`syscfg get bridge_mode`
    echo_t "[RDKB_SELFHEAL] : BR_MODE:$isBridging"

    #full bridge-mode(3)
    if [ "$isBridging" == "3" ]
    then
        # Check the status if 2.4GHz Wifi Radio
        RADIO_ENABLED_2G=0
        RadioEnable_2=`dmcli eRT getv Device.WiFi.Radio.1.Enable`
        RadioExecution_2=`echo $RadioEnable_2 | grep "Execution succeed"`

        if [ "$RadioExecution_2" != "" ]
        then
            isEnabled_2=`echo $RadioEnable_2 | grep "true"`
            if [ "$isEnabled_2" != "" ]
            then
                RADIO_ENABLED_2G=1
                echo_t "[RDKB_SELFHEAL] : Radio 2.4GHZ is Enabled"
            fi
        else
            echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while checking 2.4G radio Enable"
            echo "$RadioEnable_2"
        fi

        # Check the status if 5GHz Wifi Radio
        RADIO_ENABLED_5G=0
        RadioEnable_5=`dmcli eRT getv Device.WiFi.Radio.2.Enable`
        RadioExecution_5=`echo $RadioEnable_5 | grep "Execution succeed"`

        if [ "$RadioExecution_5" != "" ]
        then
            isEnabled_5=`echo $RadioEnable_5 | grep "true"`
            if [ "$isEnabled_5" != "" ]
            then
                RADIO_ENABLED_5G=1
                echo_t "[RDKB_SELFHEAL] : Radio 5GHZ is Enabled"
            fi
        else
            echo_t "[RDKB_PLATFORM_ERROR] : Something went wrong while checking 5G radio Enable"
            echo "$RadioEnable_5"
        fi

        if [ $RADIO_ENABLED_5G -eq 1 ] || [ $RADIO_ENABLED_2G -eq 1 ]; then
            dmcli eRT setv Device.WiFi.Radio.1.Enable bool false
            sleep 2
            dmcli eRT setv Device.WiFi.Radio.2.Enable bool false
            sleep 2
            dmcli eRT setv Device.WiFi.SSID.3.Enable bool false
            sleep 2
            IsNeedtoDoApplySetting=1
        fi
    fi

    if [ $SSID_DISABLED_2G -eq 0 ] || [ $SSID_DISABLED -eq 0 ]; then
        dmcli eRT setv Device.WiFi.SSID.1.Enable bool false
        sleep 2
        dmcli eRT setv Device.WiFi.SSID.2.Enable bool false
        sleep 2
        IsNeedtoDoApplySetting=1
    fi

    if [ "$IsNeedtoDoApplySetting" == "1" ]
    then
        dmcli eRT setv Device.WiFi.ApplyAccessPointSettings bool true
        sleep 3
        dmcli eRT setv Device.WiFi.ApplyRadioSettings bool true
        sleep 3
        dmcli eRT setv Device.WiFi.X_CISCO_COM_ResetRadios bool true
    fi
fi

if [ $BR_MODE -eq 0 ]
then
    iptables-save -t nat | grep "A PREROUTING -i"
    if [ $? == 1 ]; then
        echo_t "[RDKB_PLATFORM_ERROR] : iptable corrupted."
        #sysevent set firewall-restart
    fi
fi

case $SELFHEAL_TYPE in
    "BASE"|"SYSTEMD")
        if [ "$thisIS_BCI" != "yes" ] && [ $BR_MODE -eq 0 ] && [ ! -f "$brlan1_firewall" ]
        then
            firewall_rules=`iptables-save`
            check_if_brlan1=`echo $firewall_rules | grep brlan1`
            if [ "$check_if_brlan1" == "" ]; then
                echo_t "[RDKB_PLATFORM_ERROR]:brlan1_firewall_rules_missing,restarting firewall"
                sysevent set firewall-restart
            fi
            touch $brlan1_firewall
        fi
    ;;
esac

#Logging to check the DHCP range corruption
lan_ipaddr=`syscfg get lan_ipaddr`
lan_netmask=`syscfg get lan_netmask`
echo_t "[RDKB_SELFHEAL] [DHCPCORRUPT_TRACE] : lan_ipaddr = $lan_ipaddr lan_netmask = $lan_netmask"

lost_and_found_enable=`syscfg get lost_and_found_enable`
echo_t "[RDKB_SELFHEAL] [DHCPCORRUPT_TRACE] :  lost_and_found_enable = $lost_and_found_enable"
if [ "$lost_and_found_enable" == "true" ]
then
    iot_ifname=`syscfg get iot_ifname`
    iot_dhcp_start=`syscfg get iot_dhcp_start`
    iot_dhcp_end=`syscfg get iot_dhcp_end`
    iot_netmask=`syscfg get iot_netmask`
    echo_t "[RDKB_SELFHEAL] [DHCPCORRUPT_TRACE] : DHCP server configuring for IOT iot_ifname = $iot_ifname "
    echo_t "[RDKB_SELFHEAL] [DHCPCORRUPT_TRACE] : iot_dhcp_start = $iot_dhcp_start iot_dhcp_end=$iot_dhcp_end iot_netmask=$iot_netmask"
fi


#Checking whether dnsmasq is running or not
DNS_PID=`pidof dnsmasq`
if [ "$DNS_PID" == "" ]
then
   echo_t "[RDKB_SELFHEAL] : dnsmasq is not running"
else
   brlan0up=`cat /var/dnsmasq.conf | grep brlan0`
   IsAnyOneInfFailtoUp=0

   if [ $BR_MODE -eq 0 ]
   then
       if [ "$brlan0up" == "" ]
       then
           echo_t "[RDKB_SELFHEAL] : brlan0 info is not availble in dnsmasq.conf"
           IsAnyOneInfFailtoUp=1
       fi
    fi

    if [ ! -f /tmp/dnsmasq_restarted_via_selfheal ]
    then
    if [ $IsAnyOneInfFailtoUp -eq 1 ]
    then
         touch /tmp/dnsmasq_restarted_via_selfheal

         echo_t "[RDKB_SELFHEAL] : dnsmasq.conf is."
         echo "`cat /var/dnsmasq.conf`"

         echo_t "[RDKB_SELFHEAL] : Setting an event to restart dnsmasq"
         sysevent set dhcp_server-stop
         sysevent set dhcp_server-start
     fi
     fi

     case $SELFHEAL_TYPE in
           "BASE"|"SYSTEMD")
                checkIfDnsmasqIsZombie=`ps | grep dnsmasq | grep "Z" | awk '{ print $1 }'`
                if [ "$checkIfDnsmasqIsZombie" != "" ] ; then
                    for zombiepid in $checkIfDnsmasqIsZombie
                    do
                        confirmZombie=`grep "State:" /proc/$zombiepid/status | grep -i "zombie"`
                        if [ "$confirmZombie" != "" ] ; then
                            echo_t "[RDKB_SELFHEAL] : Zombie instance of dnsmasq is present, restarting dnsmasq"
                            kill -9 `pidof dnsmasq`
                            sysevent set dhcp_server-stop
                            sysevent set dhcp_server-start
                            break
                        fi
                    done
                fi
            ;;
     esac
fi   # [ "$DNS_PID" == "" ]

case $SELFHEAL_TYPE in
    "BASE")
    ;;
    "SYSTEMD")
        CHKIPV6_DAD_FAILED=`ip -6 addr show dev erouter0 | grep "scope link tentative dadfailed"`
        if [ "$CHKIPV6_DAD_FAILED" != "" ]; then
            echo_t "link Local DAD failed"
                partner_id=`syscfg get PartnerID`
                if [ "$partner_id" = "RDKM" ]; then
                    dibbler-client stop
                    sysctl -w net.ipv6.conf.erouter0.disable_ipv6=1
                    sysctl -w net.ipv6.conf.erouter0.accept_dad=0
                    sysctl -w net.ipv6.conf.erouter0.disable_ipv6=0
                    sysctl -w net.ipv6.conf.erouter0.accept_dad=1
                    dibbler-client start
                    echo_t "IPV6_DAD_FAILURE : successfully recovered for partner id $partner_id"
                fi
        fi
    ;;
esac

#Checking dibbler server is running or not RDKB_10683
DIBBLER_PID=`pidof dibbler-server`
if [ "$DIBBLER_PID" = "" ]; then

    DHCPV6C_ENABLED=`sysevent get dhcpv6c_enabled`
    if [ "$BR_MODE" == "0" ] && [ "$DHCPV6C_ENABLED" == "1" ]; then
        case $SELFHEAL_TYPE in
            "SYSTEMD"|"BASE")
                    echo_t "RDKB_PROCESS_CRASHED : Dibbler is not running, restarting the dibbler"
                    if [ -f "/etc/dibbler/server.conf" ]
                    then
                        BRLAN_CHKIPV6_DAD_FAILED=`ip -6 addr show dev $PRIVATE_LAN | grep "scope link tentative dadfailed"`
                        if [ "$BRLAN_CHKIPV6_DAD_FAILED" != "" ]; then
                            echo "DADFAILED : BRLAN0_DADFAILED"
                        elif [ ! -s  "/etc/dibbler/server.conf" ]; then
                            echo "DIBBLER : Dibbler Server Config is empty"
                        else
                            dibbler-server stop
                            sleep 2
                            dibbler-server start
                        fi
                    else
                        echo_t "RDKB_PROCESS_CRASHED : Server.conf file not present, Cannot restart dibbler"
                    fi
            ;;
        esac
    fi
fi

# Checking for WAN_INTERFACE ipv6 address
DHCPV6_ERROR_FILE="/tmp/.dhcpv6SolicitLoopError"
WAN_STATUS=`sysevent get wan-status`
WAN_IPv4_Addr=`ifconfig $WAN_INTERFACE | grep inet | grep -v inet6`

case $SELFHEAL_TYPE in
    "BASE"|"SYSTEMD")
        if [ "$WAN_STATUS" != "started" ]
        then
            echo_t "WAN_STATUS : wan-status is $WAN_STATUS"
        fi
    ;;
esac

if [ "$rebootDeviceNeeded" -eq 1 ]
then

    inMaintWindow=0
    doMaintReboot=1
    case $SELFHEAL_TYPE in
        "BASE"|"SYSTEMD")
            if [ "$UTC_ENABLE" == "true" ]
            then
                cur_hr=`LTime H`
                cur_min=`LTime M`
            else
                cur_hr=`date +"%H"`
                cur_min=`date +"%M"`
            fi
            if [ $cur_hr -ge 02 ] && [ $cur_hr -le 03 ]
            then
                inMaintWindow=1
                if [ $cur_hr -eq 03 ] && [ $cur_min -ne 00 ]
                then
                    doMaintReboot=0
                fi
            fi
        ;;
    esac
    if [ $inMaintWindow -eq 1 ]
    then
        if [ $doMaintReboot -eq 0 ]
        then
            echo_t "Maintanance window for the current day is over , unit will be rebooted in next Maintanance window "
        else
            #Check if we have already flagged reboot is needed
            if [ ! -e $FLAG_REBOOT ]
            then
                if [ "$SELFHEAL_TYPE" = "BASE" -o "$SELFHEAL_TYPE" = "SYSTEMD" ] && [ "$thisIS_BCI" != "yes" ] && [ "$rebootNeededforbrlan1" -eq 1 ]
                then
                    echo_t "rebootNeededforbrlan1"
                    echo_t "RDKB_REBOOT : brlan1 interface is not up, rebooting the device."
                    echo_t "Setting Last reboot reason"
                    dmcli eRT setv Device.DeviceInfo.X_RDKCENTRAL-COM_LastRebootReason string brlan1_down
                    case $SELFHEAL_TYPE in
                        "BASE")
                            dmcli eRT setv Device.DeviceInfo.X_RDKCENTRAL-COM_LastRebootCounter int 1  #TBD: not in original DEVICE code
                        ;;
                        "SYSTEMD")
                        ;;
                    esac
                    echo_t "SET succeeded"
                    sh /etc/calc_random_time_to_reboot_dev.sh "" &
                else
                    echo_t "rebootDeviceNeeded"
                    sh /etc/calc_random_time_to_reboot_dev.sh "" &
                fi
                touch $FLAG_REBOOT
            else
                echo_t "Already waiting for reboot"
            fi
        fi  # [ $doMaintReboot -eq 0 ]
    fi  # [ $inMaintWindow -eq 1 ]
fi  # [ "$rebootDeviceNeeded" -eq 1 ]
