# Filestash SFTP UI 実操作結果

実施日: 2026-10-10  
確認環境: ローカル Filestash (`127.0.0.1:18334`)、Codex In-app Browser。対象は `extended/fixtures/追加実験/` のテストデータ。

## 確認できた操作

| 項目 | 結果 | 証拠 |
| --- | --- | --- |
| 一覧・検索・プレビュー | グリッド/リスト切替、名前順、`日本語`検索、PNGプレビュー、TXT表示を確認。 | `ui/01-grid.png`–`ui/05-image-preview.png`, `ui/09-jp-file-preview.png` |
| 単一ファイル操作 | テストファイルのアップロード、ダウンロード、名前変更、削除を確認。ダウンロードのSHA-256はfixtureと一致。アップロード完了後も画面の速度表示は `0.0B/s` のままだった。 | `ui/06-upload.png`–`ui/10-delete-jp.png` |
| 一覧・フォルダー | 追加fixture一覧、フォルダー作成と削除を確認。別の管理されたrenameでは、入力欄に `qa-rename-final` が表示された状態を保存し、再読み込み後も同名で存在することを確認。検証用フォルダーは削除済み。初回の日本語フォルダー試行で表示された元名の原因は特定できていないため、その試行は評価対象から除外。 | `ui/11-extended-listing.png`, `ui/12-folder-create.png`, `ui/13-folder-rename.png`, `ui/14-folder-delete.png`, `ui/34-folder-rename-input.png`, `ui/35-folder-rename-result.png`, `ui/36-final-listing.png` |
| 複数選択・ZIP | 2ファイルを選択できた。操作欄に「ダウンロード」「削除」は表示されたが、コピー/移動は見当たらなかった。UIから取得したZIPは847 bytesで、README.md (873 bytes, CRC32 `05CEEACE`) と確認メモ.txt (119 bytes, CRC32 `483D39CD`) を収録。両エントリのSHA-256と内容はfixtureに一致。 | `ui/15-multi-select.png`, `ui/16-multi-download.png` |
| 音声・動画 | WAVの再生位置が約1秒へ進むこと、MP4の長さが約3.02秒で再生位置が約1.07秒へ進むことを確認。 | `ui/21-audio-player.png`, `ui/22-audio-playing.png`, `ui/23-video-player.png`, `ui/24-video-playing.png` |
| 読み取り専用領域 | 新規ファイル作成を再試行し、「アクセスが拒否されました」の通知を表示中に保存。一覧は既存の2ファイルのままで、QAファイルは作成されていない。 | `ui/25-readonly-listing.png`, `ui/26-readonly-denied.png` |

## 未確認・制約

- **複数ファイルアップロード:** ファイル選択イベントがタイムアウトし、3ファイルのアップロードは確認できなかった。作業用フォルダーは空のまま確認し、削除済み。`ui/17-upload-folder-create.png`, `ui/18-upload-folder-open.png`, `ui/28-multi-upload.png`, `ui/29-temp-folder-cleanup.png`
- **Markdown編集の復元:** 一時コメントが保存・読戻しされ、その後取り除かれた。復元後の本文はCRLFをLFへ正規化するとfixtureと一致したが、サーバー側は872 bytes、fixtureは873 bytesで、SHA-256も異なる。バイト単位の完全復元とは扱わない。保存中表示が残った後も読戻し結果は確認できた。`ui/19-markdown-view.png`, `ui/30-markdown-edit.png`–`ui/33-markdown-restored.png`
- **PDF表示:** 同じIABで2ページPDFを開くと本文領域が空白のままで、ページ表示を確認できなかった。アプリ不具合とは断定しない。`ui/20-pdf-page1.png`
- **共有リンク:** 共有設定と「閲覧」の詳細画面は表示されたが、パスワード/期限を設定する段階でダイアログが閉じ、リンク作成・未ログイン閲覧・失効を完了できなかった。共有URLや一時パスワードは記録していない。`ui/27-share-options.png`

検証用フォルダーと空の一括アップロード用フォルダーは削除済み。最後は `/share/追加実験/` の一覧に戻り、スクリーンショット `ui/36-final-listing.png` で確認した。
