//
//  BackchannelContentTests.swift
//  AideaTests
//

import Foundation
import Testing
@testable import Aidea

/// Backchannel のパス解決とファイル本文の分解ロジックを検証する。
/// 仕様: docs/specs/backchannels/backchannel.md / remind.md
struct BackchannelPathTests {

    @Test("親ディレクトリが 0..8 の整数なら Companion index として返す")
    func extractsValidIndex() {
        for index in 0...8 {
            let url = URL(fileURLWithPath: "/p/.aidea/backchannels/\(index)/speech-20260806T090000.txt")
            #expect(BackchannelPath.extractCompanionIndex(from: url) == index)
        }
    }

    @Test("範囲外の数字は nil")
    func rejectsOutOfRange() {
        let url = URL(fileURLWithPath: "/p/.aidea/backchannels/9/speech-1.txt")
        #expect(BackchannelPath.extractCompanionIndex(from: url) == nil)
    }

    @Test("数字でないディレクトリは nil")
    func rejectsNonNumericDirectory() {
        let inbox = URL(fileURLWithPath: "/p/.aidea/backchannels/inbox/msg.json")
        #expect(BackchannelPath.extractCompanionIndex(from: inbox) == nil)
    }

    @Test("backchannels 直下のファイルは nil")
    func rejectsFileDirectlyUnderRoot() {
        let url = URL(fileURLWithPath: "/p/.aidea/backchannels/speech-1.txt")
        #expect(BackchannelPath.extractCompanionIndex(from: url) == nil)
    }
}

/// remind ファイル本文の分解 (speaker ID 行 / `表示:` 行 / 読み上げ本文)。
struct RemindContentTests {

    @Test("1 行目が数値なら speaker ID として切り出す")
    func parsesSpeakerId() {
        let result = RemindContent.parse("2\n買い物に行く時間だよ")

        #expect(result.speakerId == 2)
        #expect(result.speechText == "買い物に行く時間だよ")
        #expect(result.displayText == nil)
    }

    @Test("1 行目が数値でなければ全体が本文で speaker ID は nil")
    func parsesWithoutSpeakerId() {
        let result = RemindContent.parse("買い物に行く時間だよ")

        #expect(result.speakerId == nil)
        #expect(result.speechText == "買い物に行く時間だよ")
    }

    @Test("表示: 行は表示文として切り出し、読み上げ本文からは除く")
    func parsesDisplayLine() {
        let result = RemindContent.parse("2\n表示: 買い物\n買い物に行く時間だよ")

        #expect(result.speakerId == 2)
        #expect(result.displayText == "買い物")
        #expect(result.speechText == "買い物に行く時間だよ")
    }

    @Test("全角コロンの表示：も受理する")
    func parsesFullWidthColonMarker() {
        let result = RemindContent.parse("表示：買い物\n本文")

        #expect(result.displayText == "買い物")
        #expect(result.speechText == "本文")
    }

    @Test("表示: 行が複数あれば最初の 1 件だけを採用し残りは本文に残す")
    func usesFirstDisplayLineOnly() {
        let result = RemindContent.parse("表示: 一番目\n表示: 二番目\n本文")

        #expect(result.displayText == "一番目")
        #expect(result.speechText.contains("表示: 二番目"))
        #expect(result.speechText.contains("本文"))
    }

    @Test("表示: の値が空なら displayText は nil")
    func emptyDisplayValueBecomesNil() {
        let result = RemindContent.parse("表示: \n本文")

        #expect(result.displayText == nil)
        #expect(result.speechText == "本文")
    }
}

/// speech ファイル本文の分解 (1 行目の speaker ID)。
struct SpeechWatcherParseTests {

    @Test("1 行目が数値なら speaker ID + 残りが本文")
    func parsesSpeakerIdAndBody() {
        let result = SpeechWatcher.parse("2\nこんにちは")

        #expect(result.speakerId == 2)
        #expect(result.text == "こんにちは")
    }

    @Test("1 行目が数値でなければ全体が本文")
    func parsesBodyOnly() {
        let result = SpeechWatcher.parse("こんにちは\n元気?")

        #expect(result.speakerId == nil)
        #expect(result.text == "こんにちは\n元気?")
    }

    @Test("数値 1 行だけなら本文は空 (読み上げ対象にしない)")
    func speakerIdOnlyHasEmptyBody() {
        let result = SpeechWatcher.parse("2")

        #expect(result.text.isEmpty)
    }

    @Test("前後の空白・改行はトリムする")
    func trimsWhitespace() {
        let result = SpeechWatcher.parse("2\n  こんにちは  \n\n")

        #expect(result.text == "こんにちは")
    }
}
