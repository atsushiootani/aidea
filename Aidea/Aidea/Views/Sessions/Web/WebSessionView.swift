//
//  WebSessionView.swift
//  Aidea
//

import SwiftUI
import AppKit
import WebKit

/// Web Session の SwiftUI View。上部にナビゲーションツールバー
/// (戻る / 進む / 更新 / URL 欄 / 地球アイコン / 検索アイコン) を持ち、下に WKWebView を表示する。
/// 検索アイコンを押すとツールバー下にページ内検索バーが開く。
/// 仕様: docs/specs/tools/web.md#ナビゲーションツールバー
struct WebSessionView: View {
    let state: WebSessionState
    @State private var urlText: String = ""
    @State private var isSearchVisible: Bool = false
    @State private var searchText: String = ""
    /// 直近の検索でヒットがあったか (なければ「見つかりません」を表示)
    @State private var matchFound: Bool = true
    @FocusState private var isURLFieldFocused: Bool
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if isSearchVisible {
                Divider()
                searchBar
            }
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
            toolbarButton("magnifyingglass", help: "ページ内検索", active: isSearchVisible) {
                if isSearchVisible { closeSearch() } else { openSearch() }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    /// ページ内検索バー。検索アイコン押下でツールバー下に開く。
    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            TextField("ページ内を検索", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isSearchFieldFocused)
                .onChange(of: searchText) { _, _ in
                    performSearch(forward: true)
                }
                .onSubmit {
                    performSearch(forward: true)
                }
                .onKeyPress(.escape) {
                    closeSearch()
                    return .handled
                }

            if !searchText.isEmpty && !matchFound {
                Text("見つかりません")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            toolbarButton("chevron.up", help: "前を検索", disabled: searchText.isEmpty) {
                performSearch(forward: false)
            }
            toolbarButton("chevron.down", help: "次を検索", disabled: searchText.isEmpty) {
                performSearch(forward: true)
            }
            toolbarButton("xmark", help: "閉じる") {
                closeSearch()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    /// ツールバーの SF Symbol ボタン 1 つ分
    private func toolbarButton(
        _ systemName: String, help: String, disabled: Bool = false, active: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .foregroundStyle(
            disabled ? Color.secondary.opacity(0.4) : (active ? Color.accentColor : Color.primary)
        )
        .help(help)
    }

    /// 検索バーを開いて検索フィールドにフォーカスする
    private func openSearch() {
        isSearchVisible = true
        DispatchQueue.main.async { isSearchFieldFocused = true }
    }

    /// 検索バーを閉じて状態をリセットする
    private func closeSearch() {
        isSearchVisible = false
        searchText = ""
        matchFound = true
        isSearchFieldFocused = false
    }

    /// 現在の検索語でページ内検索を実行する
    private func performSearch(forward: Bool) {
        state.find(searchText, forward: forward) { found in
            matchFound = found
        }
    }
}
