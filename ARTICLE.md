# Filestash を Windows の Podman で動かし、SFTPサーバーのファイルをブラウザから操作できるか試した

オープンソースのファイル管理ツール Filestash を Windows の Podman で起動し、SFTPサーバー上のファイルをブラウザから操作しました。25の操作のうち22を確認でき、転送や操作の前後でハッシュ値を比べた14ファイルのうち13が一致しました。PDFの表示、複数ファイルの同時アップロード、共有リンクの作成の3つは確認できていません。

この実験は、クラウドで動くAIエージェントと人のあいだでファイルを受け渡す置き場を作るための下調べです。今回確かめたのは「人がブラウザで触る側」で、エージェントがつなぐ側はまだ試していません。

## わかったこと

1. **ファイルの出し入れは壊れずに通る。** アップロードしてダウンロードしたファイル、ZIPでまとめて取得したファイル、読み取り専用の領域に置いたファイルは、どれもSHA-256（ファイルの中身から計算する指紋のような値）が元と一致しました。一致しなかった1ファイルは、画面で編集して元に戻したMarkdownで、改行コードの違いによる1バイト差でした。
2. **サーバー側の権限がそのまま画面に出る。** SFTPサーバーで書き込みを禁じたフォルダーに新しいファイルを作ろうとすると、Filestashは「アクセスが拒否されました」と表示し、ファイルは作られませんでした。
3. **起動は速いが、画面の表示は鵜呑みにできない。** 依頼から約14分でブラウザに画面が出ました。一方で、保存が済んでいるのに保存中の表示が残る、アップロードが終わっても速度が0.0B/sのまま、といった表示のずれが複数ありました。

対象は、自分のPCの中だけで開けるようにした使い捨ての環境と、小さなテスト用ファイル10個前後です。インターネット越しの利用、大きなファイル、複数人の同時利用、AIエージェントからの接続は確かめていません。

## Filestash とは

Filestash は、SFTP、S3、FTP、WebDAVなどの保存先を、Dropboxのようなブラウザ画面で扱えるようにするセルフホスト型（自分のサーバーに自分で置く形）のファイル管理ツールです。ファイルそのものは元の保存先に置いたまま、Filestashは画面と橋渡しだけを担当します。

| 項目 | 内容 |
| --- | --- |
| 種別 | セルフホスト型のWebファイル管理ツール |
| ライセンス | AGPL-3.0 |
| つなげる保存先 | SFTP、FTP、S3、SMB、WebDAV、IPFSほか約20種 |
| 配布形式 | 単体のバイナリと、Dockerイメージ（machines/filestash） |
| 初回設定 | 画面を開いて管理者パスワードを決める |
| 外部への出し口 | SFTP、WebDAV、S3、MCP、AS2の「ゲートウェイ」 |
| 本番で必要なもの | HTTPSを受け持つリバースプロキシ（無償版の場合） |

出典は [Filestash のGitHubリポジトリ](https://github.com/mickael-kerjean/filestash)、[公式のインストール手順](https://www.filestash.app/docs/install-and-upgrade/)、[ストレージゲートウェイの説明](https://www.filestash.app/docs/guide/storage-gateway.html)です（2026年10月10日に確認）。

表の最後から2行目にある MCP は、AIアシスタントに外部の道具を使わせるための共通規格です。公式の [MCPゲートウェイの説明](https://www.filestash.app/docs/guide/mcp-gateway.html)によると、Filestashにつないだ保存先の操作を、AIクライアントから呼べる道具として公開できます。接続先の例として Claude Code、ChatGPT、Mistral Le Chat が挙がっています。この機能が無償版に含まれるかどうかは、公式ページの記載からは確認できませんでした。

## 何を試したのか

登場するのは3つです。

| 登場するもの | 役割 | たとえると |
| --- | --- | --- |
| Filestash | ブラウザに画面を出し、操作を保存先へ伝える | 倉庫の受付窓口 |
| SFTPサーバー（atmoz/sftp） | ファイルを実際に保管する | 倉庫そのもの |
| Podman | 上の2つをWindowsの中で動かす | 窓口と倉庫を建てる土地 |

SFTPは、サーバーとの間でファイルを暗号化してやり取りする昔からある方式です。Podmanは、アプリを「コンテナ」という箱に入れて動かす道具で、Dockerと同じイメージを使えます。

倉庫（SFTPサーバー）は実験用の使い捨てで、中身はテスト用に作ったファイルだけです。窓口（Filestash）は自分のPCの中（127.0.0.1）からしか開けないようにし、SFTPのポートはPCの外にも中にも公開していません。

## 実験のやり方

1. Podmanの中に専用のネットワークを作り、SFTPサーバーとFilestashを起動する。
2. SFTPサーバーに、日本語の名前を付けたテスト用ファイルを置く。テキスト、Markdown、PNG、2ページのPDF、3秒の音声と動画、それに書き込みを禁じたフォルダーを用意した。
3. ブラウザでFilestashを開き、SFTPサーバーへログインして、25の操作を1つずつ行う。
4. 操作のたびに画面を撮り、必要なものはサーバー上のファイルを直接読んで、画面の表示と実際の状態が合っているかを確かめる。

ブラウザの操作はAIエージェントが自動で行いました。画面の記録（36枚）とサーバー上のファイルは、操作した担当とは別の担当が開いて確認しています。

結果の判定は3段階です。

| 判定 | 意味 |
| --- | --- |
| 確認できた | 画面と、必要な場合はサーバー上の実体の両方で確かめた |
| 確認できたが注記あり | 操作は成立したが、表示のずれや確認範囲の限界がある |
| 確認できなかった | 操作が最後まで通らなかった、または結果を見られなかった |

## 結果

Filestashは、SFTPサーバー上のファイルに対する25の操作のうち22を通しました。

![25の操作のうち22を確認。確認できなかったのは3つ](https://raw.githubusercontent.com/Sunwood-ai-labs/filestash-podman-sftp/main/assets/chart-operations.png)

| 分類 | 操作の数 | 確認できた | うち注記あり |
| --- | ---: | ---: | ---: |
| 接続と表示 | 5 | 5 | 0 |
| プレビュー | 6 | 5 | 3 |
| ファイル操作 | 9 | 8 | 4 |
| フォルダーと権限 | 5 | 4 | 1 |
| 合計 | 25 | 22 | 8 |

良かった点は次のとおりです。

- 日本語のフォルダー名とファイル名は、一覧、パンくず、検索、名前の変更のどこでも欠けや文字化けがありませんでした。
- テキストとMarkdownは、ダウンロードせずに画面の中で開いて編集し、保存できました。
- 複数のファイルを選ぶと、ZIPにまとめてダウンロードできました。
- 書き込みを禁じたフォルダーでは、新しいファイルを作ろうとした時点で拒否の通知が出ました。

確認できなかった3つは、PDFの表示（本文の領域が空白のまま）、複数ファイルの同時アップロード（ファイルを選ぶ画面が開かなかった）、共有リンクの作成（設定の途中でダイアログが閉じた）です。

### 画面で見る

実験で撮った36枚のうち14枚を載せます。どれもFilestash v0.6.20261009の画面で、写っているのはテスト用に作ったファイルだけです。

**テスト用ファイルを置いたフォルダーの一覧**

![テスト用ファイルを置いたフォルダーの一覧](https://raw.githubusercontent.com/Sunwood-ai-labs/filestash-podman-sftp/main/assets/screenshots/11-extended-listing.png)

日本語の名前がそのまま並び、画像はサムネイルで表示されます。左には開いているフォルダーの階層が出ます。

**リスト表示**

![リスト表示](https://raw.githubusercontent.com/Sunwood-ai-labs/filestash-podman-sftp/main/assets/screenshots/02-list.png)

同じフォルダーをリスト表示に切り替えた画面です。サイズと更新日が並びます。

**日本語での名前検索**

![日本語での名前検索](https://raw.githubusercontent.com/Sunwood-ai-labs/filestash-podman-sftp/main/assets/screenshots/04-search-jp.png)

検索欄に「説明」と入れると、開いているフォルダーの中で名前が一致する1件に絞り込まれました。

**画像のプレビュー**

![画像のプレビュー](https://raw.githubusercontent.com/Sunwood-ai-labs/filestash-podman-sftp/main/assets/screenshots/05-image-preview.png)

PNGは画面の中でそのまま開けました。右上のアイコンから全画面表示とダウンロードができます。

**Markdownの表示**

![Markdownの表示](https://raw.githubusercontent.com/Sunwood-ai-labs/filestash-podman-sftp/main/assets/screenshots/19-markdown-view.png)

Markdownは色分けされたソースとして表示されます。見出しや表が整形された表示にはなりません。

**Markdownを編集して保存した直後**

![Markdownを編集して保存した直後](https://raw.githubusercontent.com/Sunwood-ai-labs/filestash-podman-sftp/main/assets/screenshots/31-markdown-saved.png)

最終行に1行を追記して保存した直後の画面です。タイトルには未保存を示す「*」が残っていますが、サーバー上のファイルには追記が保存されていました。

**アップロードの完了通知**

![アップロードの完了通知](https://raw.githubusercontent.com/Sunwood-ai-labs/filestash-podman-sftp/main/assets/screenshots/06-upload.png)

右下の通知は「完了しました」と表示しつつ、速度は0.0B/sのままでした。ファイルは一覧に現れ、ダウンロードした中身も元と一致しています。

**複数選択**

![複数選択](https://raw.githubusercontent.com/Sunwood-ai-labs/filestash-podman-sftp/main/assets/screenshots/15-multi-select.png)

2つのファイルを選ぶと、上に「ダウンロード」と「削除」が出ます。ダウンロードを選ぶとZIPにまとまります。

**音声の再生**

![音声の再生](https://raw.githubusercontent.com/Sunwood-ai-labs/filestash-podman-sftp/main/assets/screenshots/22-audio-playing.png)

WAVは波形つきのプレーヤーで開き、再生位置が進みました。

**動画の再生**

![動画の再生](https://raw.githubusercontent.com/Sunwood-ai-labs/filestash-podman-sftp/main/assets/screenshots/24-video-playing.png)

MP4も画面の中で再生できました。3秒の動画の1秒付近です。

**読み取り専用フォルダーでの拒否**

![読み取り専用フォルダーでの拒否](https://raw.githubusercontent.com/Sunwood-ai-labs/filestash-podman-sftp/main/assets/screenshots/26-readonly-denied.png)

書き込みを禁じたフォルダーで新しいファイルを作ろうとすると、左下に「アクセスが拒否されました」と出ました。

**PDFを開いた画面（表示を確認できず）**

![PDFを開いた画面（表示を確認できず）](https://raw.githubusercontent.com/Sunwood-ai-labs/filestash-podman-sftp/main/assets/screenshots/20-pdf-page1.png)

2ページのPDFを開いても、本文の領域は空白のままでした。

**共有リンクの作成ダイアログ（作成には至らず）**

![共有リンクの作成ダイアログ（作成には至らず）](https://raw.githubusercontent.com/Sunwood-ai-labs/filestash-podman-sftp/main/assets/screenshots/27-share-options.png)

「閲覧」と「編集」を選ぶところまでは表示されました。この先の設定でダイアログが閉じ、リンクは作れていません。

**すべての操作を終えた後の一覧**

![すべての操作を終えた後の一覧](https://raw.githubusercontent.com/Sunwood-ai-labs/filestash-podman-sftp/main/assets/screenshots/36-final-listing.png)

検証用に作ったフォルダーとファイルを片付けた後の状態です。

### ファイルの中身は変わらなかったか

人とエージェントのあいだでファイルを受け渡すなら、途中で中身が変わらないことが前提になります。そこで、転送や操作の前後でSHA-256を比べました。

![照合した14ファイルのうち13がSHA-256で一致。不一致の1つは改行コードの差](https://raw.githubusercontent.com/Sunwood-ai-labs/filestash-podman-sftp/main/assets/chart-integrity.png)

| 照合したもの | 一致 | 対象 |
| --- | ---: | ---: |
| テスト用ファイルの配置（手元とサーバー） | 8 | 8 |
| 画面からアップロードしてダウンロード | 1 | 1 |
| ZIPでの一括ダウンロード | 2 | 2 |
| 読み取り専用の2ファイル（全操作の後） | 2 | 2 |
| Markdownを編集して元に戻す | 0 | 1 |

一致しなかった1件は、画面でMarkdownに1行追記して保存し、その行を消して保存し直したファイルです。元は873バイト、戻した後は872バイトでした。改行コード（行の終わりを表す記号。WindowsのCRLFとそれ以外のLFがある）をそろえて比べると本文は一致します。画面のエディターを通すと改行コードが変わることがある、という結果です。

### 使えるようになるまでの時間

![依頼から14分で画面が開き、42分で基本の7項目を終えた](https://raw.githubusercontent.com/Sunwood-ai-labs/filestash-podman-sftp/main/assets/chart-timeline.png)

| 段階 | 時刻 | かかった時間 |
| --- | --- | ---: |
| 準備とイメージ取得 | 08:56:38 → 09:09:53 | 13分15秒 |
| Podman machineの復旧と起動 | 09:09:53 → 09:11:14 | 1分21秒 |
| 初回の管理者設定とSFTP接続 | 09:11:14 → 09:24:22 | 13分08秒 |
| ブラウザでのファイル操作 | 09:24:22 → 09:38:48 | 14分26秒 |

この時間には、作業を担当したAIエージェントの手戻りが含まれます。Filestash自体は、後述の再現用スクリプトで起動し直したとき、コンテナを作ってから数秒でHTTP 200（画面を返せる状態）になりました。

## 原因の切り分け

確認できなかった3つと、表示のずれがあったものについて、どこまで原因を絞れたかをまとめます。

| 疑った要因 | 確かめ方 | 結果 | 判定 |
| --- | --- | --- | --- |
| PDFファイルが壊れている | 生成時のページ数と、手元とサーバーのSHA-256を確認 | 2ページで、ハッシュも一致 | ファイルは正常。画面側の原因は未特定 |
| PDFは別のブラウザなら表示される | 別のブラウザで同じファイルを開く | 未実施 | 未特定 |
| 複数アップロードはFilestashが受け付けない | ファイル選択の操作を1回実行 | 選択画面が開かず30秒でタイムアウト | 自動操作側の問題の可能性があり、未特定 |
| 保存中の表示が残るのは保存の失敗 | サーバー上のファイルを直接読む | 編集した内容が保存されていた | 表示だけの問題 |
| フォルダー名の変更が効いていない | 入力欄の値を画面で確かめてから再実行 | 入力した名前で変更され、再読み込み後も同じ | 操作は成立。1回目の不一致の原因は未特定 |
| ZIPのダウンロードが失敗した | 保存されたZIPを開いて中身を照合 | 2ファイルとも元と一致 | 取得は成功。自動操作側の待機がタイムアウトしただけ |
| 共有リンクは作れない | 設定ダイアログを1回操作 | パスワードと期限の設定段階でダイアログが閉じた | 未特定 |

PDFについては、Filestashの不具合とは断定していません。今回使ったのは自動操作用のアプリ内ブラウザ1種類だけで、ふだん使うブラウザでは試していないためです。

## 舞台裏

起動と操作の途中で起きたことを、時刻順に並べます（日本時間、2026年10月10日）。

| 時刻 | 起きたこと | 対処 |
| --- | --- | --- |
| 09:06 | イメージの情報を一覧にするPowerShellが構文エラー | ループの結果をいったん変数に入れてから表示する形に修正 |
| 09:09 | Podmanへの接続が拒否される（終了コード125） | 対象のPodman machineが停止していたため起動。停止の原因は未特定 |
| 09:11 | Filestashの初回設定画面が開く | 管理者パスワードを設定する段階へ進む |
| 09:18 | 管理者設定を送信するとHTTP 200が返るが、画面は設定ページのまま | 完了と扱わず、別のブラウザ操作でログインし直して設定を確認。画面が切り替わらなかった原因は未特定 |
| 09:23 | 見えていない入力欄と、すでに消えた入力欄への自動入力が各30秒でタイムアウト | 現在の画面を取り直してから操作するように変更 |
| 09:27 | ファイルをダブルクリックすると、ファイル名が2回重なったURLになり404 | 1回クリックで開き、表示を確かめてから次へ進む |
| 11:50 | ZIPのダウンロードを待つ自動操作が30秒でタイムアウト | 再実行せず、保存されたZIPの中身を照合 |
| 12:08 | SFTPコンテナ内の find が -printf に対応していない（BusyBox版） | find と stat の組み合わせに切り替え |

手作業で試す場合に関係するのは、Podman machineの停止と、ダブルクリックで404になる点の2つです。残りは自動操作に固有の問題でした。

## クラウドのエージェントとのデータ共有に使えるか

今回の実験が目指している使い方は、人はブラウザで、AIエージェントは別の入口から、同じ保存先を読み書きする形です。その観点で結果を整理します。

| 必要なこと | 今回の結果 | 状態 |
| --- | --- | --- |
| 人がブラウザで中身を見て直せる | テキスト、Markdown、画像、音声、動画を画面で開けた | 確認済み |
| 受け渡しでファイルが壊れない | 14ファイル中13が一致、残り1つは改行コードの差 | 確認済み |
| エージェントに触らせない場所を作れる | サーバー側で書き込みを禁じたフォルダーは画面からも書けなかった | 確認済み |
| エージェントが同じ保存先につなげる | SFTPサーバーへ直接つなぐ経路も、MCPゲートウェイも未実施 | 未確認 |
| 自分のPCの外から開ける | 127.0.0.1に限定して起動したため対象外 | 未確認 |
| 期限つきのリンクで一時的に渡せる | 共有リンクの作成に至らなかった | 未確認 |

人が触る側の土台は確かめられました。エージェントがつなぐ側と、外から届く経路はこれからです。エージェントの入口には、SFTPサーバーへ直接つなぐ方法と、FilestashのMCPゲートウェイを通す方法の2つが考えられます。公式のMCPゲートウェイの説明は、AIが触れる範囲を chroot（見える場所を特定のフォルダーに閉じ込める設定）と権限の設定で絞ることを勧めています。

編集したテキストの改行コードが変わる点は、エージェント側でハッシュ値を使って「変更があったか」を判定する仕組みを組むときに影響します。人が画面で開いて保存しただけで、内容が同じでも別のファイルとして検知される可能性があります。

## 評価と次に試すこと

| 観点 | 良い点 | 課題 |
| --- | --- | --- |
| 導入 | イメージ2つとコマンド数本で起動し、数秒で画面が出る | 初回の管理者設定とSFTPの接続設定は画面での手作業 |
| 日本語 | 名前の表示、検索、変更で問題なし | なし |
| 転送の正確さ | 1件ずつの転送とZIPはハッシュ一致 | 画面での編集は改行コードが変わることがある |
| 表示の信頼性 | 権限エラーはその場で通知される | 保存中の表示や速度表示が実態とずれる |
| プレビュー | 画像、音声、動画は画面内で再生できた | PDFは表示を確認できず、Markdownは整形されない |

この実験から言えないことも挙げておきます。

- 大きなファイル（今回の最大は約265KB）や、数千件のファイルがあるフォルダーでの動作。
- 複数人が同時に同じファイルを触ったときの挙動。
- インターネット越しに公開したときの安全性。HTTPSもリバースプロキシも設定していません。
- 音声が実際に聞こえるかどうか。確かめたのは再生位置が進むことまでです。
- Office文書のプレビュー。公式の構成に含まれるCollaboraは今回外しています。

次に試すこと。

- [ ] 同じSFTPサーバーへ、エージェント側から直接つないでファイルを置き、Filestashの画面に出ることを確かめる
- [ ] FilestashのMCPゲートウェイを有効にし、AIクライアントから一覧と読み書きができるかを確かめる
- [ ] 読み取り専用と書き込み可のフォルダーを分け、エージェント用のアカウントで権限が効くことを確かめる
- [ ] PDFをふだん使うブラウザで開き、表示されるかを切り分ける
- [ ] 共有リンクを手作業で作り、期限とパスワードが効くことを確かめる
- [ ] 外から届く経路（HTTPSのリバースプロキシやVPN）を足して同じ操作を繰り返す

## 動かし方

同じ構成を自分のPCで起動できます。コードは [filestash-podman-sftp](https://github.com/Sunwood-ai-labs/filestash-podman-sftp) にあります。

用意するもの。

| 必要なもの | 今回使った版 | 補足 |
| --- | --- | --- |
| Windows と PowerShell | Windows 11、PowerShell 7 | スクリプトの確認はPowerShell 7で実施 |
| Podman | CLI 5.8.3、machine 5.8.8 | machineが起動していること |
| 空きポート | 18334 | 引数で変更できる |

### 1. 起動する

```powershell
git clone https://github.com/Sunwood-ai-labs/filestash-podman-sftp.git
cd filestash-podman-sftp\quickstart
.\start.ps1
```

`start.ps1` は、専用のネットワークとボリュームを作り、SFTPサーバーとFilestashを起動して、`http://127.0.0.1:18334` がHTTP 200を返すまで待ちます。イメージは実験で使ったものと同じdigest（内容を一意に示す値）に固定しています。核になるのは次の2つのコマンドです。

```powershell
# SFTPサーバー。ポートはホストへ公開しない
podman run -d --name filestash-demo-sftp --network filestash-demo-net `
  --network-alias filestash-demo-sftp -v filestash-demo-sftp-data:/home/qa/share `
  docker.io/atmoz/sftp@sha256:7e439fab... "qa:<パスワード>:1001:100:share"

# Filestash。このPCの中からだけ開ける
podman run -d --name filestash-demo --network filestash-demo-net `
  -p 127.0.0.1:18334:8334/tcp -v filestash-demo-app-data:/app/data/state/ `
  docker.io/machines/filestash@sha256:db21af2b...
```

パスワードは初回に乱数で作られ、`quickstart\private\connections.json` に保存されます。全文は [quickstart/start.ps1](https://github.com/Sunwood-ai-labs/filestash-podman-sftp/blob/main/quickstart/start.ps1) にあります。

自分のフォルダーを共有領域に入れたい場合は、`.\start.ps1 -SeedDirectory C:\work\share-me` のように指定します。

### 2. 初回設定をする

ブラウザで `http://127.0.0.1:18334` を開き、次の順に進めます。

1. 管理者パスワードを設定する（`connections.json` の `filestashAdminPassword`）。
2. 管理画面のストレージ設定でSFTPを選ぶ。
3. ログイン画面で、ホスト名 `filestash-demo-sftp`、ポート `22`、ユーザー名 `qa`、`sftpPassword` の値を入力する。

ログインすると `share` フォルダーが見えます。ファイルを開くときは1回クリックです。

### 3. ファイルが変わっていないか確かめる

```powershell
.\compare-hashes.ps1 -LocalDirectory .\seed
```

手元のフォルダーと、SFTPサーバー上の同じ場所にあるファイルをSHA-256で比べます。

```powershell
$local  = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
$output = @(& podman @Base exec $Container sha256sum "$RemoteDirectory/$relative" 2>$null)
$remote = ([string]$output[0]).TrimStart('\').Split(' ')[0].ToLowerInvariant()
```

全文は [quickstart/compare-hashes.ps1](https://github.com/Sunwood-ai-labs/filestash-podman-sftp/blob/main/quickstart/compare-hashes.ps1) にあります。

出力の読み方。

| Result の値 | 意味 |
| --- | --- |
| match | 手元とサーバーで中身が同じ |
| DIFFERENT | 中身が違う。画面で編集したテキストは改行コードの差でこうなることがある |
| missing | サーバー側にファイルがない |

このスクリプトを実験のSFTPサーバーにかけると、8ファイル中7ファイルが一致し、編集して戻したMarkdownだけが DIFFERENT になりました。記事の数字と同じ結果です。

### 4. 止める、消す

```powershell
.\stop.ps1              # コンテナを止める。データは残る
.\cleanup.ps1 -WhatIf   # 消す対象を表示するだけ
.\cleanup.ps1           # コンテナ、ネットワーク、ボリュームを消す
```

[quickstart/stop.ps1](https://github.com/Sunwood-ai-labs/filestash-podman-sftp/blob/main/quickstart/stop.ps1) と [quickstart/cleanup.ps1](https://github.com/Sunwood-ai-labs/filestash-podman-sftp/blob/main/quickstart/cleanup.ps1) は、`start.ps1` が作ったものだけを対象にします。

### 確認できている範囲

`quickstart` の4つのスクリプトは、実験と同じPodman machineの上で、名前とポートを変えて通しで実行しました（起動、HTTP 200、ハッシュ照合、停止、再起動、削除）。この起動分では、手順2の初回設定とSFTPログインをブラウザで行っていません。初回設定とログインを確かめたのは、同じイメージと同じ引数で起動した実験本体の環境です。

リポジトリの中身。

| フォルダー | 内容 |
| --- | --- |
| quickstart | 自分のPCで起動するためのスクリプト一式 |
| experiment | 実験で実際に動かしたスクリプトと、テスト用ファイルの元 |
| results | 操作ごとの結果、ハッシュ照合、時刻の記録 |
| docs | 実験時の結果表と、画面記録の確認メモ |
| assets | グラフ、ヘッダー画像、それらの生成スクリプト、実験時の画面 |

画面の記録（スクリーンショット）は36枚のうち14枚を `assets/screenshots` に入れています。残りの22枚と実行ログは含めていません。

## 実行条件と指標の定義

| 項目 | 値 |
| --- | --- |
| 実施日 | 2026年10月10日 |
| OS | Windows 11 |
| Podman | CLI 5.8.3、machine（WSL）とAPIは 5.8.8 |
| Filestash | 画面表示の版 v0.6.20261009、イメージ作成日 2026-10-09 |
| SFTPサーバー | atmoz/sftp の alpine 版、イメージ作成日 2026-10-07 |
| 公開範囲 | Filestashは 127.0.0.1:18334 のみ。SFTPのポートは非公開 |
| ブラウザ | 自動操作用のアプリ内ブラウザ（Codex）とPlaywright |
| SFTPのユーザー | qa（UID 1001、GID 100） |
| 読み取り専用の領域 | root所有、フォルダー0755、ファイル0444 |

イメージのdigestは次のとおりです。Filestashのイメージには版を示すラベルがないため、digestで版を特定しています。

- Filestash: `sha256:db21af2bff93ebb81ad9270a8a564679be4aec87406b093c41c30db0fbf27226`
- atmoz/sftp: `sha256:7e439fabeae536fa254340724c042e11999924d906417dbb5c73602ad518813f`

指標の定義と限界。

- **操作の数（25）**は、実験時の2つの結果表（基本の7項目と追加の実験）を、操作1つにつき1行へ書き直して数えたものです。分け方を変えれば総数は変わります。書き直した一覧は [results/operations.json](https://github.com/Sunwood-ai-labs/filestash-podman-sftp/blob/main/results/operations.json) にあります。
- **確認できた**は、各操作を1回から数回試した結果です。繰り返し試して成功率を測ったものではありません。
- **SHA-256の一致（14ファイル）**は、照合を行ったファイルの数です。すべての操作でハッシュを比べたわけではありません。
- **時間**は、実験時のログの時刻から計算しました。AIエージェントの作業時間と手戻りを含みます。

## 参考リンク

- [Filestash（GitHub）](https://github.com/mickael-kerjean/filestash)
- [Filestash のインストール手順](https://www.filestash.app/docs/install-and-upgrade/)
- [Filestash のストレージゲートウェイ](https://www.filestash.app/docs/guide/storage-gateway.html)
- [Filestash のMCPゲートウェイ](https://www.filestash.app/docs/guide/mcp-gateway.html)
- [Filestash の権限設定](https://www.filestash.app/docs/guide/authorization.html)
- [atmoz/sftp（GitHub）](https://github.com/atmoz/sftp)
- [この実験のリポジトリ](https://github.com/Sunwood-ai-labs/filestash-podman-sftp)
