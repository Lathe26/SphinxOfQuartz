# Overview
**_Sphinx of Quartz_** is an program for the Mattel Electronics's Intellivision gaming console.  It was created as part of the research into the Mattel Electronics's **_Intellivision Kiosk Multiplexer_**.  The Kiosk Multiplexer is the informal modern name for the electronic hardware inside of demonstration kiosks that allowed customers to try out up 10 games while visiting a store.

Specifically, Sphinx of Quartz program has the following purposes:
1.  Play the sound effect that is hidden and unused in the Kiosk Multiplexer's ROM (i.e. dead code).
2.  Display all 26 characters of the Kiosk Multiplexer's unique font used when selecting different game cartridges.

To see a video demonstration of the Sphinx of Quartz program and the resulting research for the Intellivision Kiosk Multiplexer, see ![https://www.youtube.com/watch?v=3vMPc39v13g](https://www.youtube.com/watch?v=3vMPc39v13g)

Image of an Intellivision Kiosk Multiplexer:
![image of an Intellivision Kiosk Multiplexer](/Intellivision%20Kiosk%20Multiplexer.jpg)

Sphinx of Quartz executing at its main screen:
![image of Sphinx of Quartz executing](Sphinx%20of%20Quartz%20Executing.png)

## A Note on Oddities
Some of the graphics and text displayed in this program have a mildly humorous intent.  "Typos" in the displayed text and other odd behavior are deliberate and intended for entertainment purposes.

## Caveat for the Kiosk Multiplexer's unique font
To display the 26 characters of the Kiosk Multiplexer's unique font, one of two things needs to be done:
- Use actual Kiosk Multiplexer hardware with Sphinx of Quartz on a compatible game cartridge.  This Kiosk Multiplexer hardware is extremely rare.
- The Kiosk Multiplexer's ROM code is merged with the Sphinx of Quartz.  The combined program is then played on a normal Intellivision.

The latter option is easier to perform.  However, the Kiosk Multiplexer ROM code is not provided here.  When merged properly with Sphinx of Quartz, the combined code will execute on a normal Intellivision without the need for the addition Kiosk Multiplexer hardware.  The Intellivision will execute the game selection code at startup, simulating the Kiosk Multiplexer hardware with only 1 cartridge installed that contained Sphinx of Quartz.  This startup execution includes displaying all 26 characters via the phrase "SPHINX OF QUARTZ JUDGE MY BLACK VOW".

![image of unique font](/Sphinx%20of%20Quartz%20Judge%20My%20Black%20Vow.gif)

To merge Sphinx of Quartz with the Kiosk Multiplexer's ROM code:
1.  Obtain a copy of the Kiosk Multiplexer's ROM code as a binary file (i.e., a \*.bin file)
2.  Implement optional hacks to the ROM (not described here)
3.  Append the Kiosk Multiplexer \*.bin data to the end of SphinxOfQuartz.bin
4.  Update SphinxOfQuartz.cfg to reflect the changes.
5.  Load the merged \*.bin and \*.cfg into an Intellivision emulator or onto a multi-cart to run on actual Intellivision hardware.

Example SphinxOfQuartz.cfg before updating, assuming SphinxOfQuartz.bin is 4K words (8K bytes) in size:
```
[mapping]
$0000 - $0FFF = $5000
```

Example SphinxOfQuartz.cfg after updating:
```
[mapping]
$0000 - $0FFF = $5000
$1000 - $17FF = $7000
```

# Summary of files
`SphinxofQuartz.asm` - Assembly code with comments
`SphinxofQuartz.bin` - Program in \*.bin format.  Use with matching \*.cfg file.
`SphinxofQuartz.cfg` - The \*.cfg file that matches the \*.bin file.
`SphinxofQuartz.rom` - Program in \*.rom format.
`Sphinx of Quartz Judge My Black Vow.gif` - Screenshot of the Kiosk Multiplexer's unique font
`gram0001.gif` - A graphical memory dump of the Intellivision's video GRAM after Sphinx of Quartz has initialized it.


# Build instructions
Sphinx of Quartz has been successfully built with the jzintv-20181225-win32 release of the jzIntv emulator.  The jzIntv emulator include a number of development tools, including an assembler.  Newer versions of the jzIntv development tools should remain compatible with SphinxOfQuartz.asm.  jzIntv can be downloaded from ![http://spatula-city.org/~im14u2c/intv/](http://spatula-city.org/~im14u2c/intv/). 

SphinxOfQuartz.asm is an assembly file with extensive comments throughout.

To build the SphinxOfQuartz program files (\*.bin, \*.cfg, and \*.rom) and debugging files (\*.lst, \*.sym, and \*smap), execute the following command:
```
as1600.exe --cc3 -i <INCLUDE_PATH> -l SphinxOfQuartz.lst -s SphinxOfQuartz.sym -j SphinxOfQuartz.smap -m -o SphinxOfQuartz SphinxOfQuartz.asm
```
Substitute <INCLUDE_PATH> with the path to the examples/library folder (e.g., .../jzintv-20181225-win32/examples/library)
