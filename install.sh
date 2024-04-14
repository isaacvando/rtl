wget https://github.com/isaacvando/rtl/archive/refs/heads/main.zip
unzip main.zip
roc build rtl-main/rtl.roc --optimize
sudo mv rtl-main/rtl /usr/local/bin
rm -r rtl-main main.zip
rtl --help
