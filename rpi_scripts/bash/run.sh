
export site=http://localhost:8080/ 

export rpi_scripts_dir=$(pwd)

# change dir
cd ~

# check if was already installed the envirorment
if [ -e log.log ]; then
    # if, yes, performs an echo

    echo "already installed"
else

    # if not, insalls all the dependecies
    sudo apt-get update
    sudo apt-get upgrade
    sudo apt-get install python3-dev python3-pip
    sudo pip3 install mfrc522 
    sudo apt-get install python3-tk
    sudo pip install hashlib
    #sudo apt-get install uhubctl 2.2.0 -y
    sudo apt-get install chromium-browser -y
    sudo apt install rfkill -y

fi


# run
# sudo while (true) do uhubctl -l 1-1 -p 2 -a 0 -r 1 #vorrebbe
# sudo uhubctl -a off                    #spegne porte usb
# sudo uhubctl -a on                     #accende usb
# sudo rfkill block wifi         #block wifi
# sudo rfkill unblock wifi               #unblock wifi
sudo rfkill block bluetooth             #block bluetooth
# sudo rfkill unblock bluetooth  #unblock bluetooth

# disables usb ports for preventing un-authorized peripherics
echo 0 | sudo tee /sys/bus/usb/devices/usb1/authorized
echo 0 | sudo tee /sys/bus/usb/devices/usb2/authorized

# adds the launch to crontab
echo "@reboot ~/reader.sh" > crontab.txt
crontab crontab.txt

# launches a kiosk mode chromium browser
startx
DISPLAY=:0 chromium-browser --noerrdialogs --disable-infobars --incognito --kiosk $site &

# launches main script
bash /EMBEDDED-PROJECT/rpi_scripts/bash/main.sh

#performs logging of the launch
echo run > log.log
date > log.log



