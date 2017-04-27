#!/system/bin/sh
# Copyright (c) 2012-2015, The Linux Foundation. All rights reserved.
# Copyright (C) 2017 The halogenOS Project
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above
#       copyright notice, this list of conditions and the following
#       disclaimer in the documentation and/or other materials provided
#       with the distribution.
#     * Neither the name of The Linux Foundation nor the names of its
#       contributors may be used to endorse or promote products derived
#      from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT
# ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
# BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
# IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#
chown -h root.system /sys/devices/platform/msm_hsusb/gadget/wakeup
chmod -h 220 /sys/devices/platform/msm_hsusb/gadget/wakeup

# Target as specified in build.prop at compile-time
target=`getprop ro.board.platform`

# Set platform variables
if [ -d /sys/devices/soc0 ]; then
    soc_hwplatform=`cat /sys/devices/soc0/hw_platform` 2> /dev/null
    soc_id=`cat /sys/devices/soc0/soc_id` 2> /dev/null
else
    soc_hwplatform=`cat /sys/devices/system/soc/soc0/hw_platform` 2> /dev/null
fi

#
# soc_id may specify additional chip variants not captured in ro.board.platform
# so allow for additional target differentiation based on that
#
case $soc_id in
    "252")
        target="apq8092"
    ;;
    "253")
        target="apq8094"
    ;;
esac

echo -n 2000 > /sys/module/pm8921_charger/parameters/usb_max_current

#
# Check ESOC for external MDM
#
# Note: currently only a single MDM is supported
#
if [ -d /sys/bus/esoc/devices ]; then
for f in /sys/bus/esoc/devices/*; do
    if [ -d $f ]; then
        esoc_name=`cat $f/esoc_name`
        if [ "$esoc_name" = "MDM9x25" -o "$esoc_name" = "MDM9x35" ]; then
            esoc_link=`cat $f/esoc_link`
            break
        fi
    fi
done
fi

#
# Allow USB enumeration with default PID/VID
#
baseband=`getprop ro.baseband`
echo 1  > /sys/class/android_usb/f_mass_storage/lun/nofua
usb_config=`getprop persist.sys.usb.config`
case "$usb_config" in
    "" | "adb" | "none") #USB persist config not set, select default configuration
      case "$esoc_link" in
          "HSIC")
              setprop persist.sys.usb.config diag,diag_mdm,serial_hsic,serial_tty,rmnet_hsic,mass_storage,adb
              setprop persist.rmnet.mux enabled
          ;;
          "HSIC+PCIe")
              setprop persist.sys.usb.config diag,diag_mdm,serial_hsic,rmnet_qti_ether,mass_storage,adb
          ;;
          "PCIe")
              setprop persist.sys.usb.config diag,diag_mdm,serial_tty,rmnet_qti_ether,mass_storage,adb
          ;;
          *)
          case "$baseband" in
              "mdm")
                   setprop persist.sys.usb.config diag,diag_mdm,serial_hsic,serial_tty,rmnet_hsic,mass_storage,adb
              ;;
              "mdm2")
                   setprop persist.sys.usb.config diag,diag_mdm,serial_hsic,serial_tty,rmnet_hsic,mass_storage,adb
              ;;
              "sglte")
                   setprop persist.sys.usb.config diag,diag_qsc,serial_smd,serial_tty,serial_hsuart,rmnet_hsuart,mass_storage,adb
              ;;
              "dsda" | "sglte2")
                   setprop persist.sys.usb.config diag,diag_mdm,diag_qsc,serial_hsic,serial_hsuart,rmnet_hsic,rmnet_hsuart,mass_storage,adb
              ;;
              "dsda2")
                   setprop persist.sys.usb.config diag,diag_mdm,diag_mdm2,serial_hsic,serial_hsusb,rmnet_hsic,rmnet_hsusb,mass_storage,adb
              ;;
              *)
		case "$target" in
                        "msm8916")
                            setprop persist.sys.usb.config diag,serial_smd,rmnet_bam,adb
                        ;;
                        "apq8094" | "apq8092")
                            setprop persist.sys.usb.config diag,adb
                        ;;
                        "msm8994" | "msm8992")
                            #[BSP-66]-Anderson-Disable_set_the_property.
                            #This will ause BSP-66 issue and cause all the port enable in default.
                            #setprop persist.sys.usb.config diag,serial_smd,serial_tty,rmnet_ipa,mass_storage,adb
                        ;;
                        "msm8909")
                            setprop persist.sys.usb.config diag,serial_smd,rmnet_qti_bam,adb
                        ;;
                        *)
                            setprop persist.sys.usb.config diag,serial_smd,serial_tty,rmnet_bam,mass_storage,adb
                        ;;
                    esac
              ;;
          esac
          ;;
      esac
    ;;
    * ) ;; #USB persist config exists, do nothing
esac

#VENDOR_EDIT
#echo boot mode to kmsg
boot_mode=`getprop ro.boot.ftm_mode`
echo "boot_mode: $boot_mode" > /dev/kmsg
case "$boot_mode" in
    "ftm_at" | "ftm_rf" | "ftm_wlan" | "ftm_mos")
        echo "FTM FORCE diag,adb" > /dev/kmsg
        setprop persist.sys.usb.config diag,adb
    ;;
esac

usb_config=`getprop persist.sys.usb.config`
echo "AFTER: $usb_config" > /dev/kmsg
#VENDOR_EDIT end

echo BAM2BAM_IPA > /sys/class/android_usb/android0/f_rndis_qc/rndis_transports

#
# set module params for embedded rmnet devices
#
rmnetmux=`getprop persist.rmnet.mux`
case "$baseband" in
    "mdm" | "dsda" | "sglte2")
        case "$rmnetmux" in
            "enabled")
                    echo 1 > /sys/module/rmnet_usb/parameters/mux_enabled
                    echo 8 > /sys/module/rmnet_usb/parameters/no_fwd_rmnet_links
                    echo 17 > /sys/module/rmnet_usb/parameters/no_rmnet_insts_per_dev
            ;;
        esac
        echo 1 > /sys/module/rmnet_usb/parameters/rmnet_data_init
        # Allow QMUX daemon to assign port open wait time
        chown -h radio.radio /sys/devices/virtual/hsicctl/hsicctl0/modem_wait
    ;;
    "dsda2")
          echo 2 > /sys/module/rmnet_usb/parameters/no_rmnet_devs
          echo hsicctl,hsusbctl > /sys/module/rmnet_usb/parameters/rmnet_dev_names
          case "$rmnetmux" in
               "enabled") #mux is neabled on both mdms
                      echo 3 > /sys/module/rmnet_usb/parameters/mux_enabled
                      echo 8 > /sys/module/rmnet_usb/parameters/no_fwd_rmnet_links
                      echo 17 > write /sys/module/rmnet_usb/parameters/no_rmnet_insts_per_dev
               ;;
               "enabled_hsic") #mux is enabled on hsic mdm
                      echo 1 > /sys/module/rmnet_usb/parameters/mux_enabled
                      echo 8 > /sys/module/rmnet_usb/parameters/no_fwd_rmnet_links
                      echo 17 > /sys/module/rmnet_usb/parameters/no_rmnet_insts_per_dev
               ;;
               "enabled_hsusb") #mux is enabled on hsusb mdm
                      echo 2 > /sys/module/rmnet_usb/parameters/mux_enabled
                      echo 8 > /sys/module/rmnet_usb/parameters/no_fwd_rmnet_links
                      echo 17 > /sys/module/rmnet_usb/parameters/no_rmnet_insts_per_dev
               ;;
          esac
          echo 1 > /sys/module/rmnet_usb/parameters/rmnet_data_init
          # Allow QMUX daemon to assign port open wait time
          chown -h radio.radio /sys/devices/virtual/hsicctl/hsicctl0/modem_wait
    ;;
esac

#
# Initialize RNDIS Diag option. If unset, set it to 'none'.
#
diag_extra=`getprop persist.sys.usb.config.extra`
if [ "$diag_extra" == "" ]; then
	setprop persist.sys.usb.config.extra none
fi
