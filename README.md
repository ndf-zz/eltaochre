# eltaochre

A reverse delay program bank for the Elta Console effect unit.


## OVERVIEW:

Elta Ochre is a collection of three related reverse delay effects
for use with the Elta console and the Spin Semi FV-1 reverb IC. 

## PROGRAMS:

### 1. One-shot Long Time

- FV-1 Program: 5
- Source File: 5_oslf.asm
- X (POT0): Delay Time
- Y (POT1): Feedback Amount
- Z (POT2): Trigger Threshold CCW=disabled

One-shot reverse delay, triggered by signal level with
feedback. Delay time ranges from approximately 0.06 seconds
to just under 1 second, with reverse playback times about
half the delay time.

### 2. One-shot Short Time

- FV-1 Program: 7
- Source File: 7_oslf.asm
- X (POT0): Delay Time
- Y (POT1): Feedback Amount
- Z (POT2): Trigger Threshold CCW=disabled

One-shot reverse delay, triggered by signal level with
feedback. Delay time ranges from a few samples to about 1/10th
second, with reverse playback times about half the delay time.


### 3. Free-running Loop

- FV-1 Program: 3
- Source File: 3_frlf.asm
- X (POT0): Delay Time
- Y (POT1): Feedback Amount
- Z (POT2): Modulation left=LFO center=off right=random

Looping reverse delay with transitions across zero crossings.
Delay time ranges from approximately 0.01 seconds to just under
1 second, with reverse playback times about half the delay time.
Modulation of delay time is staged so changes happen after each
reverse playback is finished.


## CONNECTIONS:

The Elta Console is a mono input, mono output effect with the
input channel connected to ADCL. ADCL is read as the effect
input and ADCR is ignored. Both DACL and DACR are connected
to the output and are both written with a 100% wet effect signal.


## PROGRAMMING:

Connect the Elta Console cartridge to an I2C programmer as shown
in the following diagram. If the programmer already includes pull-up
resistors on the I2C bus, the dashed section should be omitted.

![Programmer Wiring Diagram](progwiring.svg "Programmer Wiring")

\* Note: When using a socket, Elta Console cartridges are reversible.


## LICENSE:

To the extent possible under law, the author(s) have dedicated
all copyright and related and neighboring rights to this software
to the public domain worldwide. This software is distributed
without any warranty.


## LINKS:

- Elta Console: <https://www.eltamusic.com/console>
- FV-1 assembler: <https://github.com/ndf-zz/asfv1>
- Spin FV-1 website: <http://spinsemi.com/products.html>
