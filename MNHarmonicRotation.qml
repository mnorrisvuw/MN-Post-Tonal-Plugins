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
	description: "This plugin creates Harmonic Rotation patters"
	menuPath: "Plugins.MNHarmonicRotation";
	requiresScore: true
	title: "MN Harmonic Rotation"
	id: mnharmonicrotation
	thumbnailName: "MNHarmonicRotation.png"
	FileIO { id: versionnumberfile; source: Qt.resolvedUrl("./assets/versionnumber.txt").toString().slice(8); onError: { console.log(msg); } }

	
	// ** DEBUG **
	property var debug: true
	property var errorMsg: ''
	property var numLogs: 0
	
	// **** PROPERTIES **** //
	property var pitches: []
	property var intervals: []
	property var rotationType: 0

  onRun: {
		if (!curScore) return;
		dialog.titleText = 'MN HARMONIC ROTATION';
		
		// ** VERSION CHECK ** //
		if (MuseScore.mscoreMajorVersion < 4 || (MuseScore.mscoreMajorVersion == 4 && MuseScore.mscoreMajorVersion < 4)) {
			dialog.msg = "<p><font size=\"6\">🛑</font> This plugin requires at MuseScore v. 4.4 or later.</p> ";
			dialog.show();
			return;
		}
		options.open();
	}
	
	function doRotation () {
		rotationType = options.rotationType;
		options.close();
		//logError ('Rotation type = '+rotationType);
		// **** CHECK SELECTION **** //
		var staves = curScore.staves;
		var numStaves = curScore.nstaves;
		var versionNumber = versionnumberfile.read().trim();
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
				lastBar = e.parent.parent;

				//logError ('pushed');
			} else {
				if (etype == Element.NOTE) {
					pitches.push(e.pitch);
					lastBar = e.parent.parent.parent;
					//logError ('pushed');
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
		cursor.rewindToTick(startTick);
		var ts = newElement(Element.TIMESIG);
		ts.timesig = fraction (numNotes,4);
		
		curScore.startCmd();
		cursor.add(ts);
		curScore.endCmd();

		// ** LOOP THROUGH ROTATION **//
		// ** NB — endStaff IS EXCLUDED FROM RANGE — SEE MUSESCORE DOCS ** //
		
		var currentTransposition, currentTranspositionIndex, currentRotation, currentRotationTransposition, currentPitch = 0;

		for (currentTranspositionIndex = 0; currentTranspositionIndex < numNotes; currentTranspositionIndex ++) {
			currentTransposition = pitches[currentTranspositionIndex]-pitches[0];
			
			cursor.rewindToTick(startTick);
			var comment = newElement(Element.STAFF_TEXT);
			comment.text = 'Transposition '+(currentTranspositionIndex + 1);
			cursor.add(comment);
			var pitch;
			for (currentRotation = 0; currentRotation < numNotes; currentRotation ++) {
				

				// ** REWIND TO START OF NEW BAR ** //
				
				switch (rotationType) {
					
					// STANDARD ROTATION
					case 0:
					case 1:
						pitch = pitches[0] + currentTransposition;
						break;
					
					// LINE CHAINING
					case 2:
					case 3:
						if (currentRotation == 0) pitch = pitches[0] + currentTransposition;
						break;
					
					// LINE STEERING
					case 4:
					case 5:
						pitch = pitches[currentRotation] + currentTransposition;
						break;
				}
				
				curScore.startCmd();
				cursor.rewindToTick(startTick);
				cursor.setDuration(1,4); // set to crotchet
				cursor.addNote(pitch,false);
				curScore.endCmd();
				//errorMsg += "\nTick "+cursor.tick+': adding '+pitch;
				startTick += division;
				var intervalIndex;
				for (currentPitch = 1; currentPitch < numNotes; currentPitch ++) {
					if (rotationType < 4) {
						intervalIndex = (currentRotation + currentPitch - 1) % numNotes;
						//errorMsg += "\nIntervalIndex = "+intervalIndex;
					} else {
						// LINE STEERING WE NEED TO ROTATE IN OPPOSITE DIRECTION
						intervalIndex = currentPitch - currentRotation - 1;
						if (intervalIndex < 0) intervalIndex += numNotes;
					}
					var interval = intervals[intervalIndex];
					
					// CALCULATE INVERTED INTERVAL?
					if (rotationType % 2 == 1 && currentRotation % 2 == 1) interval *= -1;
					pitch += interval;
					
					curScore.startCmd();
					cursor.rewindToTick(startTick);
					cursor.addNote(pitch,false);
					//cursor.next();
					curScore.endCmd();
					//errorMsg += "\nTick "+cursor.tick+': adding'+pitch;
					startTick += division;
					if (startTick > (scoreEndTick - division)) {
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
						if (startTick > (scoreEndTick - division)) {
							dialog.msg = "<p><font size=\"6\">🛑</font> Couldn’t create enough to account for startTick</p> ";
							dialog.show();
							return;
						}
					}
				}
			}
		}
		
		// ** SHOW INFO DIALOG ** //
		if (errorMsg != "") errorMsg = "<p>————————————<p><p>ERROR LOG (for developer use):</p>" + errorMsg;
		errorMsg = "<p>ROTATION COMPLETED</p><p><font size=\"6\">🎉</font></p>"+errorMsg;
		
		dialog.msg = errorMsg;
		dialog.titleText = 'MN HARMONIC ROTATION '+versionNumber;
		dialog.show();
	}
	
	

	
	function logError (str) {
		numLogs ++;
		errorMsg += "<p>"+str+"</p>";
	}
	
	//MARK: OPTIONS DIALOG
	StyledDialogView {
		id: options
		title: "MN HARMONIC ROTATION"
		contentHeight: 400
		contentWidth: 740
		property color backgroundColor: ui.theme.backgroundSecondaryColor
		
		Settings {
			property alias settingsRotationType: options.rotationType
		}
		
		property var rotationType
		
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
			text: "<p>Harmonic rotation is a 20th-century technique for generating new pitch fields/series by rotating and transposing a selected set of pitches. It was developed by Ernst Krenek, and was used by a number of composers such as Igor Stravinsky, Pierre Boulez and Oliver Knussen.</p><p>&nbsp;</p><p>This plugin will automatically generate a number of rotations for you, using a set of new algorithms devised by Michael Norris: STANDARD ROTATION is the original technique; LINE CHAINING uses the last pitch-class of each rotation to guide the transposition levels of the next rotation; LINE STEERING uses the original pitches to guide the transposition levels; INVERTED algorithms will invert the intervals in every second rotation.</p><p>&nbsp;</p><p>⚠️ This plug-in is intended to generate a number of pitch series, and will delete any notes to the right of the selected pitches. It is best used on a new blank score with the row in crotchets in the first bar.</P>"
			font.pointSize: 14
			color: ui.theme.fontPrimaryColor
			wrapMode: Text.Wrap
		}
		
		ComboBox {
			id: comboBox
			width: 300
			height: 50
			leftPadding: 10
			currentIndex: options.rotationType
			anchors {
				left: parent.left;
				leftMargin: 20;
				top: infoText.bottom;
				topMargin: 20;
			}
			model: ["Standard Rotation","Inverted Standard Rotation","Line Chaining","Inverted Line Chaining","Line Steering", "Inverted Line Steering"];
			font.pointSize: 16
			onCurrentIndexChanged: {
				options.rotationType = comboBox.currentIndex;
			}
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
					doRotation()
				}
			}
		}
	}

	
	StyledDialogView {
		id: dialog
		title: "ROTATION COMPLETED"
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
