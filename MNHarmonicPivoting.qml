/*
 * Copyright (C) 2025 Michael Norris
 *
 */

// this version requires MuseScore Studio 4.4 or later

import MuseScore 3.0
import QtQuick 2.9
import QtQuick.Controls 2.15
import Muse.UiComponents 1.0
import FileIO 3.0

MuseScore {
	version:  "1.0"
	description: "This plugin creates Harmonic Pivoting"
	menuPath: "Plugins.MNHarmonicPivoting";
	requiresScore: true
	title: "MN Harmonic Pivoting"
	id: mnharmonicpivoting
	thumbnailName: "MNHarmonicPivoting.png"
	
	// ** DEBUG **
	property var debug: true
	property var errorMsg: ''
	property var numLogs: 0
	
	// **** PROPERTIES **** //
	property var pitches: []
	property var pcs: []
	property var intervals: []

  onRun: {
		if (!curScore) return;
		dialog.titleText = 'MN HARMONIC PIVOTING';
		
		// ** VERSION CHECK ** //
		if (MuseScore.mscoreMajorVersion < 4 || (MuseScore.mscoreMajorVersion == 4 && MuseScore.mscoreMajorVersion < 4)) {
			dialog.msg = "<p><font size=\"6\">🛑</font> This plugin requires at MuseScore v. 4.4 or later.</p> ";
			dialog.show();
			return;
		}
		options.open();
	}
	
	function doPivoting () {
		options.close();
		//logError ('Rotation type = '+rotationType);
		// **** CHECK SELECTION **** //
		var staves = curScore.staves;
		var numStaves = curScore.nstaves;
		var startStaff = curScore.selection.startStaff;
		var endStaff = curScore.selection.endStaff;
		var endTick = curScore.selection.endSegment.tick;
		var scoreEndTick = curScore.lastSegment.tick;
		var elems = curScore.selection.elements;
		var lastBar;
		if (elems.length == 0) {
			dialog.msg = "<p><font size=\"6\">🛑</font> Please make a selection.</p> ";
			dialog.show();
			return;
		}
		if (startStaff != endStaff-1) {
			dialog.msg = "<p><font size=\"6\">🛑</font> Please select notes from a single staff.</p> "+startStaff+" != "+endStaff;
			dialog.show();
			return;
		}
		
		for (var i = 0; i < elems.length; i++) {
			var e = elems[i];
			if (!e.visible) continue;	
			var etype = e.type;
			if (etype == Element.CHORD) {
				if (e.notes.length > 1) {
					dialog.msg = "<p><font size=\"6\">🛑</font> One of the selected elements is a chord. Please only select single-pitch notes</p> ";
					dialog.show();
					return;
				}
				pitches.push(e.notes[0].pitch);
				pcs.push(e.notes[0].pitch % 12);
				lastBar = e.parent.parent;

				//logError ('pushed');
			} else {
				if (etype == Element.NOTE) {
					pitches.push(e.pitch);
					var pc = e.pitch % 12;
					pcs.push(pc);
					lastBar = e.parent.parent.parent;
					//logError ('pushed '+pc);
				}
			}
		}
		var numNotes = pitches.length;
		if (numNotes < 3) {
			dialog.msg = "<p><font size=\"6\">🛑</font> Please select at least 3 pitches</p> ";
			dialog.show();
			return;
		}
		var currentBar = lastBar.nextMeasure;
		if (currentBar == null || currentBar == undefined) {
			curScore.startCmd();
			cmd('append-measure');
			curScore.endCmd();
			scoreEndTick = curScore.lastSegment.tick;
			currentBar = lastBar.nextMeasure;
			if (currentBar == null || currentBar == undefined) {
				dialog.msg = "<p><font size=\"6\">🛑</font> Couldn’t create new bar</p> ";
				dialog.show();
				return;
			}
		}
		clearMeasure (currentBar);
		
		// create array of OPIs
		for (var i = 0; i < numNotes-1; i++ ) intervals.push (pitches[i+1]-pitches[i]);
		intervals.push(pitches[0] - pitches[numNotes-1]);
		
		// ** TO DO: CHECK NUM NOTES IN SELECTION ** //
		var cursor = curScore.newCursor();	
		cursor.filter = Segment.All;
		cursor.staffIdx = startStaff;
		
		var startTick = currentBar.firstSegment.tick;
		if (startTick == undefined || startTick > (scoreEndTick - division)) {
			dialog.msg = "<p><font size=\"6\">🛑</font> Starttick undefined or off the end</p> ";
			dialog.show();
			return;
		}
		
		
		// *** ADD A LAYOUT BREAK TO THE FINAL BAR *** //
		var layoutBreakTick = lastBar.firstSegment.tick;
		//logError ('Adding layout break at tick '+layoutBreakTick);
		cursor.rewindToTick(layoutBreakTick);
		var lb = newElement(Element.LAYOUT_BREAK);
		lb.layoutBreakType = LayoutBreak.LINE;
		curScore.startCmd();
		cursor.add(lb);
		curScore.endCmd();

		// *** UPDATE TIME SIGNATURE *** //
		cursor.rewindToTick(startTick);
		var ts = newElement(Element.TIMESIG);
		ts.timesig = fraction (numNotes,4);
		curScore.startCmd();
		cursor.add(ts);
		curScore.endCmd();
		cursor.filter = Segment.ChordRest;
		
		
		// *** ADD '12 TRANSPOSITIONS' NOTES *** //
		cursor.rewindToTick(startTick);
		var comment = newElement(Element.TEMPO_TEXT);
		comment.text = '12 TRANSPOSITIONS';
		comment.frameType = 1;
		comment.framePadding = 1.0;
		curScore.startCmd();
		cursor.add(comment);
		curScore.endCmd();

		// ** LOOP THROUGH TRANSPOSITIONS **//
		var currentTransposition, currentPitch = 0, pitch, pc, currentTick = startTick;
		for (currentTransposition = 0; currentTransposition < 12; currentTransposition ++) {
			
			// insert a system break every 4 bars
			if ((currentTransposition + 1) % 4 == 0) {
				cursor.rewindToTick(startTick);
				var lb = newElement(Element.LAYOUT_BREAK);
				lb.layoutBreakType = LayoutBreak.LINE;
				curScore.startCmd();

				cursor.add(lb);
				curScore.endCmd();

			}
			
			pitch = pitches[0] + currentTransposition;
			var numCommonTones = 0;
			for (currentPitch = 0; currentPitch < numNotes; currentPitch ++) {
				pc = pitch % 12;
				var isCT = pcs.includes(pc);
				numCommonTones += isCT;
				
				// add the Note at the current tick
				curScore.startCmd();
				cursor.rewindToTick(currentTick);
				cursor.addNote(pitch,false);
				
				// addNote advances the cursor so we need to go back
				cursor.rewindToTick(currentTick);
				curScore.endCmd();
				var theNote = cursor.element;
				
				// set to no stem, and a minim notehead if it's a new PC
				theNote.noStem = true;
				if (!isCT) theNote.notes[0].headType = NoteHeadType.HEAD_HALF;
				
				currentTick += division;
				if (currentTick > (scoreEndTick - division)) {
					curScore.startCmd();
					cmd('append-measure');
					curScore.endCmd();
					scoreEndTick = curScore.lastSegment.tick;
					currentBar = currentBar.nextMeasure;
					if (currentBar == null || currentBar == undefined) {
						dialog.msg = "<p><font size=\"6\">🛑</font> HERE: Couldn’t create new bar</p> ";
						dialog.show();
						return;
					}
					if (currentTick > (scoreEndTick - division)) {
						dialog.msg = "<p><font size=\"6\">🛑</font> Couldn’t create enough to account for startTick</p> ";
						dialog.show();
						return;
					}
				}
				if (!cursor.measure.is(currentBar)) {
					currentBar = cursor.measure;
					clearMeasure (currentBar);
				}
				if (currentPitch < numNotes - 1) pitch += intervals[currentPitch]
			}
			cursor.rewindToTick(startTick);
			var comment = newElement(Element.FINGERING);
			comment.text = 'T<sub>'+currentTransposition+'</sub> ('+numCommonTones+' CT)';
			comment.align = 0;
			curScore.startCmd();

			cursor.add(comment);
			curScore.endCmd();

			startTick = currentTick;
		}
		cursor.rewindToTick(startTick);
		var comment = newElement(Element.TEMPO_TEXT);
		comment.text = '12 INVERSIONS';
		comment.frameType = 1;
		comment.framePadding = 1.0;
		curScore.startCmd();

		cursor.add(comment);
		curScore.endCmd();

		var currentInversion;
		for (currentInversion = 0; currentInversion < 12; currentInversion ++) {
			
			// insert a system break every 4 bars
			if ((currentInversion + 1) % 4 == 0) {
				cursor.rewindToTick(startTick);
				var lb = newElement(Element.LAYOUT_BREAK);
				lb.layoutBreakType = LayoutBreak.LINE;
				curScore.startCmd();
				cursor.add(lb);
				curScore.endCmd();
			}
			pitch = pitches[0] + currentInversion;
			var numCommonTones = 0;
			for (currentPitch = 0; currentPitch < numNotes; currentPitch ++) {
				pc = pitch % 12;
				var isCT = pcs.includes(pc);
				numCommonTones += isCT;
				
				// add the note
				curScore.startCmd();
				cursor.rewindToTick(currentTick);
				cursor.addNote(pitch,false);
				// addNote advances the cursor so we need to go back
				cursor.rewindToTick(currentTick);
				curScore.endCmd();
				
				// set note to no stem and a minim notehead if it's a new pc
				var theNote = cursor.element;
				theNote.noStem = true;
				if (!isCT) theNote.notes[0].headType = NoteHeadType.HEAD_HALF;
				
				currentTick += division;
				if (currentTick > (scoreEndTick - division)) {
					curScore.startCmd();
					cmd('append-measure');
					curScore.endCmd();
					scoreEndTick = curScore.lastSegment.tick;
					currentBar = currentBar.nextMeasure;
					if (currentBar == null || currentBar == undefined) {
						dialog.msg = "<p><font size=\"6\">🛑</font> HERE: Couldn’t create new bar</p> ";
						dialog.show();
						return;
					}
					if (currentTick > (scoreEndTick - division)) {
						dialog.msg = "<p><font size=\"6\">🛑</font> Couldn’t create enough to account for startTick</p> ";
						dialog.show();
						return;
					}
				}
				if (!cursor.measure.is(currentBar)) {
					currentBar = cursor.measure;
					clearMeasure (currentBar);
				}
				if (currentPitch < numNotes - 1) pitch -= intervals[currentPitch]
			}
			cursor.rewindToTick(startTick);
			var comment = newElement(Element.FINGERING);
			comment.text = 'T<sub>'+currentInversion+'</sub>I ('+numCommonTones+' CT)';
			
			comment.align = 0;
			curScore.startCmd();
			cursor.add(comment);
			curScore.endCmd();

			var pitch;
			startTick = currentTick;
			
		}
		
		// ** SHOW INFO DIALOG ** //
		if (errorMsg != "") errorMsg = "<p>————————————<p><p>ERROR LOG (for developer use):</p>" + errorMsg;
		errorMsg = "<p>PIVOTING COMPLETED</p><p><font size=\"6\">🎉</font> It is now a good idea to Select All and run Tools → Optimize Enharmonic Spellings.</p>"+errorMsg;
		
		dialog.msg = errorMsg;
		dialog.titleText = 'MN HARMONIC PIVOTING';
		dialog.show();
	}
	
	function clearMeasure(measure) {
		if (!measure) {
			console.log("No measure provided to clear.");
			return;
		}
	
		// Iterate through segments (voices/staves within a measure)
		var segment = measure.firstSegment;
		while (segment) {
			// Iterate through elements within each segment
			var element = segment.firstElement;
			while (element) {
				removeElement(element); // Assuming removeElement is a function provided by the API
				element = element.next;
			}
			segment = segment.next;
		}
	}
	

	
	function logError (str) {
		numLogs ++;
		errorMsg += "<p>"+str+"</p>";
	}
	
	//MARK: OPTIONS DIALOG
	StyledDialogView {
		id: options
		title: "MN HARMONIC PIVOTING"
		contentHeight: 300
		contentWidth: 740
		property color backgroundColor: ui.theme.backgroundSecondaryColor
		
		Text {
			id: styleText
			anchors {
				left: parent.left;
				leftMargin: 20;
				top: parent.top;
				topMargin: 20;
				bottomMargin: 10;
			}
			text: "Options"
			font.bold: true
			font.pointSize: 16
			color: ui.theme.fontPrimaryColor
		}
		
		Rectangle {
			id: rect
			anchors {
				left: styleText.left;
				top: styleText.bottom;
				topMargin: 10;
			}
			width: parent.width-45
			height: 1
			color: ui.theme.fontPrimaryColor
		}
		
		Text {
			id: infoText
			anchors {
				left: parent.left;
				leftMargin: 20;
				right: parent.right;
				rightMargin: 20;
				top: rect.bottom;
				topMargin: 20;
				bottomMargin: 10;
			}
			text: "<p>‘Harmonic pivoting’ is a simple procedure of generating all 12 transpositions and 12 inversions of a pitch series, and for each one, calculating the number of common tones. This allows composers to understand which transpositions and inversions will sound ‘closer’ and which will sound more ‘distant’.</p><p>&nbsp;</p><p>🛑 This plug-in is intended to generate a number of pitch series, and will delete any notes to the right of the selected pitches. It is best used on a new blank score with the row in crotchets in the first bar.</P>"
			font.pointSize: 14
			color: ui.theme.fontPrimaryColor
			wrapMode: Text.Wrap
		}
		
		FlatButton {
			text: "Cancel"
			width: 150
			anchors {
				left: parent.left;
				leftMargin: 20;
				bottom: parent.bottom
				bottomMargin: 10;
			}
			buttonRole: ButtonBoxModel.ApplyRole
			buttonId: ButtonBoxModel.Cancel
			onClicked: {
				options.close()
			}
		}
		ButtonBox {
			anchors {
				horizontalCenter: parent.horizontalCenter
				bottom: parent.bottom
				margins: 10
			}
			buttons: [ ButtonBoxModel.Ok ]
			navigationPanel.section: dialog.navigationSection
			onStandardButtonClicked: function(buttonId) {
				if (buttonId === ButtonBoxModel.Ok) {
					doPivoting()
				}
			}
		}
	}

	
	StyledDialogView {
		id: dialog
		title: "PIVOTING COMPLETED"
		contentHeight: 252
		contentWidth: 505
		margins: 10
		property var msg: ""
		property var titleText: ""
		property var fontSize: 18

		Text {
			id: theText
			width: parent.width-40
			anchors {
				left: parent.left
				top: parent.top
				leftMargin: 20
				topMargin: 20
			}
			text: dialog.titleText
			font.bold: true
			font.pointSize: dialog.fontSize
			color: ui.theme.fontPrimaryColor
		}
		
		Rectangle {
			id: dialogRect
			anchors {
				top: theText.bottom
				topMargin: 10
				left: parent.left
				leftMargin: 20
			}
			width: parent.width-45
			height: 2
			color: ui.theme.fontPrimaryColor
		}

		ScrollView {
			id: view
			
			anchors {
				top: dialogRect.bottom
				topMargin: 10
				left: parent.left
				leftMargin: 20
			}
			height: parent.height-100
			width: parent.width-40
			leftInset: 0
			leftPadding: 0
			ScrollBar.vertical.policy: ScrollBar.AsNeeded
			TextArea {
				textFormat: Text.RichText
				text: dialog.msg
				wrapMode: TextEdit.Wrap
				leftInset: 0
				leftPadding: 0
				readOnly: true
				color: ui.theme.fontPrimaryColor
			}
		}

		ButtonBox {
			anchors {
				horizontalCenter: parent.horizontalCenter
				bottom: parent.bottom
				margins: 10
			}
			buttons: [ ButtonBoxModel.Ok ]
			navigationPanel.section: dialog.navigationSection
			onStandardButtonClicked: function(buttonId) {
				if (buttonId === ButtonBoxModel.Ok) {
					dialog.close()
				}
			}
		}
	}
	
	ApplicationWindow {
		id: progress
		title: "PROGRESS"
		property var progressPercent: 0
		visible: false
		flags: Qt.Dialog | Qt.WindowStaysOnTopHint
		width: 500
		height: 200        

		ProgressBar {
			id: progressBar
			anchors {
				horizontalCenter: parent.horizontalCenter
				bottom: parent.verticalCenter
				margins: 10
			}
			value: progress.progressPercent
			to: 100
		}
		
		FlatButton {            
			accentButton: true
			text: "Ok"
			anchors {
				horizontalCenter: parent.horizontalCenter
				bottom: parent.bottom
				margins: 10
			}
			onClicked: progress.close()
		}
	}

}
