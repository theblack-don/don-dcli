1. login to session
2. systemctl set-default multi-user.target (TTY after reboot)
3. reboot
4. login
5. sudo dnf copr remove theblackdon/kineticwe
6. sudo dnf copr remove lionheartp/Hyprland
7. sudo rpm -e --nodeps kineticwe
8. sudo rpm -e --nodeps plasma-desktop
9. sudo rpm -e --nodeps plasma-workspace
10. sudo rpm -e --nodeps kwin
11. sudo rpm -e --nodeps kwin-libs
14. sudo rpm -e --nodeps kwin-commmom
15. sudo dnf upgrade --refresh
16. sudo dnf group install kde-desktop
17. systemctl set-default graphical.target
18. systemctl enable --now sddm or reboot 
