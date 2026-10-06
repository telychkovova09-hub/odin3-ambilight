#!/system/bin/sh
touch /data/local/tmp/ambi_stop
sleep 3
cp /sdcard/ambi_loop.sh /data/local/tmp/ambi_loop.sh
cp /storage/emulated/0/ambi_loop.sh /data/local/tmp/ambi_loop.sh
cp /data/media/0/ambi_loop.sh /data/local/tmp/ambi_loop.sh
rm -f /data/local/tmp/ambi_stop
nohup sh /data/local/tmp/ambi_loop.sh > /dev/null 2>&1 < /dev/null &