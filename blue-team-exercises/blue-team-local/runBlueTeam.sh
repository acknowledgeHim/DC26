#!/bin/bash
sed -i '/controllerIP/'"$CONTROLLER_IP"'/g'sed -i 's/controllerIP/'"$CONTROLLER_IP"'/g' buildBlueTeam.py
sudo -E python buildBlueTeam.py