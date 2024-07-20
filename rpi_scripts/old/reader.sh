cd ~
if [ -e log.log ]; then
    echo "already installed"
else

#config
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
#run
#sudo while (true) do uhubctl -l 1-1 -p 2 -a 0 -r 1 #vorrebbe
#sudo uhubctl -a off                    #spegne porte usb
#sudo uhubctl -a on                     #accende usb
#sudo rfkill block wifi         #block wifi
#sudo rfkill unblock wifi               #unblock wifi
sudo rfkill block bluetooth             #block bluetooth
#sudo rfkill unblock bluetooth  #unblock bluetooth

echo 0 | sudo tee /sys/bus/usb/devices/usb1/authorized
echo 0 | sudo tee /sys/bus/usb/devices/usb2/authorized
 
echo "@reboot ~/reader.sh" > crontab.txt
crontab crontab.txt
 
chromium-browser --headless --disable-gpu http://localhost:8080/ 
startx
DISPLAY=:0 chromium-browser --noerrdialogs --disable-infobars --incognito --kiosk http://localhost:8080/ &
python /reader/main.py

echo run > log.log
date > log.log



