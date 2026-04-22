//
//  FileTreeViewController+Undo.swift
//  Aidea
//

import AppKit

/// FileTreeViewController のアンドゥ対応操作ヘルパ。
/// rename / move / delete / create / paste 等の各 action 関数から呼ばれ、
/// `FilerSessionState.undoManager` に逆操作を登録する。
/// アンドゥ・リドゥの中でも自分自身を再 register するため、Cmd+Z / Cmd+Shift+Z で連鎖する。
/// 仕様: docs/specs/tools/filer.md#undolastoperation
extension FileTreeViewController {
    /// `FileManager.moveItem` を実行し、UndoManager に逆方向の move を登録する。
    /// rename / DnD 移動で共用。
    @discardableResult
    func performUndoableMove(from oldURL: URL, to newURL: URL, actionName: String) -> Bool {
        do {
            try FileManager.default.moveItem(at: oldURL, to: newURL)
        } catch {
            showFileOperationError(error, action: actionName)
            return false
        }
        owner?.undoManager.registerUndo(withTarget: self) { target in
            _ = target.performUndoableMove(from: newURL, to: oldURL, actionName: actionName)
        }
        owner?.undoManager.setActionName(actionName)
        return true
    }

    /// `FileManager.trashItem` でゴミ箱に送り、UndoManager に「ゴミ箱から元位置へ復元」を登録する。
    /// 削除 / create / paste のアンドゥで共用 (create / paste はファイル自体の作成を取り消すため trash する)。
    @discardableResult
    func performUndoableTrash(at url: URL, actionName: String) -> Bool {
        var resultingTrashURL: NSURL?
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: &resultingTrashURL)
        } catch {
            showFileOperationError(error, action: actionName)
            return false
        }
        let trashURL = resultingTrashURL as URL?
        owner?.undoManager.registerUndo(withTarget: self) { target in
            guard let trashURL = trashURL else { return }
            _ = target.performUndoableRestoreFromTrash(from: trashURL, to: url, actionName: actionName)
        }
        owner?.undoManager.setActionName(actionName)
        return true
    }

    /// ゴミ箱内の URL を `FileManager.moveItem` で元位置に戻し、
    /// UndoManager に「再びゴミ箱送り」を登録する (redo 連鎖)。
    @discardableResult
    func performUndoableRestoreFromTrash(from trashURL: URL, to originalURL: URL, actionName: String) -> Bool {
        do {
            try FileManager.default.moveItem(at: trashURL, to: originalURL)
        } catch {
            showFileOperationError(error, action: actionName)
            return false
        }
        owner?.undoManager.registerUndo(withTarget: self) { target in
            _ = target.performUndoableTrash(at: originalURL, actionName: actionName)
        }
        owner?.undoManager.setActionName(actionName)
        return true
    }

    /// ファイル操作エラー時の共通アラート表示。
    /// 履歴は失効させず、当該 1 件のみ失敗扱いとして他のグループ要素は処理を続行する。
    func showFileOperationError(_ error: Error, action: String) {
        let alert = NSAlert()
        alert.messageText = "\(action) に失敗しました"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}
