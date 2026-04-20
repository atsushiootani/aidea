---
title: "0003: Claude API を直接叩く（Claude Code CLI は別途使う）"
description: メインは Claude Code CLI で、補助的なチャットペインでのみ Claude API を直叩きする両用方針
status: 採用
derived_from: []
syncs_with: []
impacts: []
replaces: []
replaced_by: []
conventions:
  - docs/LAYOUT.md
last_updated: 2026-04-08
---

# 0003: Claude API を直接叩く（Claude Code CLI は別途使う）

**日付**: 2026-04-08

## 背景
Claude と対話する手段は 2 つある：
1. Claude Code CLI をターミナルで動かす
2. API を直接叩いてチャット UI を作る

## 判断
**両方採用**。メインの対話は CLI（ターミナル内）、補助的なクイック質問は API 直叩きチャットペイン。

## 理由
- Claude Code CLI は既に高機能で、エージェント機能・ツール呼び出し・コンテキスト管理が揃っている
- それを自作で再実装するのは無意味
- 一方で「チャット的にサクッと質問」したいケースもある（Git diff の解説を求めるとか）
- そのときに CLI を起動するのは大げさ

## トレードオフ
- チャットペインでは Claude Code のエージェント機能は使えない（ツール呼び出しなど）
- ユーザーが使い分ける必要がある
