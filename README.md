# MN Harmonic Rotation Plugin for MuseScore

A plug-in for [MuseScore Studio 4.5](https://musescore.org/en) that automatically generates a set of pitches using the ‘harmonic rotation’ technique popularised by Krenek, Stravinsky, Boulez and others.

### MN HARMONIC ROTATION

* ‘Rotation technique’, sometimes called ‘harmonic rotation’ or ‘serial rotation’, was a technique developed by Ernst Krenek, and subsequently used by Stravinsky, Boulez, Knussen and others.
* In it, a series of notes, usually 5–7 pitches, is rotated to the left and then transposed back onto the original pitch.
* This plugin also includes several new rotation algorithms designed by Michael Norris to overcome some of the limitations of standard rotation technique.
* Because the intervals are not changing, it creates a strong sense of ‘intervallic coherence’ or ‘intervallic economy’; at the same time, the pitch collection is changing, creating a sense of macroharmonic flux. This dual musical effect of the technique made it fruitful for a number of post-tonal composers.
* It works with any type of material, quasi-tonal/scalar (as in Krenek) or non-tonal (as in Stravinsky & Boulez).
* To use, create a new score, and enter a series of single pitches in the first bar or two. Select these pitches and then run the plugin. It will generate a series of pitch collections that you can then use melodically and/or harmonically in your composition.
* See below for more detailed instructions and descriptions of the various rotation techniques.

***

## Installation

*MN Harmonic Rotation requires MuseScore Studio 4.5.2 or later.*

**INSTRUCTIONS**:
* **Download** the project as a zip file either from the green Code button above, or from the direct download link below.
* **Extract it** using archive extraction software
* **Copy and paste (or move) the entire folder** into MuseScore’s plugins folder, configurable at [Preferences→General→Folders](https://musescore.org/en/handbook/4/preferences). The default directories are:
    * **Mac OS**: ~/Documents/MuseScore4/Plugins/
    * **Windows**: C:\Users\YourUserName\Documents\MuseScore4\Plugins\
    * **Linux**: ~/Documents/MuseScore4/Plugins
* **Open MuseScore** or quit and relaunch it if it was already open
* Click **Home→Plugins** or **Plugins→Manage plugins...**
* Click the MN Harmonic Rotation icon and click ‘**Enable**’
* The plugin should now be available from the **Plugins** menu

### Direct Download

Direct downloads of the Zip file can be found on the [releases page](https://github.com/mnorrisvuw/MNRotationPlugins/releases).

## <a id="use"></a>How to use
* In a blank score, enter your pitches as crotchets/quarter notes in the first bar(s).
* Select the pitches and run this plug-in
* As this plug-in generates new pitch collections, it will delete any music currently entered to the right of the selection. Therefore it is best if you work on a new blank score.
* The following algorithms are available:
    * **Standard Rotation**: the pitch collection is rotated to the left and transposed to be on the same pitch as the first pitch of the series. This entire process is then transposed onto each of the pitches
    * **Inverted Standard Rotation**: as above, except every second rotation has its intervals inverted
    * **Line Chaining**: similar to the standard rotation technique, except that each rotation is transposed onto the last pitch of the previous rotation. Note: if used melodically, you likely would not repeat the pitch. 
    * **Inverted Line Chaining**: as above, except every second rotation has its intervals inverted
    * **Line Steering**: the pitch collection is rotated to the right and transposed to be on the next pitch in the original sequence. This has a fractal quality: the original sequence can be seen linking the first notes of each rotation.
    * **Inverted Line Steering**: as above, except every second rotation has its intervals inverted


## <a id="feedback"></a>Feedback, requests and bug reports

* Please send all feedback, feature requests and bug reports to michael.norris@vuw.ac.nz

* For bug reports, especially the ‘non-completion bugs’ mentioned above (i.e. the final dialog box does not show), **please send me your MuseScore file and the name of the plug-in.**

## License

This project is licensed under the terms of the GNU General Public License v3.0.  
See [LICENSE](LICENSE) for details.
