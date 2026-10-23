//
//  JavaScriptStringLiteral.swift
//  Aidea
//

import Foundation

/// 信頼できない文字列を、HTML のインライン `<script>` に埋め込める JS 文字列リテラルへ変換する。
///
/// JSON 文字列としてエスケープしたうえで、HTML パーサが解釈しうる `<` `>` `&` と、
/// 古い JS で改行扱いになる U+2028 / U+2029 を `\uXXXX` に置き換える。
/// これにより `</script>` や `<!--` を含む入力でも script 要素を閉じられない。
enum JavaScriptStringLiteral {
    /// ダブルクォート付きの JS 文字列リテラルを返す (例: `"a<b"`)
    static func make(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]),
              let json = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return json
            .replacingOccurrences(of: "<", with: "\\u003c")
            .replacingOccurrences(of: ">", with: "\\u003e")
            .replacingOccurrences(of: "&", with: "\\u0026")
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }
}
