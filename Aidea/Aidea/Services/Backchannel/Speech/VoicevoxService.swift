//
//  VoicevoxService.swift
//  Aidea
//

import Foundation

/// VOICEVOX REST API クライアント。audio_query → synthesis の2ステップで音声を合成する。
enum VoicevoxService {
    private static let baseURL = "http://localhost:50021"
    private static let defaultSpeaker = 20 // もち子さん

    /// テキストから WAV 音声データを生成する
    static func synthesize(_ text: String, speaker: Int = defaultSpeaker) async throws -> Data {
        let query = try await audioQuery(text: text, speaker: speaker)
        return try await synthesis(query: query, speaker: speaker)
    }

    /// VOICEVOX が起動しているか確認する
    static func isAvailable() async -> Bool {
        guard let url = URL(string: "\(baseURL)/version") else { return false }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    /// テキストから音声合成用のクエリパラメータを取得する
    private static func audioQuery(text: String, speaker: Int) async throws -> Data {
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/audio_query?speaker=\(speaker)&text=\(encoded)") else {
            throw VoicevoxError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw VoicevoxError.apiError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return data
    }

    /// audio_query の結果から WAV 音声データを合成する
    private static func synthesis(query: Data, speaker: Int) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/synthesis?speaker=\(speaker)") else {
            throw VoicevoxError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = query
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw VoicevoxError.apiError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return data
    }
}

enum VoicevoxError: LocalizedError {
    case invalidURL
    case apiError(statusCode: Int)
    case notRunning

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "VOICEVOX: 無効な URL"
        case .apiError(let code): return "VOICEVOX API エラー (status: \(code))"
        case .notRunning: return "VOICEVOX が起動していません"
        }
    }
}
