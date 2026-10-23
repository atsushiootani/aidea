//
//  ShellCommandSanitizer.swift
//  Aidea
//

import Foundation

/// PTY へキー入力として送るコマンド文字列から、表示されない制御文字を取り除く。
/// Markdown Preview のシェルコードブロックは外部由来のファイルでも表示されるため、
/// 見た目と実際に送られる入力がずれないよう、表示前と送信前の両方でこれを通す (issue #296)。
enum ShellCommandSanitizer {

    /// C0 制御文字 (U+0000〜U+001F)・DEL (U+007F)・C1 制御文字 (U+0080〜U+009F) を除去する。
    /// 改行 (U+000A) とタブ (U+0009) だけは残す。CR (U+000D) も除去するので CRLF は LF になる。
    static func sanitize(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars where !isStripped(scalar) {
            scalars.append(scalar)
        }
        return String(scalars)
    }

    /// 除去対象の制御文字かどうか
    static func isStripped(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x09, 0x0A:
            return false
        case 0x00...0x1F, 0x7F, 0x80...0x9F:
            return true
        default:
            return false
        }
    }
}
