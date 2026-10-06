# Ambilight for the Odin 3 stick LEDs (prototype)

The stick LEDs follow the colors on screen, like TV backlighting. Left stick = left half of the screen, right stick = right half. Colors fade smoothly.

## How it works

A script takes a screenshot into RAM about 4 times per second, samples pixels on the left and right side, and writes the result to the system setting `joystick_led_light_picker_color` (the same one the LED quick setting uses). No extra app needed, it uses the built-in "Run script as Root".

## Files

- `ambi_loop.sh` – the main program (don't run it directly)
- `ambi_start.sh` – turns it on
- `ambi_stop.sh` – turns it off

## Install

1. Download all three files and save them in the top level of the internal storage (`/sdcard`, next to Download, DCIM etc.), not in a subfolder.
2. Keep the exact file names. They must end in `.sh`, not `.sh.txt`.
3. Make sure the stick LEDs are switched on in the quick settings.

## Use

- Start: Settings → Odin settings → Run script as Root → select `ambi_start.sh` → Run
- Stop: same way with `ambi_stop.sh`. Your previous LED color is restored.
- After a reboot you need to start it again.

## Tuning

Change the values in the first lines of `ambi_loop.sh`, then run `ambi_start.sh` again.

- `BRIGHT` – brightness
- `BOOST` – color intensity
- `GREEN` / `BLUE` – color balance
- `SPEED` – how fast the colors follow

## Is it safe?

Pretty much, yes. The script only changes one thing: the stick LED color setting, the same one you change yourself in the quick settings. It doesn't touch system files, performance settings or anything else.

- The screenshots stay in RAM on your device, are overwritten each time and deleted when you stop the script. Nothing is sent anywhere.
- The only file it writes is a small log (`ambi_log.txt`).
- Stopping it restores your old LED color. A reboot also ends it completely.

It does run through "Run script as Root", so as with any script, feel free to read it first.

## Good to know

- Protected video (e.g. Netflix) reads as black, so the LEDs go dark.
- Uses a bit of extra battery.
- Only tested on my Odin 3. Use at your own risk.
- If nothing happens, check `ambi_log.txt` in the same folder.

## Status

This doesn't work perfectly yet. The lights lag a bit because the script can only grab a few screenshots per second, so very short flashes can be missed. I'm working on a better version, an app, that will react much faster and smoother.

