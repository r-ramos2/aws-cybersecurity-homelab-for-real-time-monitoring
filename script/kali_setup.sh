#!/bin/bash
apt-get update && apt-get full-upgrade -y
apt-get install -y kali-desktop-xfce xorg xrdp
systemctl enable xrdp
systemctl start xrdp
