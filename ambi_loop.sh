#!/system/bin/sh
BRIGHT=100
BOOST=70
WHITE=40
GREEN=75
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
echo "Version 5" >> $LOG
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
  fi
  cnt=$((cnt+1))
  [ $HDR -eq 12 ] || [ $HDR -eq 16 ] || { cnt=0; return 1; }
}

sample() {
  sr=0; sg=0; sb=0; sw=0
  x0=$((W*$1/100)); n=$((W*42/100*4))
  for yp in $2 $3 $4; do
    off=$((HDR + ((H*yp/100)*W + x0)*4))
    i=0
    for v in $(od -An -v -tu1 -w48 -j $off -N $n $F 2>/dev/null | sed 's/^ *\([0-9]*\) *\([0-9]*\) *\([0-9]*\).*/\1 \2 \3/'); do
      case $i in
        0) pr=$v; i=1;;
        1) pg=$v; i=2;;
        2) mx=$((pr>pg?pr:pg)); mx=$((mx>v?mx:v))
           mn=$((pr<pg?pr:pg)); mn=$((mn<v?mn:v))
           w=$(((mx-mn)/2+8))
           sr=$((sr+pr*w)); sg=$((sg+pg*w)); sb=$((sb+v*w)); sw=$((sw+w))
           i=0;;
      esac
    done
  done
  [ $sw -gt 0 ] || return 1
  R=$((sr/sw)); G=$((sg/sw)); B=$((sb/sw))
}

tune() {
  mx=$((R>G?R:G)); mx=$((mx>B?mx:B))
  mn=$((R<G?R:G)); mn=$((mn<B?mn:B))
  if [ $mx -lt 1 ]; then R=0; G=0; B=0; return; fi
  f=$((((mx-mn)*100/mx-5)*5)); f=$((f<0?0:f)); f=$((f>100?100:f))
  k=$((mn*BOOST/100*f/100))
  R=$(((R-k)*mx/(mx-k))); G=$(((G-k)*mx/(mx-k))); B=$(((B-k)*mx/(mx-k)))
  R=$((R*R/mx)); G=$((G*G/mx)); B=$((B*B/mx))
  mn=$((R<G?R:G)); mn=$((mn<B?mn:B))
  s2=$(((mx-mn)*100/mx))
  v=$((mx*mx/255))
  v=$((v*(WHITE*100+(100-WHITE)*s2)/10000*BRIGHT/100))
  R=$((R*v/mx)); G=$((G*v/mx*(100-(100-GREEN)*s2/100)/100)); B=$((B*v/mx*BLUE/100))
  R=$((R>255?255:R)); G=$((G>255?255:G)); B=$((B>255?255:B))
  if [ $R -lt 3 ] && [ $G -lt 3 ] && [ $B -lt 3 ]; then R=0; G=0; B=0; fi
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
  if ! grab || ! sample 3 14 28 42; then
    fail=$((fail+1))
    if [ $fail -ge 5 ]; then
      echo "FEHLER: Bild lesen klappt nicht (W=$W H=$H SIZE=$SIZE HDR=$HDR)" >> $LOG
      break
    fi
    sleep 1
    continue
  fi
  fail=0
  tune; tLR=$R; tLG=$G; tLB=$B
  sample 55 58 72 86
  tune; tRR=$R; tRG=$G; tRB=$B
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
  [ $d -lt 3 ] && continue
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
