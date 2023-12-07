import MuseScore 3.0
import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Window 2.0

MuseScore {
    property var pluginName: qsTr("Easy Monosyllabic Lyrics", "title")

    version: "1.0.0"
    description: qsTr("Input Monosyllabic Lyrics easily in MuseScore", "description")
    menuPath: "Plugins." + pluginName

    requiresScore: true

    // MuseScore 3 and 4 compat
    Component.onCompleted: {
        if (mscoreMajorVersion >= 4) {
            title = pluginName
            thumbnailName = "EasyMonosyllabicLyrics.png"
            categoryCode = "lyrics"
        }
    }
    function _quit() {
        (typeof(quit) === 'undefined' ? Qt.quit : quit)();
    }

    onRun: {
        inputDialog.visible = true;
		lyricsInput.forceActiveFocus();
    }

    function reacquireFocus() {
        inputDialog.requestActivate();
        lyricsInput.forceActiveFocus();
    }

    Window {
        id: inputDialog
        visible: false  // prevent dialog flashing by on initialization
        title: pluginName

        width: 480
        height: 80

        Item {
            anchors.fill: parent

            TextField {
                id: lyricsInput

                anchors.top: parent.top
                anchors.left: parent.left

                width: parent.width
                height: 48

                placeholderText: qsTr("Input here...", "Placeholder")
                selectByMouse: true

                onTextEdited: {
                    curScore.startCmd();
                    var currentValue = [null, Placement.ABOVE, Placement.BELOW][placementSelector.currentIndex];
                    script.applyLyricsToScore(script.splitLyrics(text), verseSelector.value, currentValue);
                    curScore.endCmd();

                    reacquireFocus();
                }
            }

            SpinBox {
                id: verseSelector

                anchors.bottom: parent.bottom
                anchors.left: parent.left

                width: 128
                height: 32

                from: 0
                to: 999

                textFromValue: function(value, locale) { return value + 1 + "."; }
                valueFromText: function(text, locale) { return parseInt(text) - 1; }

                onValueModified: {
                    curScore.startCmd();
                    script.restorePreviousLyrics();
                    var currentValue = [null, Placement.ABOVE, Placement.BELOW][placementSelector.currentIndex];
                    script.applyLyricsToScore(script.splitLyrics(lyricsInput.text), value, currentValue);
                    curScore.endCmd();

                    reacquireFocus();
                }
            }

            Item {
                id: verseRight
                
                anchors.bottom: parent.bottom
                anchors.left: verseSelector.right

                width: 4
            }

            ComboBox {
                id: placementSelector

                anchors.bottom: parent.bottom
                anchors.left: verseRight.right

                width: 112
                height: 32
                
                textRole: "text"

                model: [
                    { value: null, text: qsTr("None", "Placement") },
                    { value: Placement.ABOVE, text: qsTr("Above", "Placement") },
                    { value: Placement.BELOW, text: qsTr("Below", "Placement") }
                ]
                
                onActivated: {
                    var currentValue = [null, Placement.ABOVE, Placement.BELOW][currentIndex];
                    curScore.startCmd();
                    script.applyLyricsToScore(script.splitLyrics(lyricsInput.text), verseSelector.value, currentValue);
                    curScore.endCmd();

                    reacquireFocus();
                }
            }
            
            Button {
                id: cancelButton

                anchors.bottom: parent.bottom
                anchors.right: confirmLeft.left

                width: 80
                height: 32

                text: qsTr("Revert", "Action")

                onClicked: {
                    curScore.startCmd();
                    script.restorePreviousLyrics();
                    curScore.endCmd();
                    lyricsInput.text = "";
                    inputDialog.close();
                    _quit();
                }
            }

            Item {
                id: confirmLeft
                
                anchors.bottom: parent.bottom
                anchors.right: confirmButton.left

                width: 4
            }

            Button {
                id: confirmButton

                anchors.bottom: parent.bottom
                anchors.right: parent.right

                width: 80
                height: 32

                text: qsTr("Done", "Action")

                onClicked: {
                    curScore.startCmd();
                    script.confirm();
                    curScore.endCmd();
                    lyricsInput.text = "";
                    inputDialog.close();
                    _quit();
                }
            }
        }
    }

    property var script: (function() {
        function splitLyrics(lyrics) {
            const combineRules = [
                { previous: /[a-zA-Z'ａ-ｚＡ-Ｚ＇]/ , current: /[a-zA-Z'ａ-ｚＡ-Ｚ＇]/ }, // 英単語の結合
                // { previous: /[\p{Ll}\p{Lt}\p{Lu}]/u , current: /[\p{Ll}\p{Lt}\p{Lu}]/u }, // 小文字と大文字の結合
                { previous: /[ぁ-ゟ]/ , current: /[ぁぃぅぇぉゃゅょゎゕゖ]/ }, // 小書き文字の一部と濁点半濁点は前のひらがなと結合
                { previous: /[ァ-ヿ]/ , current: /[ァィゥェォャュョヮヵヶ゙゚゛゜]/ }, // 小書き文字の一部は前のカタカナと結合
                { previous: /[ｦ-ﾝ]/, current: /[ｧ-ｮ]/}, // 小書き文字の一部は前の半角カタカナと結合
                { previous: /[ぁ-ゟァ-ヿｦ-ﾝ]/ , current: /[゙゚゛゜ﾞﾟ]/ }, // 濁点半濁点は前の仮名と結合
                { previous: /./, current: /[,.:;!?､｡，、。：；！？]/ }, // 句読点や記号は前の文字と結合
                { previous: /[‘“(（｢「『]/, current: /\S/ }, // 開き記号は後の文字と結合
                { previous: /\S/, current: /[’”)）｣」』]/}, // 閉じ記号は前の文字と結合
                { previous: /\S/, current: /[+＋]/ }, // プラス記号は前の文字と結合
                { previous: /[+＋]/, current: /\S/ }, // プラス記号は後の文字と結合
                { previous: /[^-_]/, current: /-/ }, // ハイフンは前のハイフンまたはアンダーバー以外の文字と結合
            ];

            var result = [];
            var currentGroup = "";

            for (var i = 0; i < lyrics.length; i++) {
                const currentChar = lyrics[i];
                const previousChar = currentGroup.length > 0 ? currentGroup[currentGroup.length - 1] : "";

                var shouldCombine = false;

                // 前の文字と結合するかどうかを判定
                for (var ruleId = 0; ruleId < combineRules.length; ruleId++ ) {
                    var rule = combineRules[ruleId];
                    if (rule.current.test(currentChar) && rule.previous.test(previousChar)) {
                        shouldCombine = true;
                        break;
                    }
                }

                if (shouldCombine) {
                    currentGroup += currentChar;
                } else {
                    if (currentGroup != "") {
                        result.push(currentGroup.replace(/[+＋]/g, "")); // currentGroupからプラス記号を除去して追加
                    }
                    currentGroup = currentChar.replace(/\s/g, ""); // 空白文字の場合は追加しない
                }
            }

            if (currentGroup != "") {
                result.push(currentGroup.replace(/[+＋]/g, ""));
            }

            return result;
        }

        var previousLyrics = {};
        var previousLargestTick = {};
        var previousVerse = 0;
        var nextStartTick = {};

        function getTrackAndTick() {
            var result = [];

            if (curScore.selection.isRange) {
                var selection = curScore.selection;
                var cursor = curScore.newCursor();
                for (var staff = selection.startStaff; staff < selection.endStaff; staff++) {
                    cursor.rewind(Cursor.SELECTION_START);
                    cursor.track = staff * 4;
                    while (cursor.segment && cursor.tick < selection.endSegment.tick + 1) {
                        if (cursor.element.type == Element.CHORD) {
                            result.push( { track: cursor.track, startTick: cursor.tick } );
                            break;
                        }
                        cursor.next();
                    }
                }
            } else {
                for (var i in curScore.selection.elements) {
                    var element = curScore.selection.elements[i];
                    result.push( { track: element.track, startTick: getElementTick(element) } );
                }
            }
            
            return result;
        }

        function getElementTick(element) {
            var segment = element;
            while (segment.parent && segment.type != Element.SEGMENT) {
                segment = segment.parent;
            }
            return segment.tick;
        }

        function getSlurTieTicks(track, tick) {
            // 選択範囲を保存
            var isRange = curScore.selection.isRange;
            var selection = {};
            if (isRange) {
                selection.startTick = curScore.selection.startSegment.tick;
                selection.endTick = curScore.selection.endSegment.tick;
                selection.startStaff = curScore.selection.startStaff;
                selection.endStaff = curScore.selection.endStaff;
            } else {
                selection.elements = {};
                for (var i in curScore.selection.elements) {
                    selection.elements[i] = curScore.selection.elements[i];
                }
            }

            var tempCursor = curScore.newCursor();
            tempCursor.track = track;
            tempCursor.rewindToTick(tick);
            tempCursor.next();

            curScore.startCmd();
            curScore.selection.clear();
            curScore.selection.selectRange(tick, tempCursor.tick, Math.floor(track / 4), Math.floor(track / 4) + 1);
            curScore.endCmd();

            var minSlurTicks = 0;
            var maxTieTicks = 0;
            for (var i in curScore.selection.elements) {
                var element = curScore.selection.elements[i];
                if (element.track != track) {
                    continue;
                }
                if (element.type == Element.SLUR) {
                    if ((minSlurTicks == 0 || minSlurTicks > element.spannerTicks.ticks) && element.spannerTick.ticks == tick) {
                        minSlurTicks = element.spannerTicks.ticks;
                    }
                } else if (element.type == Element.NOTE) {
                    var tieTicks = getElementTick(element.lastTiedNote) - tick;
                    if (maxTieTicks == 0 || maxTieTicks < tieTicks) {
                        maxTieTicks = tieTicks;
                    }
                }
            }

            // 選択範囲を元に戻す
            curScore.startCmd();
            curScore.selection.clear();
            if (isRange) {
                curScore.selection.selectRange(selection.startTick, selection.endTick, selection.startStaff, selection.endStaff);
            } else {
                for (var i in selection.elements) {
                    var element = selection.elements[i];
                    curScore.selection.select(element, true);
                }
            }
            curScore.endCmd();

            // minSlurTicks または maxTieTicks の大きい方を返す
            return minSlurTicks > maxTieTicks ? minSlurTicks : maxTieTicks;
        }

        function getAndRemoveDuplicateLyric(cursor, verse) {
            var lyrics = cursor.element.lyrics;
            var isExist = false;
            var lyricElem = null;

            for (var i = 0; i < lyrics.length; i++) {
                if (lyrics[i].verse == verse) {
                    if (isExist) {
                        cursor.element.remove(lyrics[i]);
                        i--;
                    } else {
                        lyricElem = lyrics[i];
                        isExist = true;
                    }
                }
            }

            return lyricElem;
        }

        function savePreviousLyric(processIndex, track, tick, lyricElem) {
            if (previousLyrics[track] === undefined) {
                previousLyrics[track] = {};
            }
            if (previousLyrics[track][tick] === undefined) {
                if (lyricElem) {
                    if (lyricElem.syllabic == Lyrics.BEGIN || lyricElem.syllabic == Lyrics.MIDDLE) {
                        previousLyrics[track][tick] = lyricElem.text + "-";
                    } else {
                        previousLyrics[track][tick] = lyricElem.text;
                        if (lyricElem.lyricTicks.ticks) {
                            // メリスマの場合はメリスマの最後まで保存
                            var tempCursor = curScore.newCursor();
                            tempCursor.track = track;
                            tempCursor.rewindToTick(tick);
                            while (tempCursor.tick < tick + lyricElem.lyricTicks.ticks) {
                                tempCursor.next();
                                if (tempCursor.element.type == Element.CHORD) {
                                    previousLyrics[track][tempCursor.tick] = "_";
                                }
                            }
                            tick = tempCursor.tick;
                        }
                    }
                } else {
                    previousLyrics[track][tick] = null;
                }
            }
            if (previousLargestTick[processIndex] === undefined || previousLargestTick[processIndex] < tick) {
                previousLargestTick[processIndex] = tick;
            }
        }

        function applyLyricsToScore(lyricsList, verse, placement) {
            previousVerse = verse;
            var processDataList = getTrackAndTick();
            var processIndex = 0;

            for (var pdi = 0; pdi < processDataList.length; pdi++) {
                var processData = processDataList[pdi];
                var track = processData.track;
                var cursor = curScore.newCursor();
                cursor.track = track;
                cursor.rewindToTick(processData.startTick);
                
                var ic = 0;
                var isInsideWord = false;
                var melismaStartElem = null;
                var melismaStartTick = 0;
                var slurTieEndTick = -1;
                const defaultPlacement = newElement(Element.LYRICS).placement;

                while (cursor.segment && (ic < lyricsList.length || cursor.tick <= previousLargestTick[processIndex])) {
                    if (cursor.element.type == Element.CHORD) {
						var isTieBack = !!cursor.element.notes[0].tieBack;
						if(isTieBack) { // repeat effect of `_` or `-`
							if(ic > 0) ic--;
						}
                    
                        var lyricElem = getAndRemoveDuplicateLyric(cursor, verse);
                        savePreviousLyric(processIndex, track, cursor.tick, lyricElem);

                        var newLyricText = lyricsList[ic] || previousLyrics[track][cursor.tick];

                        if (/[=＝]/.test(newLyricText)) {
                            var index = newLyricText.search(/[=＝]/);
                            var beforeText = newLyricText.substring(0, index);
                            var afterText = newLyricText.substring(index + 1);

                            if (slurTieEndTick == -1) {
                                var slurTieTicks = 0;

                                if (beforeText) {
                                    slurTieTicks = getSlurTieTicks(track, cursor.tick);
                                    slurTieEndTick = cursor.tick + slurTieTicks;
                                } else {
                                    cursor.prev();
                                    slurTieTicks = getSlurTieTicks(track, cursor.tick);
                                    slurTieEndTick = cursor.tick + slurTieTicks;
                                    cursor.next();
                                }

                                if (slurTieTicks) {
                                    newLyricText = beforeText || "ー";
                                    if (slurTieEndTick == cursor.tick) {
                                        slurTieEndTick = -1;
                                    } else {
                                        ic--;
                                    }
                                } else {
                                    slurTieEndTick = -1;
                                    if (beforeText != "" || afterText != "") {
                                        newLyricText = newLyricText.replace(/[=＝]/g, "ー").replace(/ーー/g, "ー");
                                    } else {
                                        ic++;
                                        if (ic == lyricsList.length) {
                                            nextStartTick[processIndex] = cursor.tick;
                                        }
                                        continue;
                                    }
                                }
                            } else if (cursor.tick == slurTieEndTick) {
                                slurTieEndTick = -1;
                                if (afterText) {
                                    newLyricText = beforeText ? afterText : "ー" + afterText;
                                } else {
                                    newLyricText = "ー";
                                }
                            } else if (cursor.tick < slurTieEndTick) {
                                newLyricText = "ー";
                                ic--;
                            }
                        }
                        
                        if (newLyricText && !isTieBack && newLyricText != "-" && newLyricText != "_") {
							// do not add text for tied notes
                            if (lyricElem === null) {
                                lyricElem = newElement(Element.LYRICS);
                                cursor.element.add(lyricElem);
                            }
                            lyricElem.text = newLyricText.replace(/[-_%]/g, "");
                            lyricElem.verse = verse;
                            lyricElem.placement = placement === null ? defaultPlacement : placement;
                            if (newLyricText.endsWith("-")) {
                                lyricElem.syllabic = isInsideWord ? Lyrics.MIDDLE : Lyrics.BEGIN;
                                isInsideWord = true;
                            } else {
                                lyricElem.syllabic = isInsideWord ? Lyrics.END : Lyrics.SINGLE;
                                isInsideWord = false;
                            }
                            melismaStartElem = lyricElem;
                            melismaStartTick = cursor.tick;
                            lyricElem.lyricTicks = fraction(0, 1);
                        } else {
                            if (lyricElem !== null) {
                                cursor.element.remove(lyricElem);
                            }
                            if (newLyricText == "_") {
                                melismaStartElem.lyricTicks = fraction(cursor.tick - melismaStartTick, division * 4);
                            }
                        }
                        ic++;
                    }
                    cursor.next();
                    if (ic == lyricsList.length) {
                        nextStartTick[processIndex] = cursor.tick;
                    }
                }
                processIndex++;
            }
        }

        function restorePreviousLyrics() {
            var currentValue = [null, Placement.ABOVE, Placement.BELOW][placementSelector.currentIndex];
            applyLyricsToScore([], previousVerse, currentValue);
            nextStartTick = {};
            previousLyrics = {};
            previousLargestTick = {};
            previousVerse = verseSelector.value;
        }

        function confirm() {
            moveSelectionToNextElement();
            nextStartTick = {};
            previousLyrics = {};
            previousLargestTick = {};
        }

        function moveSelectionToNextElement() {
            var processDataList = getTrackAndTick();

            curScore.selection.clear();

            var processIndex = 0;

            for (var pdi = 0; pdi < processDataList.length; pdi++) {
                var processData = processDataList[pdi];
                var track = processData.track;
                var cursor = curScore.newCursor();
                cursor.track = track;
                cursor.rewindToTick(nextStartTick[processIndex] || processData.startTick);

                while (cursor.segment && cursor.element.type != Element.CHORD) {
                    cursor.next();
                }
                if (cursor.segment) {
                    curScore.selection.select(cursor.element.notes[0], true);
                }
                
                processIndex++;
            }
        }

        return {
            applyLyricsToScore: applyLyricsToScore,
            splitLyrics: splitLyrics,
            restorePreviousLyrics: restorePreviousLyrics,
            confirm: confirm
        }
    })()
}
