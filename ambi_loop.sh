#!/system/bin/sh
BRIGHT=80
BOOST=25
GREEN=80
BLUE=85
SPEED=80
STEPS=4
PAUSE=0.02

KEY=joystick_led_light_picker_color
STOP=/data/local/tmp/ambi_stop
LOG=/data/local/tmp/ambi_log.txt

savelog() {
  for P in /sdcard /storage/emulated/0 /data/media/0; do
    cp $LOG $P/ambi_log.txt 2>/dev/null && break
  done
}

echo "Start: $(date)" > $LOG
echo "Version 4" >> $LOG
ORIG=$(settings get system $KEY)
case "$ORIG" in "#"*) ;; *) ORIG="#ffff0000,#ffff0000";; esac
echo "Alte Farbe: $ORIG" >> $LOG

TMP=""
for D in /dev /mnt; do
  if grep -q " $D tmpfs " /proc/mounts && mkdir -p $D/ambi 2>/dev/null && touch $D/ambi/t 2>/dev/null; then
    TMP=$D/ambi
    break
  fi
done
if [ -z "$TMP" ]; then
  echo "FEHLER: kein Zwischenspeicher" >> $LOG
  savelog
  exit 1
fi
F=$TMP/s.raw
echo "Zwischenspeicher: $TMP" >> $LOG

cnt=0
HDR=0
grab() {
  screencap $F 2>/dev/null || return 1
  if [ $((cnt%50)) -eq 0 ]; then
    set -- $(od -An -tu4 -N 8 $F 2>/dev/null)
    W=$1; H=$2
    [ -n "$H" ] || return 1
    SIZE=$(stat -c %s $F)
    HDR=$((SIZE - W*H*4))
    NL=$((W*4/96))
    L1=$((NL*4/100)); L2=$((NL*34/100)); R1=$((NL*66/100)); R2=$((NL*96/100))
  fi
  cnt=$((cnt+1))
  [ $HDR -eq 12 ] || [ $HDR -eq 16 ] || { cnt=0; return 1; }
}

sample() {
  lr=0; lg=0; lb=0; lw=0; rr=0; rg=0; rb=0; rw=0
  for yp in 12 30 50 70 88; do
    off=$((HDR + (H*yp/100)*W*4))
    i=0
    for v in $(od -An -v -tu1 -w96 -j $off -N $((W*4)) $F 2>/dev/null | sed 's/^ *\([0-9]*\) *\([0-9]*\) *\([0-9]*\).*/\1 \2 \3/'); do
      case $((i%3)) in
        0) pr=$v;;
        1) pg=$v;;
        2) j=$((i/3))
           if [ $j -ge $L1 ] && [ $j -le $L2 ]; then
             mx=$((pr>pg?pr:pg)); mx=$((mx>v?mx:v))
             mn=$((pr<pg?pr:pg)); mn=$((mn<v?mn:v))
             w=$(((mx-mn)/4+16))
             lr=$((lr+pr*w)); lg=$((lg+pg*w)); lb=$((lb+v*w)); lw=$((lw+w))
           elif [ $j -ge $R1 ] && [ $j -le $R2 ]; then
             mx=$((pr>pg?pr:pg)); mx=$((mx>v?mx:v))
             mn=$((pr<pg?pr:pg)); mn=$((mn<v?mn:v))
             w=$(((mx-mn)/4+16))
             rr=$((rr+pr*w)); rg=$((rg+pg*w)); rb=$((rb+v*w)); rw=$((rw+w))
           fi;;
      esac
      i=$((i+1))
    done
  done
  [ $lw -gt 0 ] && [ $rw -gt 0 ]
}

tune() {
  mx=$((R>G?R:G)); mx=$((mx>B?mx:B))
  mn=$((R<G?R:G)); mn=$((mn<B?mn:B))
  k=$((mn*BOOST/100))
  if [ $mx -gt $k ]; then
    R=$(((R-k)*mx/(mx-k))); G=$(((G-k)*mx/(mx-k))); B=$(((B-k)*mx/(mx-k)))
  fi
  if [ $mx -gt 0 ]; then
    R=$((R*R/mx)); G=$((G*G/mx)); B=$((B*B/mx))
  fi
  R=$((R*BRIGHT/100)); G=$((G*GREEN/100*BRIGHT/100)); B=$((B*BLUE/100*BRIGHT/100))
}

fade() {
  s=1
  while [ $s -le $STEPS ]; do
    settings put system $KEY "$(printf '#ff%02x%02x%02x,#ff%02x%02x%02x' $((cLR+(nLR-cLR)*s/STEPS)) $((cLG+(nLG-cLG)*s/STEPS)) $((cLB+(nLB-cLB)*s/STEPS)) $((cRR+(nRR-cRR)*s/STEPS)) $((cRG+(nRG-cRG)*s/STEPS)) $((cRB+(nRB-cRB)*s/STEPS)))"
    [ $s -lt $STEPS ] && sleep $PAUSE
    s=$((s+1))
  done
}

cLR=0; cLG=0; cLB=0; cRR=0; cRG=0; cRB=0
frames=0
fail=0
while [ ! -e $STOP ]; do
  if ! grab || ! sample; then
    fail=$((fail+1))
    if [ $fail -ge 5 ]; then
      echo "FEHLER: Bild lesen klappt nicht (W=$W H=$H SIZE=$SIZE HDR=$HDR lw=$lw rw=$rw)" >> $LOG
      break
    fi
    sleep 1
    continue
  fi
  fail=0
  R=$((lr/lw)); G=$((lg/lw)); B=$((lb/lw)); tune; tLR=$R; tLG=$G; tLB=$B
  R=$((rr/rw)); G=$((rg/rw)); B=$((rb/rw)); tune; tRR=$R; tRG=$G; tRB=$B
  frames=$((frames+1))
  if [ $frames -eq 1 ]; then
    echo "Bild: ${W}x${H}, Kopf $HDR" >> $LOG
    echo "Erste Farben: links $tLR $tLG $tLB, rechts $tRR $tRG $tRB" >> $LOG
    echo "Zeit Bild 1: $(date +%S.%N)" >> $LOG
  fi
  if [ $frames -eq 41 ]; then
    echo "Zeit Bild 41: $(date +%S.%N)" >> $LOG
    savelog
  fi
  d=0
  for p in "$tLR $cLR" "$tLG $cLG" "$tLB $cLB" "$tRR $cRR" "$tRG $cRG" "$tRB $cRB"; do
    set -- $p
    x=$(($1-$2)); x=$((x<0?-x:x))
    d=$((x>d?x:d))
  done
  [ $d -lt 4 ] && continue
  wait
  nLR=$((cLR+(tLR-cLR)*SPEED/100)); nLG=$((cLG+(tLG-cLG)*SPEED/100)); nLB=$((cLB+(tLB-cLB)*SPEED/100))
  nRR=$((cRR+(tRR-cRR)*SPEED/100)); nRG=$((cRG+(tRG-cRG)*SPEED/100)); nRB=$((cRB+(tRB-cRB)*SPEED/100))
  fade &
  cLR=$nLR; cLG=$nLG; cLB=$nLB; cRR=$nRR; cRG=$nRG; cRB=$nRB
done

wait
settings put system $KEY "$ORIG"
rm -rf $TMP
rm -f $STOP
echo "Ende: $(date)" >> $LOG
savelog