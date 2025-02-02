#!/bin/bash

sudo dnf update -y

sudo dnf install -y @kde-desktop
sudo dnf remove -y kernel-core


# Install some extra packages
sudo dnf install -y mesa-vulkan-drivers pipewire plasma-milou

sudo systemctl set-default graphical.target
sudo systemctl enable sddm
