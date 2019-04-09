Tandy13h
========

Tandy13h is an experimental VGA/MCGA mode 13h emulation TSR driver for the
Tandy Video II adapter that can be found in the Tandy 1000 RL, SL and TL
series of computers.

Usage
-----
The TSR driver can be loaded via

    TANDY13H.COM

It can be unloaded via

    TANDY13H.COM /U

Once the driver has been loaded, programs can switch to mode 13h as if
they were running on a system equipped with an MCGA or VGA card.

How it works
------------
This driver maps the 256 color mode of VGA and MCGA cards with its 320x200
pixels to the Tandy Video II adapter's 16 color mode with 640x200 pixels.
Both those modes use segment A000h as frame buffer and share practically
the same memory model.
Every 256 color pixel will show up as a pair of 16 color pixels.

Limitations
-----------
The output on-screen will look similar to a 256 color picture with a
palette that consists of the average colors of all possible pairs of CGA
colors, albeit with vertical stripes.  This implicit palette cannot be
changed.
Furthermore, any functionality that bypasses the video BIOS cannot be
reproduced.
