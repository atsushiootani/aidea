//
//  LanguageDetectorTests.swift
//  AideaTests
//

import Foundation
import Testing
@testable import Aidea

/// `LanguageDetector.isEnglish(_:)` の判定を検証する (issue #287)。
struct LanguageDetectorTests {

    @Test("英文のみは true")
    func pureEnglishIsTrue() {
        let text = "This is a plain English sentence used to describe how the feature works."
        #expect(LanguageDetector.isEnglish(text))
    }

    @Test("日本語のみは false")
    func pureJapaneseIsFalse() {
        let text = "これは日本語の文章です。機能の説明をここに書いています。"
        #expect(!LanguageDetector.isEnglish(text))
    }

    @Test("空文字列は false")
    func emptyStringIsFalse() {
        #expect(!LanguageDetector.isEnglish(""))
    }

    @Test("英語の説明文にコードブロックが混じっていても true (日本語ドキュメントより英語比率が高い代表ケース)")
    func englishProseWithCodeBlockIsTrue() {
        let text = """
        Run the following command to install dependencies:

        ```bash
        npm install
        ```

        This will download all required packages and set up the project.
        """
        #expect(LanguageDetector.isEnglish(text))
    }

    @Test("日本語主体の日英混在 (英単語が少し混じる) は false (判定不能ケース)")
    func mixedJapaneseDominantIsFalse() {
        let text = "これは日本語のドキュメントです。ただし console.log や npm install のような英単語も少し混じります。"
        #expect(!LanguageDetector.isEnglish(text))
    }

    @Test("記号・数字だけの文字列は false (判定不能ケース)")
    func symbolsAndNumbersOnlyIsFalse() {
        #expect(!LanguageDetector.isEnglish("1234567890 ----- === +++ !!!"))
    }
}
