//
//  WebSessionView.swift
//  Aidea
//

import SwiftUI
import AppKit
import WebKit

/// Web Session の SwiftUI View。上部にナビゲーションツールバー
/// (戻る / 進む / 更新 / URL 欄 / 地球アイコン) を持ち、下に WKWebView を表示する。
/// 仕様: docs/specs/tools/web.md#ナビゲーションツールバー
struct WebSessionView: View {
    let state: WebSessionState
    @State private var urlText: String = ""
    @FocusState private var isURLFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            WebViewRepresentable(state: state)
        }
        .onAppear {
            urlText = state.url.absoluteString
        }
        .onChange(of: state.url) { _, newURL in
            // 編集中 (フォーカス中) はユーザ入力を追従更新で上書きしない
            if !isURLFieldFocused {
                urlText = newURL.absoluteString
            }
        }
    }

    /// ナビゲーションツールバー。一般的なブラウザと同じ並び。
    private var toolbar: some View {
        HStack(spacing: 6) {
            toolbarButton("chevron.left", help: "戻る", disabled: !state.canGoBack) {
                state.webView.goBack()
            }
            toolbarButton("chevron.right", help: "進む", disabled: !state.canGoForward) {
                state.webView.goForward()
            }
            toolbarButton("arrow.clockwise", help: "更新") {
                state.webView.reload()
            }

            TextField("URL を入力", text: $urlText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .focused($isURLFieldFocused)
                .onSubmit {
                    state.loadURLString(urlText)
                    isURLFieldFocused = false
                }

            toolbarButton("globe", help: "ブラウザで開く") {
                NSWorkspace.shared.open(state.url)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    /// ツールバーの SF Symbol ボタン 1 つ分
    private func toolbarButton(
        _ systemName: String, help: String, disabled: Bool = false, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .foregroundStyle(disabled ? Color.secondary.opacity(0.4) : Color.primary)
        .help(help)
    }
}
