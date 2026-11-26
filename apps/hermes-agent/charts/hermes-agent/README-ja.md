<!-- translation_source: charts/hermes-agent/README.md @ 7ed24f70b11e37d9b2317d6a9fd863c96c2cf4d9 -->

<div align="center" markdown="1">

# hermes-agent-helm/hermes-agent

<img height="240" src="https://raw.githubusercontent.com/jyje/hermes-agent-helm/main/docs/images/hermes-agent-helm.png" alt="Kubernetes × Hermes Agent"/>

</div>

👩🏻‍💻 Kubernetes 上の Hermes Agent - Codex/Copilot でログインし、エージェントチームを軽量に運用できます。

複数の LLM プロバイダーに対応するエージェントフレームワーク [Hermes Agent](https://github.com/NousResearch/hermes-agent) を Kubernetes 上で実行します。OpenAI、Anthropic、Gemini、OpenRouter、NVIDIA、LiteLLM/vLLM などの OpenAI 互換プロキシを含む、Hermes が対応するプロバイダーを `values.yaml` で設定できます。`helm test` によるヘルスチェックも付属しています。

[![GitHub](https://img.shields.io/badge/GitHub-jyje%2Fhermes--agent--helm-181717?logo=github)](https://github.com/jyje/hermes-agent-helm) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/jyje/hermes-agent-helm/blob/main/LICENSE) ![Version: 1.28.0](https://img.shields.io/badge/Version-1.28.0-informational?style=flat) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat) ![AppVersion: v0.22.2](https://img.shields.io/badge/AppVersion-v0.22.2-informational?style=flat)

[English](README.md) · [한국어](README-ko.md) · [日本語](README-ja.md) · [简体中文](README-zh.md)

**[このプロジェクト](https://github.com/jyje/hermes-agent-helm)が役に立ったら [GitHub で ⭐](https://github.com/jyje/hermes-agent-helm) をお願いします。ほかの方がこのプロジェクトを見つける助けになります。**

> 日本語版は入門ページを翻訳しています。未翻訳のセクションは英語で表示されます。翻訳の修正提案を歓迎します。生成済みの `## Values` 表は英語のまま掲載しています。
> メンテナーは日本語の母語話者ではなく、この翻訳は日本語の母語話者によるレビューを受けていません。不明確な表現は英語の原文を基準に確認してください。

## TL;DR

```bash
# OCI (recommended)
helm upgrade --install hermes-agent \
  oci://ghcr.io/jyje/hermes-agent-helm/hermes-agent --version 1.28.0 \
  --namespace hermes-agent --create-namespace \
  --set-string env.OPENAI_API_KEY='sk-...' --wait
```

```bash
# Helm Repository
helm repo add hermes-agent https://jyje.github.io/hermes-agent-helm
helm repo update
helm upgrade --install hermes-agent hermes-agent/hermes-agent \
  --namespace hermes-agent --create-namespace \
  --set-string env.OPENAI_API_KEY='sk-...' --wait
```

- **Web ダッシュボード**: ブラウザでエージェントとチャットし、セッションを閲覧し、モデル、スキル、設定を管理します。パスワード、Nous Portal OAuth、または独自の OpenID Connect ログインで保護されます。詳細は[ダッシュボード](#ダッシュボードの公開)を参照してください。
- **ArgoCD**: プロバイダーとメッセンジャーの組み合わせごとに、適用可能な `Application` マニフェストを用意しています。[`examples/argocd/`](../../examples/argocd/) を参照してください。
- **実際のシークレットをコミットしない GitOps**: SealedSecret と `extraEnvFrom` の手順は [SealedSecret ガイド](../../examples/argocd/#sealedsecret-walkthrough-nvidia-nim--discord)を参照してください。
- **エージェントチーム**: 共通の Discord チャンネルで `@mention` によって引き継ぐ複数インスタンスを実行できます。[`hermes-collab-pair.yaml`](../../examples/argocd/hermes-collab-pair.yaml)、[チーム](../../docs/advanced/teams/reference.md)、[連携ガイド](../../docs/advanced/teams/collaboration.md)を参照してください。

## プロバイダーの設定

`config.model.provider` に組み込みの識別子を指定し、`env` に API キーを設定します。

| プロバイダー | `config.model.provider` | キーの環境変数 | サンプル |
| --- | --- | --- | --- |
| OpenAI | `openai-api` | `OPENAI_API_KEY` | [`values-openai.yaml`](values-openai.yaml) |
| Anthropic (Claude) | `anthropic` | `ANTHROPIC_API_KEY` | [`values-anthropic.yaml`](values-anthropic.yaml) |
| Google Gemini | `gemini` | `GOOGLE_API_KEY` | [`values-gemini.yaml`](values-gemini.yaml) |
| Google Vertex AI | `vertex` | 不要。マウントしたサービスアカウント JSON（または ADC）から OAuth2 トークンを自動取得 | [`values-google-vertex.yaml`](values-google-vertex.yaml) |
| OpenRouter | `openrouter` | `OPENROUTER_API_KEY` | [`values-openrouter.yaml`](values-openrouter.yaml) |
| NVIDIA NIM | `nvidia` | `NVIDIA_API_KEY` | [`values-nvidia-nim-and-discord.yaml`](values-nvidia-nim-and-discord.yaml) |
| Fireworks AI | `fireworks` | `FIREWORKS_API_KEY` | [`values-fireworks.yaml`](values-fireworks.yaml) |
| DeepInfra | `deepinfra` | `DEEPINFRA_API_KEY` | [`values-deepinfra.yaml`](values-deepinfra.yaml) |
| Upstage Solar | `upstage` | `UPSTAGE_API_KEY` | [`values-upstage.yaml`](values-upstage.yaml) |
| GitHub Copilot | `copilot` | `COPILOT_GITHUB_TOKEN`（OAuth デバイスフロー。API キー不要） | [`values-github-copilot.yaml`](values-github-copilot.yaml) |
| OpenAI Codex | `openai-codex` | ChatGPT/Codex デバイスログイン（API キー不要） | [`values-openai-codex.yaml`](values-openai-codex.yaml) |
| Mixture-of-Agents (MoA) | `moa` | プリセットの参照モデルと集約モデルによる | [`values-moa.yaml`](values-moa.yaml) |
| カスタム（LiteLLM / vLLM / LM Studio） | `config.providers` 配下の独自 ID | プロキシによる | [`values-litellm.yaml`](values-litellm.yaml) |

> 接尾辞のない `openai` は有効なプロバイダー識別子ではありません。OpenRouter の別名として扱われます。**`openai-api` を使用してください。**

プロバイダー別の `--set` の例と Discord/Telegram の設定は、下の[プロバイダーとメッセンジャーの設定](#プロバイダーとメッセンジャーの設定)を参照してください。

## テスト

```bash
helm test hermes-agent -n hermes-agent
kubectl logs -n hermes-agent -l app.kubernetes.io/component=test --tail=-1
```

インストール後に `hermes doctor` 形式のヘルスチェック Job を実行します。プロバイダーとの実際の往復通信も確認する場合は、[詳細なテスト](#詳細なテスト)を参照してください。

## 概要

[Hermes Agent](https://github.com/NousResearch/hermes-agent) を Kubernetes 上で実行します。次のリソースをデプロイします。

- 永続化した `HERMES_HOME` を持つ単一レプリカの **Deployment**（デフォルト）または **StatefulSet**（`controller.type`）。イメージの s6 が監視するゲートウェイを実行します。
- 部分的な `config.yaml` と任意の `SOUL.md` を保持する **ConfigMap**。
- `.env` の値を保持し、`envFrom` で注入する **Secret**。
- `controller.type=statefulset` の場合は DNS と管理用の headless Service。ゲートウェイはアウトバウンドのため受信ポートはありません。`deployment` の場合は独立した PVC を使用します。どちらの構成でも、明示的に選択した dashboard、API サーバー、webhook のポートを公開する **任意の** ClusterIP Service と、**任意の** Ingress または Gateway API HTTPRoute（`ingress.enabled` / `httpRoute.enabled`）を利用できます。
- `hermes doctor` 形式の検査を実行する **Helm テスト** Job（`helm test`）。

エージェントのコマンド実行には **`local` バックエンド**を使用します。コマンドは Pod 内で実行され、Pod 自体がサンドボックスです。`docker` バックエンドは**クラスター内では非対応**です。Docker デーモンやソケットが必要で、containerd クラスター（MicroK8s / Raspberry Pi）には存在せず、マウントにもセキュリティリスクがあります。

> イメージタグは 2026 年 10 月から **semver** です（例: `v0.22.2`）。それ以前のイメージは日付形式のタグ（例: `v2026.9.24`）を使います。amd64 と arm64 のマルチアーキテクチャに対応し、Raspberry Pi クラスターでも動作します。

> **スケーリングについて。** Hermes は単一インスタンスのパーソナルエージェントなので、このチャートは `replicaCount: 1` に固定し、複数レプリカモードを提供しません。[values 表](#values)の注記も参照してください。拡張には `resources` や `persistence.size` を増やします。複数のエージェントが必要な場合は、別々のインスタンスを**チーム**にまとめ、1 つのゲートウェイチャンネルを共有します。[Hermes チーム](../../docs/advanced/teams/reference.md)を参照してください。

## プロバイダーとメッセンジャーの設定

未リリースの変更を試すなど、ローカルのチャートからインストールする場合:

```bash
helm upgrade --install hermes-agent ./charts/hermes-agent \
  --namespace hermes-agent --create-namespace \
  --set-string env.OPENAI_API_KEY='sk-...' --wait
```

チャートには `OPENAI_API_KEY` のプレースホルダーが含まれます。インストールやアップグレード時に利用するプロバイダーの値と `config.model` を上書きするか、values ファイルを指定してください。

> リリース名をチャート名と同じ `hermes-agent` にすると、リソース名が `hermes-agent-0` となり、`hermes-agent-hermes-agent-0` のような重複を避けられます。`fullnameOverride` で指定することもできます。

### インストール設定: LLM プロバイダー

主なインストール設定は、Hermes が接続する LLM バックエンドです。チャットプラットフォームは、下の[メッセンジャー連携](#メッセンジャー連携telegram--discord)を参照してください。

- **組み込みプロバイダー**: `config.model.provider` に Hermes の識別子（`openai-api`、`anthropic`、`gemini`、`openrouter`、`nvidia`、`deepseek`、`lmstudio` など）、`config.model.default` にそのモデル ID を指定します。対応するキーを `env`（`OPENAI_API_KEY`、`ANTHROPIC_API_KEY`、`GOOGLE_API_KEY`、`NVIDIA_API_KEY` など）に設定します。

  ```bash
  # OpenAI
  helm upgrade --install hermes-agent ./charts/hermes-agent -n hermes-agent --create-namespace \
    --set-string config.model.provider=openai-api \
    --set-string config.model.default=gpt-4o-mini \
    --set-string env.OPENAI_API_KEY='sk-...' --wait

  # Gemini
  helm upgrade --install hermes-agent ./charts/hermes-agent -n hermes-agent --create-namespace \
    --set-string config.model.provider=gemini \
    --set-string config.model.default=gemini-2.5-flash \
    --set-string env.GOOGLE_API_KEY='<your-key>' \
    --set-string env.OPENAI_API_KEY=unused --wait

  # NVIDIA NIM (this is the provider CI exercises end-to-end)
  helm upgrade --install hermes-agent ./charts/hermes-agent -n hermes-agent --create-namespace \
    --set-string config.model.provider=nvidia \
    --set-string config.model.default=nvidia/nemotron-3-nano-omni-30b-a3b-reasoning \
    --set-string env.NVIDIA_API_KEY='nvapi-...' \
    --set-string env.OPENAI_API_KEY=unused --wait
  ```

- **カスタムの OpenAI 互換プロバイダー**（LiteLLM、vLLM、LM Studio など）: `config.providers.<id>` に `base_url` と `key_env` を登録し、`config.model.provider` にその `<id>` を指定します。[追加サンプル](#追加サンプル)の `values-litellm.yaml`（外部プロキシ）または `values-litellm-k8s.yaml`（クラスター内）を参照してください。

### メッセンジャー連携（Telegram / Discord）

ワークロードの `hermes gateway run` は、**認証情報**が設定されたチャットプラットフォームに接続します。ボットトークンを渡すだけで連携できます。トークンは機密情報なので `.Values.env`（Secret に生成）に指定し、許可ユーザーやホームチャンネルなどの非機密設定は `.Values.extraEnv`（通常の環境変数）に指定します。トークンの設定だけでプラットフォームは**自動的に有効**になり、`config.yaml` の変更は不要です。

> **検証状況:** チャートが正しい Secret と環境変数を生成し、エージェントがプラットフォームを認識します。`DISCORD_BOT_TOKEN` と `DISCORD_HOME_CHANNEL` のシークレットが設定された信頼できる CI 実行では、`hermes send` で送信し、Discord API でチャンネルを読み戻して到着を確認する実通信テストを行います。**確認できなければ失敗**します。ボットには *View Channel* と *Read Message History* が必要です。フォークの PR ではシークレットを公開しないため省略します。Telegram はまだプレースホルダーによる設定のみです。自分のクラスターで試すには実際のボットトークンを指定してください。

- **Discord**: [Discord Developer Portal](https://discord.com/developers/applications) でボットを作成し、**Message Content Intent** を有効にしてサーバーへ招待します。

  ```bash
  helm upgrade --install hermes-agent ./charts/hermes-agent -n hermes-agent --create-namespace \
    --set-string config.model.provider=nvidia \
    --set-string config.model.default=nvidia/nemotron-3-nano-omni-30b-a3b-reasoning \
    --set-string env.NVIDIA_API_KEY='nvapi-...' \
    --set-string env.OPENAI_API_KEY=unused \
    --set-string env.DISCORD_BOT_TOKEN='<bot-token>' --wait
  ```

  任意の非機密設定（`extraEnv` または `--set`）:

  | 環境変数 | 意味 |
  | --- | --- |
  | `DISCORD_ALLOWED_USERS` | ボットとの会話を許可するユーザー ID。カンマ区切り |
  | `DISCORD_ALLOW_ALL_USERS` | `true` で全員を許可（開発専用） |
  | `DISCORD_HOME_CHANNEL` | cron や通知の送信先チャンネル ID |
  | `DISCORD_HOME_CHANNEL_NAME` | ホームチャンネルの表示名 |

- **Telegram**: [@BotFather](https://t.me/BotFather) でボットを作成し、`env.TELEGRAM_BOT_TOKEN` を設定します。必要なら `extraEnv` で `TELEGRAM_HOME_CHANNEL` と `TELEGRAM_ALLOWED_USERS` も指定します。

- **Slack**: Socket Mode 用に `env.SLACK_BOT_TOKEN` と `env.SLACK_APP_TOKEN` を設定します。ネイティブ Slack アダプターから送信するメッセージのリンクやメディアのプレビューを抑止するには、次の部分設定を追加します。

  ```yaml
  config:
    platforms:
      slack:
        extra:
          unfurl_links: false
          unfurl_media: false
  ```

  relay アダプター経由で送信する Slack メッセージには、relay の名前空間を使用します。

  ```yaml
  config:
    platforms:
      relay:
        extra:
          slack:
            unfurl_links: false
            unfurl_media: false
  ```

  キーを省略すると Slack の標準プレビュー動作を保持します。この設定は Slack への送信メッセージだけに影響します。

コピーできるメッセンジャー設定は、[追加サンプル](#追加サンプル)の `values-anthropic-and-discord.yaml` / `values-openai-and-telegram.yaml` を参照してください。

## デバイスフローによるログイン（GitHub Copilot と OpenAI Codex）

`auth.deviceFlow.enabled=true` で **`auth-device-login` init コンテナー**を追加します。認証 URL と一度限りのコードを Discord または Telegram のホームチャンネル（またはログ）へ送り、人間の承認を待ち、得られた認証情報を `HERMES_HOME` ボリュームに保存します。

- `github-copilot` は GitHub の OAuth 2.0 デバイス認可を実行し、`COPILOT_GITHUB_TOKEN` を `.env` に書き込みます。
- `openai-codex` はチャートが固定する Hermes バージョンのデバイスコードフローに従い、Hermes のネイティブヘルパーでリフレッシュトークンの連鎖を含む `auth.json` をアトミックに更新します。ChatGPT/Codex アカウントの認証であり、API キーを使う `openai-api` とは別です。

```bash
helm upgrade --install hermes-agent ./charts/hermes-agent -n hermes-agent --create-namespace \
  -f charts/hermes-agent/values-openai-codex.yaml \
  --set-string env.DISCORD_BOT_TOKEN='<bot-token>' --wait
# then approve the prompt posted to Discord (or read it from the logs):
kubectl logs deploy/hermes-agent -n hermes-agent -c auth-device-login -f
```

**動作するプロバイダーとチャンネルの組み合わせ。** 1 つのリリースは 1 つのプロバイダー（`auth.deviceFlow.provider`）にログインし、コードと準備完了メッセージは 1 つのチャンネル（`notify`）に届きます。2 つのプロバイダーと 2 つのメッセンジャーの 4 通りすべてを実際のクラスターで実行しました（イメージ `v2026.9.24`、2026 年 10 月）。各実行では、チャンネルへのコードの到着、承認、保存された認証情報、完了メッセージ、準備完了メッセージ、メンションへのモデルの応答までを確認しています。

| プロバイダー | Discord | Telegram |
| --- | --- | --- |
| `openai-codex` | 確認済み（`gpt-6-luna`） | 確認済み（`gpt-6-luna`） |
| `github-copilot` | 確認済み（`gpt-4o`、Copilot Free アカウント） | 確認済み（`gpt-4o`、Copilot Free アカウント） |

Copilot の実行には Free アカウントを使ったため、利用できるモデルは GitHub のプランの規則に従います。また Discord では `DISCORD_ALLOWED_USERS` に自分のユーザー ID も必要です（登録されていないアカウントからのメッセージは、ログを残さずに無視されます）。

```bash
# Same flow with Telegram instead of Discord (Copilot shown).
helm upgrade --install hermes-copilot ./charts/hermes-agent -n hermes-copilot --create-namespace \
  -f charts/hermes-agent/values-github-copilot.yaml \
  --set auth.deviceFlow.notify=telegram \
  --set-string env.TELEGRAM_BOT_TOKEN='<bot-token>' \
  --set-json 'extraEnv=[{"name":"TELEGRAM_HOME_CHANNEL","value":"<chat-id>"},{"name":"TELEGRAM_ALLOWED_USERS","value":"<user-id>"}]'
```

注意点:

- **`persistence.enabled=true` が必須**です。ボリュームがないと再起動でトークンが失われ、毎回承認が必要になります。
- **`notify`** は `discord`（`DISCORD_BOT_TOKEN` と `DISCORD_HOME_CHANNEL` を再利用）、`telegram`（`TELEGRAM_BOT_TOKEN` と `TELEGRAM_HOME_CHANNEL` を再利用）、または `logs`（認証プロンプトを init コンテナーのログにだけ表示）です。`telegram` の場合は `sendMessage` だけで送信するため、同じボットをポーリングするエージェントと競合しません。複数リリースのチームでは、デバイスログインを実行するすべてのリリースに `TELEGRAM_HOME_CHANNEL` を設定してください。各プロンプトにはリリース名（チームモードではチーム内の識別名）が入るため、並行するログインを見分けられます。
- **準備完了メッセージ**: 「login complete」は認証情報が保存されたことを示すだけです。初回起動にはその後も数分かかることがあり（スキルの同期、モデルのウォームアップ）、Hermes は*再起動*は通知しますが新規起動は通知しません。`readyNotify.enabled=true` を設定すると、ゲートウェイが起動した時点で同じ Discord または Telegram のホームチャンネルに 1 行投稿します（`readyNotify.notify` でチャンネルを選び、デバイスフローが有効な場合は `auth.deviceFlow.notify` に従います）。チャートは `env` / `extraEnvFrom` にあるボットの認証情報を再利用する `gateway:startup` フックを `HERMES_HOME/hooks/ready-notify` に配置します。実際の初回起動では、メッセージは Hermes 自身の `Gateway running` ログ行と同時に届き、最初のターンの準備が整う数秒前でした。
- init コンテナーは任意のストレージクラスに書き込めるよう **root** で実行され、トークンファイルを `auth.deviceFlow.tokenOwner` に **chown** します。デフォルトは上流イメージの実行ユーザーである uid/gid `10000` で、非 root のエージェントが読めるようにします。
- **プロファイル選択:** `auth.deviceFlow.provider` で `github-copilot` または `openai-codex` を選択します。Copilot のクライアント ID は上流 Hermes と共通です。OpenAI のプロトコル定数と保存処理は、チャート独自の認証情報ではなく固定した Hermes イメージから提供されます。

## エージェントチーム

Hermes は**単一インスタンスのパーソナルエージェント**です。複数の独立したインスタンスを運用し、**1 つの Discord チャンネル**をコンテキストの共有経路とするチームにまとめます。各エージェントは専用のボットトークン、Pod、非公開の `HERMES_HOME` PVC、アイデンティティを持ちます。タスクの調整は Discord チャンネルだけで共有し、チームの知識ボリュームは別途マウントします。

### `@mention` による引き継ぎ

各インスタンスに同じ `DISCORD_HOME_CHANNEL` と、それぞれ異なる `DISCORD_BOT_TOKEN` を設定します。引き継ぎは返信参照ではなく、Discord メッセージの**本文**に明示的な `<@BOT_USER_ID>` を入れて行います。次の 4 つの環境変数で、引き継ぎを安定させ、ボット間の無限往復を防ぎます。

| 環境変数 | 推奨値 | 理由 |
| --- | --- | --- |
| `DISCORD_ALLOW_BOTS` | `mentions` | 相手のボットが明示的に `@mention` した場合だけ応答する。 |
| `DISCORD_THREAD_REQUIRE_MENTION` | `true` | 共有スレッドでは明示的なメンションでのみ起動する。 |
| `DISCORD_REPLY_TO_MODE` | `off` | 返信参照による自動通知でループが再開しないよう、参照を付けない。 |
| `DISCORD_ALLOW_MENTION_REPLIED_USER` | `false` | 自動の返信通知を実際のメンションとして扱わない。 |

これらは `env` / `extraEnv` に設定します。Discord アダプターが `os.getenv` で直接読むため、`config` 配下には置きません。

`config.group_sessions_per_user: false` と `config.discord.history_backfill: true` も設定します。そうしないと、同じスレッド内でも人間と各ボットの送信者が異なるセッションに分離されます。履歴の補完により、ボットがメンションされていない間の表示可能なメッセージも取得できます。

### クイックスタート: 2 体のエージェントと 1 つのチャンネル

```bash
helm upgrade --install hermes-planner ./charts/hermes-agent \
  --namespace hermes-team --create-namespace \
  -f charts/hermes-agent/values-multi-agent-collab.yaml \
  --set-string env.DISCORD_BOT_TOKEN='<planner-bot-token>' --wait

helm upgrade --install hermes-builder ./charts/hermes-agent \
  --namespace hermes-team \
  -f charts/hermes-agent/values-multi-agent-collab.yaml \
  --set-string env.DISCORD_BOT_TOKEN='<builder-bot-token>' --wait
```

3 体以上のエージェントや GitOps でメンバー一覧を宣言的に管理する場合は、**ArgoCD ApplicationSet** を使用します。メンバー追加は 1 行の差分で行えます。[`hermes-collab-pair.yaml`](../../examples/argocd/hermes-collab-pair.yaml)、[チーム](../../docs/advanced/teams/reference.md)、[連携](../../docs/advanced/teams/collaboration.md)を参照してください。

リーダーと複数のメンバーには [`values-team-leader.yaml`](values-team-leader.yaml) と [`values-team-member.yaml`](values-team-member.yaml) を使用します。このプロトコルは明示的なボットメンションを 1 件ずつ処理し、すべてのタスク、結果、レビューを Discord スレッドに残します。チームモードでは、共通のメンバー一覧とプロトコルのスキル ConfigMap を各 Pod にマウントします。リーダーのリリースが ConfigMap と RWX 知識 PVC を一度だけ作成し、メンバーは名前で参照して読み取り専用でマウントします。PVC は永続的な共有知識を保存しますが、タスク、状態、結果の引き継ぎには使用しません。ApplicationSet の例では、メンバー一覧と共通ポリシーを一度だけ宣言し、各項目にはアイデンティティ、役割、専用 Secret 名だけを指定します。
`file` と `memory` ツールセットは各エージェント自身の作業には利用できます。禁止するのは、ファイル、メモリ、フック、バックグラウンド処理を使ったエージェント間の引き継ぎです。

Telegram のチームでは `team.platform: telegram` を設定し、役割ごとの Telegram 用 values ファイルを使い、[Telegram チームガイド](../../docs/advanced/teams/telegram.md)に従ってください。1 つのボットを共有するアシスタント構成、BotFather の設定、リリースごとの Secret、メンションのルーティング、ループ防止、ArgoCD ApplicationSet を扱っています。Telegram チームのサンプルは CI でレンダリングを確認しています。実際の Telegram グループでの実行では、2 つのモデル（`nemotron-3-ultra-550b` と `gpt-6-luna`）でリーダー、メンバー、リーダーの引き継ぎを最後まで完了しました。記録は [#311](https://github.com/jyje/hermes-agent-helm/pull/311) のコメントにあります。リーダーのモデルは重要で、30B のモデルは委任せずに自分で回答しました。別の人間アカウントがブロックされる場合、ループガードのしきい値、連続する複数の引き継ぎは検証していません。

**例: すべてのボットが OpenAI Codex にログインする Telegram チーム。** 各リリースが個別にログインするため、外部の認証プロキシや共有トークンは使いません。3 つのボットトークンを Secret（`tg-august`、`tg-may`、`tg-march`。それぞれ `TELEGRAM_BOT_TOKEN` キーを持つ）に入れ、役割ごとの values ファイルに 1 つのオーバーレイを重ねます。

```yaml
# codex-overlay.yaml
config:
  model:
    provider: openai-codex
    default: gpt-6-luna            # gpt-6-luna-900k for the larger window
auth:
  deviceFlow:
    enabled: true
    provider: openai-codex
    notify: telegram               # each code arrives in the team group
readyNotify:
  enabled: true                    # one "ready" line per bot when it is up
```

```bash
# Install all three at once. Each bot posts its own code to the group,
# for example "OpenAI Codex login required for may".
for r in august may march; do
  role=member; [ "$r" = august ] && role=leader
  helm upgrade --install "hermes-$r" ./charts/hermes-agent \
    --namespace hermes-team --create-namespace \
    -f "charts/hermes-agent/values-telegram-team-$role.yaml" -f codex-overlay.yaml \
    --set-string "fullnameOverride=hermes-$r" --set-string "team.identity=$r" \
    --set-json "extraEnvFrom=[{\"secretRef\":{\"name\":\"tg-$r\"}}]" &
done; wait
```

3 つのコードを `https://auth.openai.com/codex/device` で承認します。まだチームにメッセージを送らないでください。「login complete」の後も初回起動には数分かかり（実際の実行では約 7 分）、その間に送ったメッセージは失われます。各ボットの「is ready」の行を待ってから、リーダーにメンションしてください。

- メンバーの values ファイルと同様に、**すべての**リリースに `TELEGRAM_HOME_CHANNEL` を設定します。ログインと準備完了のメッセージはそこに届きます。
- 1 つの ChatGPT アカウントで 3 回ログインしても実際の確認ではリフレッシュに問題はありませんでしたが、上流では同じアカウントの 2 回目のログインが古いログインを無効にするとしています。チームではボットごとに 1 アカウントを推奨します。確認した内容としていない内容は [OpenAI Codex](../../docs/advanced/providers/openai-codex.md) を参照してください。
- 各ボットのグループでの最初の返信に、Hermes の一度きりの「caps context at 272K」通知が含まれることがあります。`compression.codex_gpt55_autoraise_notice: false` で非表示にできます。

> 上流では、Hermes ボット同士の Discord 会話は組み込みのサーキットブレーカーを持たない非対応の構成とされています。この例は実験的なものです。専用の信頼できるチャンネルを使用し、手動停止手段を確保して、固定したイメージで実通信を検証してから利用してください。

参照シーケンスは kind 上の `v2026.7.20` で実通信を完了しています。日時付きの[チーム検証記録](../../docs/advanced/teams/reference.md#leader-orchestrated-teams)を参照してください。

> **別の構成: 1 つの Pod と複数のプロファイル。** 1 つのチャンネルで複数のボットを連携させるのでなく、**単一のボットトークン**で Discord のサーバー、チャンネル、スレッドごとに異なるエージェントプロファイルへ振り分けたい場合は、ゲートウェイのプロファイル多重化を使います。上流ではこれが既定で有効なので（`gateway.multiplex_profiles` の既定値は `true` で、`true` だけが有効な値です。以前の `false` は廃止されました）、チャートの設定は不要です。Pod は 1 つで済みます。これは連携ではなくルーティングのための機能なので、目的に合わせて選択してください。

## 詳細なテスト

[`helm test`](#テスト) Job（フック `helm.sh/hook: test`）は `hermes --version`、初期配置した `config.yaml` の確認、docker の利用可否の確認、`hermes doctor` を実行します。バックエンドは `local` なので docker の確認は情報表示のみです。さらに、チャートが Hermes イメージ内で実行するコードをイメージ更新時の非互換から守るため、対応する機能が有効な場合だけ 2 つの検査を実行します。OpenAI Codex デバイスログインではログイン処理がインポートする Hermes ヘルパーの存在を確認し、`readyNotify.enabled` では初期配置した `gateway:startup` フックを Hermes が検出して実行することを確認します。`--set tests.enabled=false` で Job を無効にでき、`--set tests.doctorStrict=true` で doctor の問題をテスト失敗として扱えます。

Kubernetes 1.33 以降では、`tests.isolateDoctor: true` で任意の診断を再起動可能な別の init コンテナで実行できます。診断がメモリ不足で終了したり待機時間内に完了しなかったりしても、必須チェックは続行されます。`tests.resources` は各コンテナに適用されます。診断ログは `kubectl logs job/<release>-test -c hermes-doctor-diagnostics` で確認してください。`tests.doctorStrict` が有効な場合は隔離を無効にします。

### プロバイダーのエンドツーエンド検証（`tests.chat.enabled`）

`tests.chat.enabled=true` は 5 番目の検査を追加します。インストール時と**同じ `config` / `env`** で実際の `hermes chat` 往復通信を行い、**プロンプトと応答の全文をテスト Job のログへ出力**します。メインのワークロードと同じ ConfigMap と Secret をマウントするため、別の API キーは不要です。`helm test` は `--set` を受け付けないので、先に `helm upgrade --reuse-values` で有効にします。

```bash
helm upgrade hermes-agent ./charts/hermes-agent -n hermes-agent \
  --reuse-values --set tests.chat.enabled=true --wait

helm test hermes-agent -n hermes-agent
kubectl logs -n hermes-agent -l app.kubernetes.io/component=test --tail=-1
```

出力例（NVIDIA NIM、`tests.chat.prompt` のデフォルトは `Just say hi.`）:

```
[5/5] hermes chat round-trip
--- prompt ---
Just say hi.
--- model: (config default) (timeout 180s) ---
Query: Just say hi.
Initializing agent...
────────────────────────────────────────

╭─ ⚕ Hermes ───────────────────────────────────────────────────────────────────╮
    Hi.
╰──────────────────────────────────────────────────────────────────────────────╯

--- end response ---
```

往復通信の失敗や空の応答は、デフォルトでは**テスト失敗にせず**ログに記録します。`tests.chat.failOnError=true` で Job を失敗させられます。CI は `NVIDIA_API_KEY` シークレットがある場合にこの設定を使用します。

無料枠のモデルが不安定または過負荷になる場合は、`tests.chat.models` に `provider/model` ID のリストを指定します。Job は `hermes chat -m <id> --provider <config.model.provider>` で順番に試し、各試行に `tests.chat.timeout` を適用し、1 つ成功すれば合格します。CI でも少数の無料 NVIDIA NIM モデルでこの方法を使います。

## 設定モデル

Hermes は `$HERMES_HOME/config.yaml` と環境変数のシークレットを、バージョン固有の組み込みデフォルトへの**部分的な上書き**として読み込みます。優先順位は CLI > `config.yaml` > `.env` > 組み込みデフォルトです。このチャートも同じモデルを採用し、変更したい値だけを設定します。上流の設定全体を複製するとバージョン間でずれるため、複製しません。

> **パススルーの原則。** `.Values.config` は**そのまま** `config.yaml` に生成され、どの階層にも任意のキーを追加できます（`values.schema.json` 参照）。Hermes の[設定ガイド](https://hermes-agent.nousresearch.com/docs/user-guide/configuration)や[環境変数リファレンス](https://hermes-agent.nousresearch.com/docs/reference/environment-variables)の設定は、`config.<path>` または `env` / `extraEnv` から**チャートを変更せず**指定できます。この README はインストール時によく使うプロバイダー、メッセンジャー、チーム構成を中心に説明します。探し方は [FAQ](#faq) を参照してください。

- **`config.yaml`**: `.Values.config` に上書きするキーだけを設定します。ConfigMap に生成し、init コンテナーが永続ボリュームの **`HERMES_HOME` に初期配置**します。Hermes 自身もスキル、`auth.json`、自己改善などを実行時に書き込むためです。`bootstrap.overwrite=false`（デフォルト）はファイルがない場合だけ配置して実行時の編集を保持します。`true` にするとデプロイごとにチャートの設定で置き換えます。初期配置後、init コンテナーが Hermes の非対話型の設定マイグレーションを実行します。変更前に `config.yaml` と `.env` をバックアップし、マイグレーションに失敗した場合は元に戻します。明示的なバージョンがない設定は、新しい部分設定としてマイグレーションされます。上流のサポート下限（現在 v12）より古いバージョンを明示した設定は変更しないため、下記の復旧手順に従ってください。
- **`SOUL.md` のアイデンティティ**: `.Values.soul.text` で `HERMES_HOME/SOUL.md` に永続的なエージェントのアイデンティティを配置します。空の場合は Hermes が初回起動時に初期ファイルを作成します。配置の判断は `config.yaml` と独立しており、`bootstrap.overwrite=false` なら既存の内容を保持し、`true` ならデプロイごとに置き換えます。ConfigMap に保存されるため、シークレットを含めないでください。内容と適用範囲は上流の [SOUL.md ガイド](https://hermes-agent.nousresearch.com/docs/guides/use-soul-with-hermes)を参照してください。
- **シークレットと API キー**: `.Values.env` に設定します。Secret に生成し、`envFrom` で環境変数として注入します。環境変数は `config.yaml` より優先されます。

#### マイグレーションの下限より古い設定の復旧

Hermes は、サポートされていないスキーマバージョンを明示した設定の自動マイグレーションを意図的に拒否します。編集する前に `HERMES_HOME/config.yaml` をバックアップしてください。まず上流のマイグレーション履歴を確認し、ファイルのキーがサポートされる下限と互換であれば、ルートに `_config_version: 12` を設定してワークロードを再起動します。Hermes はサポートされるマイグレーションを実行し、マイグレーション前のバックアップを `HERMES_HOME/backups/config/` に残します。互換でない場合は `hermes setup` で現在の設定を生成し、必要な設定をバックアップから戻してください。`bootstrap.overwrite=false` では、この復旧ができるようチャートは既存のファイルを既定で保持します。`bootstrap.overwrite=true` では、マイグレーションの前に values から生成した設定で置き換えます。

### リモート設定（オプトイン）

Hermes v0.23.0 以降、複数のエージェントを運用する場合は、各プロファイルの設定を中央の設定サービスから読み込めます。ワークロードは `config:` ではなく環境変数でバックエンドを選択します。セルフホストの設定サービスを使う場合は、まずエージェントを登録し、次の Helm values を設定します。

```yaml
extraEnv:
  - name: HERMES_CONFIG_BACKEND
    value: remote
  - name: HERMES_CONFIG_INSTANCE_ID
    value: my-registered-agent
  - name: HERMES_CONFIG_REMOTE_URL
    value: https://config.example.com
extraEnvFrom:
  - secretRef:
      name: hermes-remote-config-credentials
```

インスタンス ID と HTTPS URL を実際の値に置き換えます。リリースと同じ名前空間に参照先の Secret を作成し、`GATEWAY_RELAY_IDP_TOKEN_URL`、`GATEWAY_RELAY_IDP_CLIENT_ID`、`GATEWAY_RELAY_IDP_CLIENT_SECRET` を設定します。`GATEWAY_RELAY_IDP_SCOPE` は任意です。Hermes Cloud を使う場合は、カスタム URL とこの Secret 参照を省略し、プロファイルの `auth.json` で Nous アクセストークンを利用できるようにします。認証と複数プロファイルの設定方法は、[上流のリモート設定ガイド](https://github.com/NousResearch/hermes-agent/blob/v0.23.0/website/docs/user-guide/remote-config.md)を参照してください。

リモートモードではローカルの `config.yaml` は読み込まれません。Helm の `config:` を変更しても設定サービスには反映されません。起動時にリモート設定を取得できない場合、Hermes はローカルファイルにフォールバックせず終了します。

ローカルファイルの初期配置を意図的に省略する場合を除き、`bootstrap.enabled` はデフォルトの `true` のままにしてください。無効にすると、設定した `SOUL.md` や ready-notify フックも配置されなくなり、新しいテスト用ボリュームに `config.yaml` がないため、標準の `helm test` は失敗します。`helm test` に成功しても、ワークロードからリモート設定サービスへの接続は検証されません。デプロイしたワークロードが起動し、サービスからプロファイル設定を読み込めることを確認してください。

### シークレットの供給方法

デプロイごとに方法を選びます。API キーに SealedSecret、それ以外に Bitwarden を使うなど、組み合わせも可能です。

| 方法 | 用途 | 参照先 |
| --- | --- | --- |
| 通常の `.Values.env` | ローカル開発、または実際の値を含めてコミットしない values ファイル | この README のプロバイダー例 |
| SealedSecret + `extraEnvFrom` | GitOps。実際のシークレットを暗号化してコミットする | [`examples/argocd/`](../../examples/argocd/) |
| Bitwarden Secrets Manager | ローテーション可能な初期トークン 1 つで複数のプロバイダーキーを管理 | [`values-bitwarden.yaml`](values-bitwarden.yaml) |
| 1Password | このチャートでは未対応。起動時にイメージ内の PATH に `op` CLI が必要で、values サンプルだけでは追加できない。まず上流側の対応を確認・実装する。 | : |

GitOps では実際のキーを `env` に入れてコミットしないでください。`extraResources` で `SealedSecret` などをデプロイし、生成された Secret を `extraEnvFrom` で参照します。チャート自身の Secret の後に適用されるため優先されます。完全な例は [`examples/argocd/`](../../examples/argocd/) を参照してください。

Bitwarden Secrets Manager は起動時に `config.secrets.bitwarden` からプロバイダーのキーを解決します。初期認証情報 `BWS_ACCESS_TOKEN` だけを外部管理の Kubernetes Secret に置き、`extraEnvFrom` で参照します。[`values-bitwarden.yaml`](values-bitwarden.yaml) を参照してください。初回起動ではチェックサムを検証した `bws` CLI を `HERMES_HOME` にダウンロードするため、Pod から Bitwarden と GitHub Releases への外向き通信が必要です。

### ダッシュボードの公開

<p align="center"><a href="https://raw.githubusercontent.com/jyje/hermes-agent-helm/main/docs/images/dashboard-architecture.png"><img src="https://raw.githubusercontent.com/jyje/hermes-agent-helm/main/docs/images/dashboard-architecture.png" alt="アーキテクチャ: ブラウザから Ingress、Service のポート 9119 を経て hermes dashboard プロセスへ。同じ Pod で hermes gateway run と HERMES_HOME ボリュームを共有します" width="900"></a></p>

管理ダッシュボード（`service.port`、デフォルト 9119）はイメージ内の s6 サービスで、唯一の組み込み Web UI です。ダッシュボード自体は上流の Hermes のもので、このチャートは有効化して公開するだけです。ログインしたユーザーには API キーが表示され、シェルフックの作成や Chat タブの利用もできるため、ログインは Pod へのシェルアクセスとして扱い、次の手順を順番に進めてください。

**1. ログイン方式を選ぶ。** ループバック以外にバインドする場合、上流の認証ゲートは必須です。プロバイダーがないとダッシュボードは**安全側に停止し、待ち受けを開始しません**。`--insecure` と `HERMES_DASHBOARD_INSECURE` は上流で非推奨となり、効果がありません。

| 方式 | `dashboard.auth.provider` | 用途 | サンプル |
| --- | --- | --- | --- |
| ユーザー名とパスワード | `basic` | 信頼できるネットワークまたは VPN。上流はインターネットへの公開には推奨していません。 | [`values-ingress.yaml`](values-ingress.yaml) |
| Nous Portal OAuth | `oauth` | 公開ホスト。ポータルで **Base URL** に外部オリジンを設定します（`/auth/callback` が付加されます）。個人アカウントのクライアントでは、ログインは所有者に限られます。 | [`values-ingress-oauth.yaml`](values-ingress-oauth.yaml) |
| 独自の OpenID Connect プロバイダー | `oidc` | 独自の ID プロバイダーを使う公開ホスト（シークレットなしの public PKCE クライアント）。ダッシュボードにはユーザー許可リストがなく、プロバイダーがこのクライアント向けにトークンを発行するすべての ID がログインできるため、アプリケーションの制限はプロバイダー側で行います。 | [`values-ingress-oidc.yaml`](values-ingress-oidc.yaml) |

認証情報を `extraEnvFrom` や ExternalSecret から渡す場合は `external` を使います。それ以外では、プロバイダーのキーが `env` または `extraEnv`（OAuth と OIDC は `config.dashboard.oauth` も）にない場合、502/503 を返す Ingress を残す代わりにレンダリング時にテンプレートが失敗します。`basic` には `HERMES_DASHBOARD_BASIC_AUTH_USERNAME` と、`_PASSWORD` または `_PASSWORD_HASH` が必要です。OAuth のクライアント ID と OIDC の issuer はシークレットではないため、サンプルでは `config.dashboard.oauth` に置いています。

**2. 有効化してルーティングする。** `dashboard.enabled: true`（`HERMES_DASHBOARD=1` をレンダリングします）、`service.enabled: true`、そして `ingress` または `httpRoute` を設定します。`dashboard.publicUrl` は `config.dashboard.public_url` になります。空の場合は最初の Ingress ホストから導出され（`ingress.tls` を設定すると `https`）、HTTPRoute では明示的に設定します。ID プロバイダーに登録した外部オリジンと一致させる必要があります。`config.dashboard` に既に設定した値が優先されます。

`HERMES_DASHBOARD=1` を `extraEnv` や `env` に直接書くより `dashboard.enabled` を使ってください。イメージは変数だけでも動作しますが、チャートからは見えないため、readiness プローブ、導出される `public_url` と `trusted_proxies`、認証プロバイダーの確認、信頼するプロキシの警告がすべて省略されます。変数を使い続ける場合は、`service.port` への `tcpSocket` プローブなど、独自の `probes.readiness` を追加してください。

**3. 信頼するプロキシを設定する。** TLS を終端する Ingress の背後では、`dashboard.trustedProxies` にコントローラーを指定します（`config.dashboard.trusted_proxies` になります。正確な IP または限定した CIDR で、`0.0.0.0/0` は拒否されます）。指定がないと上流は `X-Forwarded-Proto` を無視し、ログインはできてもセッション Cookie に `Secure` が付きません。この欠落は表面化しないため、信頼するプロキシなしで `https` で公開するとリリースノートに警告が表示されます。ダッシュボードから見たピアのアドレスを指定します。これはコントローラーによって異なります。

- 通常のコントローラー Pod: その Pod IP または Pod CIDR。`kubectl get pods -n <コントローラーの namespace> -o wide` で確認します。
- ホストネットワークのコントローラー（MicroK8s の ingress など）: それが動くノードのアドレス。Calico VXLAN のようなオーバーレイ CNI では、これはダッシュボード Pod と**同じノード**のコントローラーにしか当てはまりません。別のノードのコントローラーは、Pod ネットワーク内にあるそのノードのトンネルアドレスから接続します。ノードごとにコントローラーがある MicroK8s での実測では、ノードネットワークだけを指定すると、他のノード経由のログインは成功しても Cookie の `Secure` が失われました。ノードネットワークと Pod ネットワークの両方を指定してください（例: `10.0.4.0/24` と `10.1.0.0/16`）。Pod ネットワークは `kubectl get ippools.crd.projectcalico.org`（Calico）または `kubectl get nodes -o jsonpath='{.items[*].spec.podCIDR}'` で確認します。

正確な IP はコントローラー Pod が再作成されると一致しなくなります。テスト以外では限定した CIDR を推奨します。

**4. 後から変更する場合。** `public_url` と `trusted_proxies` はボリュームの初回シード時に `config.yaml` へ書き込まれ、`bootstrap.overwrite` のデフォルトは `false` です。そのため、ホストや `dashboard.*` の値を変える後続の `helm upgrade` は Pod に**反映されず**、古い `public_url` は OAuth と OIDC のコールバックを壊します。そのアップグレードでは `--set bootstrap.overwrite=true` を指定します。これは `config.yaml`（と設定した `SOUL.md`）をチャートのレンダリング内容で置き換えるため、先に実行時の変更をバックアップし、その後 `false` に戻してください。

**5. 初回起動は遅い。** 初回起動では同梱スキルがボリュームに同期されるため、数分かかることがあります（ネットワークストレージではさらに長くなります）。ダッシュボードが有効な間、チャートは `service.port` への TCP readiness プローブ（`dashboard.readinessProbe`）をレンダリングするため、ダッシュボードが待ち受けを始めるまで Pod は NotReady のままで、Ingress もルーティングしません。`helm --wait` はこれを待ちます。明示的な `probes.readiness` が優先され、readiness が Pod を再起動することはありません。

**6. 確認する。** セッションなしでは `GET /` はログインページへリダイレクトし、`/api/env` と `/api/config` は 401 を返します。ログイン後、`GET /api/auth/me` はプロバイダーを報告し、セッション Cookie は `__Host-`、`Secure`、`HttpOnly` になります。

| 症状 | 考えられる原因 |
| --- | --- |
| インストール直後に Ingress が 502 を返す | 初回起動がまだ続いています。ダッシュボードが待ち受けるまで Pod は NotReady です。 |
| ダッシュボードが待ち受けを始めない | 認証プロバイダーが設定されていないため、ゲートが安全側に停止しています。 |
| OIDC: `/auth/login` が 503 を返す | issuer が誤っています。レスポンス本文に理由（`OIDC discovery returned 404 for ...`）が含まれます。独自のエラーページを持つプロキシでは隠れることがあるため、Service に直接問い合わせてください。issuer の末尾スラッシュの違いは許容されます。 |
| ID プロバイダーが `Unregistered redirect_uri`（OIDC）、またはポータルが `redirect_uri_mismatch`（OAuth）を表示する | 外部オリジンが登録内容と異なります。ホストを変更した場合は手順 4 を参照してください。 |
| ログインはできるが Cookie が `Secure` にならない | 信頼するプロキシがない、アドレスが誤っている、または `*.localhost` ホスト（上流はループバックのホストを開発環境として扱います）。オーバーレイ CNI 上のホストネットワークのコントローラーの背後では、リクエストが入るノードによって変わることがあります。Pod ネットワークも指定してください（手順 3）。 |
| `networkPolicy` を有効にすると Ingress がタイムアウトする（一部のコントローラー経由のみの場合もある） | ポリシーがすべての受信を拒否し、コントローラーが許可されていません。手順 7 を参照してください。 |

**7. NetworkPolicy を使う場合。** `networkPolicy.enabled` はすべての受信通信を拒否するため、Pod が Ready のまま（kubelet のプローブは影響を受けません）、Ingress からダッシュボードへの通信が気付かないうちに遮断されます。`networkPolicy.extraIngress` にポート 9119 のルールを追加してください。ホストネットワークのコントローラーは Pod や namespace のセレクターに一致しません。オーバーレイ CNI（Calico VXLAN で実測）ではノードネットワークと Pod ネットワークの両方を許可し、同じ 2 つの CIDR を `dashboard.trustedProxies` にも指定します。実測したルールとすぐに使えるオーバーレイは [`values-networkpolicy-dashboard.yaml`](values-networkpolicy-dashboard.yaml) にあります。

### API サーバーと webhook リスナー

`apiServer.enabled` は Hermes の OpenAI 互換 API サーバーを起動します。上流のデフォルトはループバックですが、このチャートでは Kubernetes Service から到達できるよう `0.0.0.0` を使います。`API_SERVER_KEY` を `env`、または推奨の `extraEnvFrom` で参照する外部管理 Secret に設定してください。ループバックだけで待ち受ける場合も必須です。`apiServer.corsOrigins` は明示的かつ限定的なブラウザーオリジンの許可リストにのみ使用します。上流の [API サーバーガイド](https://hermes-agent.nousresearch.com/docs/user-guide/features/api-server)を参照してください。

`webhook.enabled` は共通の webhook 受信リスナーと設定したルートを起動します。Telegram や WhatsApp Cloud 固有の webhook モードは別のリスナーで、このスイッチでは起動しません。`WEBHOOK_SECRET` またはルートごとのシークレットを `env` / `extraEnvFrom` に指定してください。上流の [webhook ガイド](https://hermes-agent.nousresearch.com/docs/user-guide/messaging/webhooks)を参照してください。

実行時の設定だけではポートは公開されません。従来の dashboard 専用 Service には `service.ports: []` を維持し、それ以外では全 Service ポートを明示します。[`values-api-server-and-webhook.yaml`](values-api-server-and-webhook.yaml) は API サーバーと webhook のポートを公開し、必須の認証情報を外部 Secret から参照する例です。

バージョン別のポート、バインド、認証とチャートの接続方法は[公開リスナー一覧（英語）](https://jyje.github.io/hermes-agent-helm/advanced/integrations/listeners/)を参照してください。[`values-telegram-webhook.yaml`](values-telegram-webhook.yaml) は Telegram 固有の受信リスナー、Service、TLS Ingress を明示的に接続します。通常のポーリングは外向き接続なので、これらは不要です。

### A2A（Agent-to-Agent）リスナー

A2A には専用のチャート値や有効化用の環境変数がありません。上流の有効化設定は `config.yaml` の `gateway.platforms.a2a` ブロックなので、既存の自由形式 `config:` パススルーで設定します。

```yaml
config:
  gateway:
    platforms:
      a2a:
        enabled: true
        extra:
          port: 9900
extraEnv:
  - name: A2A_HOST      # upstream defaults to 127.0.0.1; widen for a Service
    value: "0.0.0.0"
  - name: A2A_PORT
    value: "9900"
```

Service 経由でリスナーを公開するには、外部 Secret に `A2A_PEER_TOKENS`（例: `agent-a:<token>`）を設定し、`A2A_TRUSTED_PEERS` に対応するピア名を列挙します。クライアントは Bearer ヘッダーにトークンだけを送ります。トークンはループバック以外へのバインドと認証に使われ、許可リストがタスク送信を許可します。許可リストがなければ、認証に成功してもタスク送信はデフォルトで拒否されます。共有の `A2A_BEARER_TOKEN` を使う場合、ピアは名前ではなく `ip:<source-ip>` で識別されます。[A2A ガイド](https://hermes-agent.nousresearch.com/docs/user-guide/messaging/a2a)と、許可リスト、外部 Secret、Service ポートを組み合わせた [`values-a2a.yaml`](values-a2a.yaml) を参照してください。

以前の共有トークンの例を使用していた場合は、この設定を適用する前に既存の Secret にピア別トークンを追加し、クライアントも各ピアのトークンを使うように変更してください。コールバック受信側が通知の署名を検証する場合は、Secret に `A2A_PUSH_SECRET` を設定し、受信側にも同じ署名キーを設定します。別途設定しないまま共有トークンを削除すると、デフォルトのコールバック署名キーも失われます。

**Hermes v0.23.2 以降のプッシュコールバック。** コールバック URL は通知の送信先で、受信用の A2A Service とは別です。デフォルトの URL ポリシーは、プライベート IP に解決される宛先を拒否します。プライベート IP を使うクラスター内部の Kubernetes Service DNS 名も対象です。コールバックの送信時にリダイレクトを追わないため、最終 URL を直接指定してください。エージェントから受信先に接続でき、URL ポリシーで許可されることを確認してください。[上流のコールバックテスト](https://github.com/NousResearch/hermes-agent/blob/v0.23.2/tests/plugins/test_a2a_callback_ssrf.py)を参照してください。

### HTTP ルーティング: Ingress または HTTPRoute

どちらもデフォルトでは無効です。Ingress コントローラーがある場合は `ingress`、Gateway API CRD と `parentRefs` で参照できる Gateway がある場合は `httpRoute` を使用します。同じホストとパスに両方を有効にせず、クラスターで運用する API を選択してください。

各 Ingress パスは `service` と `port` を上書きできます。Service 名を省略するとこのチャートの Service を指すため、`service.enabled: true` が必要です。外部 Service 名を明示する場合はチャートの Service は不要です。HTTPRoute の `backendRefs` にも同じ既定値の規則が適用されます。暗黙の参照先となるチャートの Service が存在しない場合、チャートは早期に失敗します。

`ingress.annotations` と `httpRoute.annotations` は、external-dns のヒントや、コントローラーまたは Gateway 実装固有の設定など、各リソースにメタデータを追加します。

[`values-ingress-listeners.yaml`](values-ingress-listeners.yaml) は `/v1` と webhook を異なる Ingress ホストと Service ポートに振り分けます。[`values-httproute.yaml`](values-httproute.yaml) は Gateway API での同等の例です。HTTPRoute のホスト名はリソース内の全ルールに適用されるため、リスナー間をホスト単位で分離する場合は HTTPRoute を分けてください。

### Pod Security Standards による強化

`podSecurityContext` / `securityContext` は互換性のためデフォルトでは空ですが、固定したイメージで非 root と読み取り専用 rootfs の動作を CI 検証しています。s6-overlay は自身で非 root uid に切り替え、`/run` と `/tmp` を書き込み・実行可能な tmpfs としてマウントすれば起動します。`/run` には起動時に実行する s6 の初期化バイナリがあります。[`values-hardened.yaml`](values-hardened.yaml) は PSS `restricted` 準拠の例で、`pod-security.kubernetes.io/enforce=restricted` を設定した名前空間へインストールします。

2 つの init コンテナーには Pod やメインコンテナーとは別の securityContext が必要です。`auth.deviceFlow.securityContext` はデフォルトでは空でログインイメージのユーザーを継承し、指定 uid がトークン保存先を所有していれば非 root で動作します。`values-hardened.yaml` は `tokenOwner` と一致する設定例です。`team.sharedVolume.permissions` の所有権準備コンテナーは任意のストレージで `chown` するため root が必要で、非 root モードはありません。`restricted` では `permissions.enabled` を無効にし、ストレージが対応する場合は `podSecurityContext.fsGroup` を使ってください。

## ゲートウェイのライフサイクル: ロールアウト、停止、ドレイン

イメージ `v2026.7.1` 以降、`agent.restart_drain_timeout` のデフォルトは **0** です。Pod 停止時（ロールアウト、ノードドレイン、`kubectl delete pod`）は実行中のエージェント処理を即座に中断し、会話記録を保存して終了します。標準ではロールアウトが速く、Kubernetes のデフォルトの終了猶予 30 秒で十分です。

実行中のターンの完了を待ってから中断する場合は、Hermes のドレイン時間と Pod の終了猶予時間の両方を指定します。

```yaml
config:
  agent:
    restart_drain_timeout: 60    # seconds to wait for in-flight runs
terminationGracePeriodSeconds: 90 # keep WELL ABOVE the drain timeout
```

終了猶予がドレイン時間より十分に長くないと、kubelet がドレイン中に SIGKILL を送ります。上流は systemd の `TimeoutStopSec` との同様の競合で古いロックが残り、クラッシュループになると説明しており、これがデフォルトを 0 にした理由です。無期限に続くターンの完了を保証する機能ではありません。

> **クラスター内では scale-to-zero は使えません。** 上流 `v2026.7.1` のアイドル検出（dormant-quiesce）は Nous のマネージド relay 専用です。ユーザー設定ではなくプラットフォームが付与する `HERMES_SCALE_TO_ZERO` で有効になり、relay のみの接続と登録済みの wake URL が必要で、ホスティング基盤による VM の休止に依存します。このチャートの直接の Discord/Telegram/Slack 接続では作動せず、Kubernetes は Pod を Running のまま維持するため公開していません。

## 無人実行時の承認

ゲートウェイ Pod には **TTY がない**ため、危険な `terminal` / `execute_code` コマンドの対話的な承認要求に応答できず、実行が止まることがあります。`config.approvals` で設定します。

```yaml
config:
  approvals:
    mode: manual        # "manual" (default) prompts; the gateway has nobody to answer
    deny:                # commands matching these patterns are refused BEFORE
      - "rm -rf /"       # any approval/yolo logic even sees them: safe to keep
      - "curl.*\\|.*sh"  # even in yolo mode
    cron_mode: deny       # unattended cron runs: "deny" (default) or "approve"
    unattended_mode: deny # API server / webhook sessions: "deny" (default) or "approve"
    single_query_mode: deny  # one-shot `hermes chat -q` runs: same choice
    discord_prompt_timeout: 120  # seconds a Discord button prompt stays live
                                 # (clamped upstream; default 300s / 5 min)
```

`cron_mode`、`unattended_mode`、`single_query_mode` は、それぞれ cron、`apiServer` / `webhook` 経由のセッション、単発の `-q` 実行を対象とします。デフォルトはすべて `deny` で、危険なコマンドの承認要求が発生すると待機せず直ちに拒否し、エージェントに別の方法を探させます。`approve` はその実行状況の要求をすべて自動承認します。Discord や Telegram など人間が応答できるプラットフォームには適用されず、各プラットフォームのタイムアウト付き対話承認を使用します。

コマンド承認とは別に、エージェント自身の指示ファイル（`AGENTS.md`、`SOUL.md`、スキル、メモリストア）への書き込みは必ず承認を求めます。人間へ確認する経路がなければ拒否され、yolo による回避もありません。これは上流の `security.protected_instruction_files` で、標準で有効です。自己改善のスキル書き込みも、黙って実行されずチャットで承認を求めます。

`approvals.deny` は特定の危険なパターンをほかの承認モードに関係なく拒否するリストであり、完全なポリシーではありません。これだけでゲートウェイが非対話的になるわけではなく、許容するリスクに応じた `HERMES_YOLO_MODE` や承認モードと組み合わせます。詳細は上流の[セキュリティガイド](https://hermes-agent.nousresearch.com/docs/user-guide/security)を参照してください。

## 環境変数

ここでは開始に必要な[プロバイダー](#インストール設定-llm-プロバイダー)と[メッセンジャー](#メッセンジャー連携telegram--discord)の変数を説明しています。Hermes が読むほかの変数も、シークレットは `.Values.env`（Secret）、非機密値は `.Values.extraEnv`（通常の環境変数）、外部管理の Secret は `extraEnvFrom` で指定できます。[設定モデル](#設定モデル)を参照してください。

各 Hermes リリースに合わせて更新される完全な一覧は、**[環境変数リファレンス](https://hermes-agent.nousresearch.com/docs/reference/environment-variables)**を参照してください。

イメージ `v0.22.2` 時点でよく使われる追加の変数:

| 変数 | 用途 |
| --- | --- |
| `DEEPSEEK_API_KEY` | DeepSeek プロバイダー |
| `ZAI_API_KEY` | Z.AI / GLM プロバイダー（組み込みキー `zai`。`GLM_BASE_URL` で Global/China/Coding-Plan のエンドポイントを選択） |
| `MODEL_API_KEY` | Meta Model API（Muse Spark）プロバイダー（組み込みキー `meta-ai`。`META_API_KEY` も別名として利用可能。`META_BASE_URL` でエンドポイントを上書き） |
| `NEBIUS_API_KEY` / `NEBIUS_BASE_URL` | Nebius Token Factory プロバイダー（`nebius-token-factory`）と任意のエンドポイント上書き |
| `RAMP_ROUTER_API_KEY` / `RAMP_ROUTER_BASE_URL` | Ramp Router プロバイダー（`router`）と任意のエンドポイント上書き |
| `TOKENPLAN_API_KEY` / `TOKENPLAN_BASE_URL` | Tencent TokenPlan プロバイダー（`tencent-tokenplan`、Anthropic Messages エンドポイント）と任意のエンドポイント上書き |
| `AZURE_FOUNDRY_API_KEY` | Microsoft Foundry / Azure OpenAI プロバイダー |
| `HERMES_WRITE_SAFE_ROOT` | `write_file` / `patch` を指定ルートディレクトリに制限（複数の場合は OS のパス区切り文字） |
| `SLACK_BOT_TOKEN` / `SLACK_APP_TOKEN` | Slack ボット（Socket Mode） |
| `MATRIX_HOMESERVER` / `MATRIX_ACCESS_TOKEN` | Matrix ホームサーバー連携 |
| `WHATSAPP_CLOUD_PHONE_NUMBER_ID` / `WHATSAPP_CLOUD_ACCESS_TOKEN` | WhatsApp Cloud API |
| `HERMES_DASHBOARD_BASIC_AUTH_USERNAME` / `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` | ループバック以外で必須となる dashboard の組み込みユーザー名・パスワード認証。`HERMES_DASHBOARD_PUBLIC_URL` は Ingress の背後の外部オリジンを宣言 |
| `HERMES_MAX_ITERATIONS` | 会話ごとのツール呼び出し反復数（デフォルト 500 回と終了処理 1 回）。厳密な上限は `config.agent.max_turns`。上流では標準で無制限で、このチャートでは初期配置しない |
| `HERMES_AGENT_TIMEOUT` | ゲートウェイの無活動タイムアウト（デフォルト 1800 秒 / 30 分） |
| `HERMES_TIMEZONE` | IANA タイムゾーンの上書き |

> **環境変数では設定できない項目:** コンテキスト圧縮、フォールバックプロバイダー、プロバイダールーティングは `.Values.config` の `config.yaml` でのみ設定します。対応する環境変数はありません。

## アップグレードノート

### キー不要の Nous サンプルの廃止

`values-nous.yaml` オーバーレイを削除しました。Hermes v0.22 では
`HERMES_GUEST_ONBOARDING` が削除され、無料の `nous/welcome` による
オンボーディングはデスクトップ専用になりました。このオーバーレイでは
キー不要のゲートウェイを起動できません。
[公式 v0.22.0 リリースノート](https://github.com/NousResearch/hermes-agent/releases/tag/v0.22.0)を参照してください。

デプロイ設定から古いオーバーレイと環境変数を削除し、
[OpenAI](values-openai.yaml) や [OpenRouter](values-openrouter.yaml) などの
サンプルを選び、自分の認証情報を設定してください。
`bootstrap.overwrite: false` の既存ボリュームでは `config.yaml` が保持されるため、
保存されたプロバイダー・モデル設定も更新するか、バックアップ後に意図的に
再シードしてください（[設定モデル](#設定モデル)参照）。
廃止するのは匿名利用のサンプルであり、上流の認証済み Nous サポートではありません。

### Hermes v0.23.2

**Basic 認証を使っている場合は、再度ログインしてください。** Hermes v0.23.1 以前からアップグレードすると、ダッシュボードと Webapp の既存のパスワード認証セッションは無効になります。同じ認証情報で再度ログインしてください。Secret のローテーションや PVC の初期化は不要です。OAuth と OIDC には適用されません。[上流の Basic 認証コード](https://github.com/NousResearch/hermes-agent/blob/v0.23.2/plugins/dashboard_auth/basic/__init__.py#L139-L185)を参照してください。

### Hermes v0.23.0

- **セッションの自動削除はオプトインです。** `v0.23.0` イメージでは `sessions.auto_prune` のデフォルトは `false` です。アップグレード前に PVC 上の `config.yaml` を確認してください。明示的に `true` を設定している場合は自動削除が続きます。デフォルトの `bootstrap.overwrite: false` では、Helm の値を変更しても既存ファイルは置き換わりません。未設定の場合、ディスクの空き容量が少なくなると Hermes が確認を求めることがあり、有効または無効を選ぶと `config.yaml` に保存されます。
- **ブラウザー自動化には `browser_exec` を使います。** 削除された `agent-browser` CLI や `browser_navigate`、`browser_click` などを参照するプロンプト、スキル、ツール一覧を更新してください。
- **MCP サーバーはプラグインに移動しました。** Hermes をサーバーとして起動する MCP クライアントのコマンドを `hermes mcp serve` から `hermes mcp-serve` に変更してください。
- **Webapp はデフォルトで無効です。** リスナーを使うには `webapp.enabled` を明示的に有効にしてください。

[公式 v0.23.0 アップグレードノート](https://github.com/NousResearch/hermes-agent/releases/tag/v0.23.0#-upgrade-notes)と[タグのセッションデフォルト](https://github.com/NousResearch/hermes-agent/blob/v0.23.0/hermes_cli/config_defaults.py#L2257)を参照してください。

### Hermes v0.22（チャート 1.20.0）

> **v0.22.1 を実行した場合:** 上流は、このリリースが誤ったコミットから作られ、
> そのゲートウェイで使ったセッションを v0.22.2 では削除できないと明記しています。
> バージョン変更前に Hermes のボリュームをバックアップしてください。
> 明示的な `image.tag` の上書きを含め、v0.22.1 を実行した環境の制限です。
> v0.22.2 の新規インストールや v0.22.1 を経由しない直接アップグレードを指しません。
> チャートのデフォルト v0.22.2 を維持し、v0.22.1 は選ばないでください。
> 安全なロールバックや手動 DB 修復手順は確認されていません。
> 回避のために `state.db` を削除しないでください。
> [公式 v0.22.2 の訂正と既知の問題](https://github.com/NousResearch/hermes-agent/releases/tag/v0.22.2)を参照してください。

チャート 1.20.0 はデフォルトイメージを `v2026.9.24`（Hermes v0.21.5）から `v0.22.2` に更新します。チャートの values とテンプレートは変わりませんが、Hermes 自体のデフォルトの一部が永続ボリューム上のデータに影響します。履歴のあるリリースをアップグレードする前に確認してください。

- **v0.22.2 では古いセッションが起動時にデフォルトで削除されます。** このイメージでは gateway の起動時に `sessions.retention_days`（デフォルト 90 日）以上操作のない終了済みセッションが `state.db` から削除されます。開いているセッションは対象外です。すべて残すには、アップグレード前に設定してください。

  ```yaml
  config:
    sessions:
      auto_prune: false
  ```

  デフォルトの `bootstrap.overwrite: false` では、ボリューム上の既存の `config.yaml` は置き換えられないため、この値は新規インストールにのみ反映されます。既存のリリースでは、アップグレード前に `kubectl exec <pod> -- hermes config set sessions.auto_prune false` を実行するか、`bootstrap.overwrite: true` で一度デプロイしてください（[設定モデル](#設定モデル)を参照）。
- **アイドル／日次のセッションリセットは廃止されました。** 会話がタイマーでリセットされることはなくなり、`SESSION_IDLE_MINUTES` と `session_reset` の idle/daily モードは効果がありません（設定が残っていると警告が記録されます）。新しく始めるには会話で `/new` または `/reset` を使ってください。
- **1 つの gateway がすべてのプロファイルを処理します。** upstream はプロファイルごとの gateway をマシンごとに 1 つの multiplexed gateway にまとめます。チャートのリリースはそれぞれ gateway を 1 つ持つ別の Pod なので、[エージェントチーム](#エージェントチーム)のデプロイには影響しません。
- **イメージタグは semver です。** 今後 `image.tag` は `vX.Y.Z` 形式で固定してください（[概要](#概要)を参照）。
- **セキュリティ修正。** 新しいイメージには v0.21.6 の dashboard 認証強化が含まれています。[ダッシュボードを公開](#ダッシュボードの公開)している場合は早めにアップグレードしてください。

その他の変更は upstream の [v0.22.0 リリースノート](https://github.com/NousResearch/hermes-agent/releases/tag/v0.22.0)を参照してください。

## FAQ

**この README にない Hermes の設定を変更するには？**

ここではインストール時の基本設定を説明しています。それ以外は次の手順で設定します。

1. 公式の[設定ガイド](https://hermes-agent.nousresearch.com/docs/user-guide/configuration)（`config.yaml`）または[環境変数リファレンス](https://hermes-agent.nousresearch.com/docs/reference/environment-variables)で目的の項目を探します。
2. `foo.bar: baz` などの設定なら values ファイルの `.Values.config.foo.bar` または `--set-string config.foo.bar=baz` で指定します。`SOME_TOKEN` などの環境変数なら `.Values.env.SOME_TOKEN`（機密）または `.Values.extraEnv`（非機密）に指定します。
3. `helm upgrade` 後、`kubectl exec <pod> -- hermes doctor` または `helm test` で確認します。

Hermes が対応する設定にはチャート変更は不要です。[パススルーの原則](#設定モデル)を参照してください。チャートの `values.yaml` やサンプルは、プロバイダー全体の設定、ボットのループ防止変数、チーム構成など、出発点となるテンプレートが有用な場合に提供します。

**上流のリリースノートにある機能が `values.yaml` の新しいキーにならないのはなぜ？**

上流の多くの設定追加は既存のパススルーで利用できます。例として [#45](https://github.com/jyje/hermes-agent-helm/issues/45)、[#46](https://github.com/jyje/hermes-agent-helm/issues/46)、[#48](https://github.com/jyje/hermes-agent-helm/issues/48) を参照してください。`values-*.yaml` は新しいプロバイダーやシークレット取得元など、コピーできる出発点が役立つ複雑な設定に対して追加します。

## 追加サンプル

小規模・家庭用クラスター（Raspberry Pi / arm64 k3s など）向けに、編集して使える `-f` オーバーレイを提供します。認証情報は**ダミーのプレースホルダーまたは外部 Secret への参照**です。インストール時に `--set-string` で上書きするか、前述の SealedSecret と `extraEnvFrom` を使ってください。各ファイル冒頭にコマンド例があります。

| ファイル | モデルプロバイダー | 追加機能 |
| --- | --- | --- |
| [`values-nvidia-nim-and-discord.yaml`](values-nvidia-nim-and-discord.yaml) | NVIDIA NIM | **Discord ボット**を設定済み |
| [`values-nvidia-nim-and-buzz.yaml`](values-nvidia-nim-and-buzz.yaml) | NVIDIA NIM | **Buzz ボット**を設定済み（Block の Nostr ベースの人間・エージェント向けプラットフォーム） |
| [`values-github-copilot.yaml`](values-github-copilot.yaml) | GitHub Copilot (`copilot`) | **OAuth デバイスフローログイン**と Discord ボット |
| [`values-openai-codex.yaml`](values-openai-codex.yaml) | OpenAI Codex (`openai-codex`) | **ChatGPT/Codex デバイスログイン**と Discord ボット |
| [`values-anthropic-and-discord.yaml`](values-anthropic-and-discord.yaml) | Anthropic (Claude) | **Discord ボット**を設定済み |
| [`values-openai-and-telegram.yaml`](values-openai-and-telegram.yaml) | OpenAI (`openai-api`) | **Telegram ボット**を設定済み |
| [`values-telegram-team-assistant.yaml`](values-telegram-team-assistant.yaml) | OpenAI (`openai-api`) | **許可された複数のユーザーで共有する Telegram ボット 1 つ** |
| [`values-telegram-team-leader.yaml`](values-telegram-team-leader.yaml) + [`values-telegram-team-member.yaml`](values-telegram-team-member.yaml) | NVIDIA NIM | **Telegram のリーダー/メンバーチーム**。メンションによる制御とループ防止付き |
| [`examples/argocd/hermes-team-telegram.yaml`](../../examples/argocd/hermes-team-telegram.yaml) | 任意 | **ArgoCD ApplicationSet**: リーダー 1 つと複数の Telegram メンバー、リリースごとの Secret |
| [`values-google-chat.yaml`](values-google-chat.yaml) | OpenAI (`openai-api`) | Pub/Sub pull サブスクリプションで **Google Chat ボット**を設定済み。サービスアカウント JSON は `extraVolumes` でマウント |
| [`values-openai.yaml`](values-openai.yaml) | OpenAI (`openai-api`) | : |
| [`values-anthropic.yaml`](values-anthropic.yaml) | Anthropic (Claude) | : |
| [`values-gemini.yaml`](values-gemini.yaml) | Google Gemini | : |
| [`values-google-vertex.yaml`](values-google-vertex.yaml) | Google Vertex AI (`vertex`) | `extraVolumes` で**サービスアカウント JSON をマウント**（静的 API キー不要） |
| [`values-openrouter.yaml`](values-openrouter.yaml) | OpenRouter | : |
| [`values-fireworks.yaml`](values-fireworks.yaml) | Fireworks AI | Fireworks ネイティブのモデル ID |
| [`values-deepinfra.yaml`](values-deepinfra.yaml) | DeepInfra | `DEEPINFRA_BASE_URL` でエンドポイントを上書き |
| [`values-upstage.yaml`](values-upstage.yaml) | Upstage Solar | `UPSTAGE_BASE_URL` でエンドポイントを上書き |
| [`values-moa.yaml`](values-moa.yaml) | Mixture-of-Agents (`moa`) | 参照モデルを並列実行し、集約モデルが結果を統合 |
| [`values-bitwarden.yaml`](values-bitwarden.yaml) | 任意 | **Bitwarden Secrets Manager** が起動時にプロバイダーキーを供給 |
| [`values-litellm.yaml`](values-litellm.yaml) | LiteLLM プロキシ（外部/Ingress） | : |
| [`values-litellm-k8s.yaml`](values-litellm-k8s.yaml) | LiteLLM プロキシ（クラスター内 Service DNS） | : |
| [`values-ingress.yaml`](values-ingress.yaml) | OpenAI (`openai-api`) | **Dashboard Ingress**（dashboard 有効化、上流のパスワード認証、信頼するプロキシ） |
| [`values-webapp.yaml`](values-webapp.yaml) | OpenAI (`openai-api`) | **Webapp**: 内部 ClusterIP、外部パスワード Secret、ローカルポート転送 |
| [`values-ingress-oauth.yaml`](values-ingress-oauth.yaml) | OpenAI (`openai-api`) | **Nous Portal OAuth を使うダッシュボード Ingress**。インターネットに公開するダッシュボードに上流が推奨するログイン方式 |
| [`values-ingress-oidc.yaml`](values-ingress-oidc.yaml) | OpenAI (`openai-api`) | **独自の OpenID Connect プロバイダーを使うダッシュボード Ingress**（public PKCE クライアント、Nous Portal 不要） |
| [`values-api-server-and-webhook.yaml`](values-api-server-and-webhook.yaml) | OpenAI (`openai-api`) | **API サーバーと webhook**。明示的な Service ポートと外部 Secret |
| [`values-telegram-webhook.yaml`](values-telegram-webhook.yaml) | OpenAI (`openai-api`) | **Telegram 固有の webhook**: 受信リスナー、Service ポート、TLS Ingress、外部 Secret を明示 |
| [`values-a2a.yaml`](values-a2a.yaml) | OpenAI (`openai-api`) | **A2A（Agent-to-Agent）**。config.yaml パススルーと明示的な Service ポートで、ほかの A2A エージェントから検出・操作可能 |
| [`values-ingress-listeners.yaml`](values-ingress-listeners.yaml) | OpenAI (`openai-api`) | **Ingress のリスナールーティング**: `/v1` API と webhook のホストを別の Service ポートへ接続 |
| [`values-httproute.yaml`](values-httproute.yaml) | OpenAI (`openai-api`) | **Gateway API HTTPRoute**: 既存の Gateway を経由するリスナールーティング |
| [`values-networkpolicy-litellm.yaml`](values-networkpolicy-litellm.yaml) | LiteLLM プロキシ（クラスター内） | **外向き通信を制限する NetworkPolicy**: RFC1918 とクラウドのメタデータエンドポイントを遮断し、LiteLLM Service だけを明示的に許可 |
| [`values-networkpolicy-dashboard.yaml`](values-networkpolicy-dashboard.yaml) | OpenAI (`openai-api`) | **NetworkPolicy を有効にしたダッシュボード Ingress**: ポート 9119 の受信ルールと対応する信頼するプロキシ。Calico VXLAN 上のホストネットワークのコントローラーで実測 |
| [`values-hardened.yaml`](values-hardened.yaml) | OpenAI (`openai-api`) | **PSS `restricted`**: 非 root、読み取り専用 rootfs、ケーパビリティ削除。`restricted` 強制の名前空間で CI 検証済み |
| [`values-soul.yaml`](values-soul.yaml) | 任意 | **永続的なアイデンティティ**: 実践的なエンジニアリング方針と実行時の編集保持 |
| [`values-multi-agent-collab.yaml`](values-multi-agent-collab.yaml) | 任意 | **連携するペア**: 共有 Discord チャンネルで @mention によって引き継ぐ 2 体のエージェント |
| [`values-team-leader.yaml`](values-team-leader.yaml) + [`values-team-member.yaml`](values-team-member.yaml) | NVIDIA NIM（ほかも利用可能） | **リーダー主導のチーム**: 明示的なボット @mention を直列化し、RWX 知識 PVC はリーダーが書き込み、メンバーは読み取り専用。ファイルによるタスク引き継ぎなし。[チーム](../../docs/advanced/teams/reference.md)参照 |
| [`values-shared-knowledge.yaml`](values-shared-knowledge.yaml) | Anthropic (Claude) | **共有 RWX PVC**: 複数エージェントで同じ知識ベースを読み書き |

ArgoCD でデプロイする場合は [`examples/argocd/`](../../examples/argocd/) を参照してください。各サンプルの Application マニフェストと `extraEnvFrom` によるシークレット設定を提供しています。

## Values

| Key | Type | Description | Default |
|-----|------|-------------|---------|
| affinity | object | Affinity rules for Pod scheduling. | `{}` |
| apiServer.corsOrigins | string | Comma-separated browser origins allowed to call the API directly. Empty    disables browser CORS access. | `""` |
| apiServer.enabled | bool | Enable Hermes' OpenAI-compatible HTTP API server. | `false` |
| apiServer.host | string | Bind address. Upstream defaults to 127.0.0.1; a Kubernetes Service needs    a non-loopback address. API_SERVER_KEY is still required on loopback. | `"0.0.0.0"` |
| apiServer.port | int | API server port. | `8642` |
| args | list | Arguments passed through the image entrypoint. `gateway run` selects the    non-interactive outbound messaging service instead of the default TUI. | `["gateway","run"]` |
| auth | object | ------------------------------------------------------------------------- | `{"deviceFlow":{"enabled":false,"forceRelogin":false,"image":{"repository":"python","tag":"3.14-slim"},"notify":"discord","provider":"github-copilot","providers":{"github-copilot":{"authHost":"github.com","clientId":"Ov23li8tweQw6odWQebz","flow":"github","scope":"read:user","tokenEnv":"COPILOT_GITHUB_TOKEN","validateUrl":"https://api.github.com/user"},"openai-codex":{"flow":"openai-codex","issuer":"https://auth.openai.com"}},"resources":{},"securityContext":{},"timeoutSeconds":870,"tokenOwner":{"gid":10000,"uid":10000}}}` |
| auth.deviceFlow.enabled | bool | Bootstrap a provider credential via the OAuth device flow at startup.    When false, the agent uses the static key from `env`/`extraEnvFrom`. | `false` |
| auth.deviceFlow.forceRelogin | bool | Force a fresh login even if a token already exists on the volume. | `false` |
| auth.deviceFlow.image | object | Login image for GitHub-style profiles. OpenAI Codex uses the pinned    Hermes image so auth.json persistence and refresh stay version-aligned. | `{"repository":"python","tag":"3.14-slim"}` |
| auth.deviceFlow.notify | string | Where to deliver the verification URL + user code for human approval.    `discord` reuses the agent's bot creds (DISCORD_BOT_TOKEN +    DISCORD_HOME_CHANNEL from `env`/`extraEnvFrom`); `telegram` reuses    TELEGRAM_BOT_TOKEN + TELEGRAM_HOME_CHANNEL the same way. The code is    always also printed to the init container logs as a fallback. | `"discord"` |
| auth.deviceFlow.provider | string | Which provider profile to authenticate. Must be a key under    `providers` below. Only one device-flow login runs at a time. | `"github-copilot"` |
| auth.deviceFlow.providers.github-copilot.authHost | string | Host serving the device-code + token endpoints (GitHub-style paths). | `"github.com"` |
| auth.deviceFlow.providers.github-copilot.clientId | string | OAuth client id for the device grant. The shared opencode/Copilot-CLI    client used by the upstream GitHub Copilot provider. | `"Ov23li8tweQw6odWQebz"` |
| auth.deviceFlow.providers.github-copilot.flow | string | Login protocol handler. | `"github"` |
| auth.deviceFlow.providers.github-copilot.scope | string | OAuth scope requested in the device grant. | `"read:user"` |
| auth.deviceFlow.providers.github-copilot.tokenEnv | string | .env key Hermes reads this provider's token from (resolution order    COPILOT_GITHUB_TOKEN > GH_TOKEN > GITHUB_TOKEN). | `"COPILOT_GITHUB_TOKEN"` |
| auth.deviceFlow.providers.github-copilot.validateUrl | string | Optional endpoint to verify an existing token is still live; on    401/403 the init container re-runs the login. Empty = skip the check.    `/user` answers 401 for a revoked token and does not depend on the    Copilot plan. The old `copilot_internal/v2/token` exchange endpoint    returned 403 for a valid token on a Copilot Free account, which made    every restart ask for a new login. | `"https://api.github.com/user"` |
| auth.deviceFlow.providers.openai-codex.flow | string | Use the OpenAI Codex device-code flow bundled with the pinned    Hermes version and persist refreshable credentials in auth.json. | `"openai-codex"` |
| auth.deviceFlow.providers.openai-codex.issuer | string | OpenAI account issuer. Override only for a compatible test server. | `"https://auth.openai.com"` |
| auth.deviceFlow.resources | object | Resources for the login init container. | `{}` |
| auth.deviceFlow.securityContext | object | securityContext for the device-login init container. Empty by    default - inherits the image's own user (root for the Python image,    the pinned Hermes image otherwise). Overriding to a non-root uid only    works if that uid can already write the token's destination path;    see values-hardened.yaml for a verified non-root override (uid/gid    matching tokenOwner, so the chown above becomes a same-uid no-op). | `{}` |
| auth.deviceFlow.timeoutSeconds | int | Seconds to wait for the human to authorize before the init container    fails (and retries). Keep below the provider's device-code validity. | `870` |
| auth.deviceFlow.tokenOwner | object | uid/gid that should own the written token file. By default this init    container inherits the login image's own user (root for the Python    image below) so it can write to any storage class reliably, then    chowns the token to this owner. Set it to the Hermes runtime uid; the    upstream image's s6-overlay runs the agent as uid/gid 10000: so the    non-root agent can read the credential. | `{"gid":10000,"uid":10000}` |
| bootstrap.enabled | bool | Seed chart-managed files into HERMES_HOME via an init container. | `true` |
| bootstrap.overwrite | bool | false: seed config.yaml and configured SOUL.md only if absent, preserving    runtime edits across upgrades. Set true to replace both files with chart    content on every deploy. | `false` |
| command | list | Container command override. Empty keeps the Hermes image entrypoint, which    starts the s6-supervised outbound messaging gateway and prepares volume    ownership before dropping privileges. Set only for explicit debugging. | `[]` |
| config | object | ------------------------------------------------------------------------- | `{"agent":{"gateway_timeout":1800},"model":{"default":"gpt-4o-mini","provider":"openai-api"},"providers":{},"terminal":{"backend":"local"}}` |
| configMapAnnotations | object | Annotations to add to every ConfigMap the chart renders (config, login    script, team skill), for example Argo CD sync waves. | `{}` |
| controller | object | ------------------------------------------------------------------------- | `{"type":"deployment"}` |
| controller.type | string | Workload kind: "deployment" or "statefulset". | `"deployment"` |
| dashboard | object | ------------------------------------------------------------------------- | `{"auth":{"provider":"basic"},"enabled":false,"publicUrl":"","readinessProbe":{"enabled":true,"periodSeconds":10},"trustedProxies":[]}` |
| dashboard.auth.provider | string | Upstream auth provider the credentials below are for. The template    fails when the provider's required keys are missing from `env` or    `extraEnv`: `basic` (HERMES_DASHBOARD_BASIC_AUTH_USERNAME + _PASSWORD    or _PASSWORD_HASH), `oauth` (HERMES_DASHBOARD_OAUTH_CLIENT_ID) or    `oidc` (HERMES_DASHBOARD_OIDC_ISSUER + _CLIENT_ID). Use `external`    when credentials arrive through `extraEnvFrom` or an ExternalSecret,    which the chart cannot inspect. | `"basic"` |
| dashboard.enabled | bool | Start the supervised management dashboard (renders `HERMES_DASHBOARD=1`).    Exposing it also needs `service.enabled` plus an `ingress` or `httpRoute`.    `public_url` and `trusted_proxies` are written into `config.yaml` when the    volume is first seeded, so changing the host or `dashboard.*` later needs    `--set bootstrap.overwrite=true` for that upgrade (see the README, "Expose the    dashboard"). | `false` |
| dashboard.publicUrl | string | External origin the dashboard is reached at, for example    `https://hermes.example.com`. Feeds `config.dashboard.public_url`. When    empty and `ingress.enabled`, it is derived from the first Ingress host    (`https` when `ingress.tls` is set). Set it explicitly for an HTTPRoute.    A value already set under `config.dashboard` wins. | `""` |
| dashboard.readinessProbe.enabled | bool | Render a TCP readiness probe on `service.port` while the dashboard is    enabled, so the pod only joins the Service once the dashboard    listens. The first start can take minutes (bundled skills sync onto    the volume), during which an Ingress would otherwise answer 502. An    explicit `probes.readiness` wins. Readiness never restarts the pod. | `true` |
| dashboard.readinessProbe.periodSeconds | int | Seconds between readiness checks. | `10` |
| dashboard.trustedProxies | list | Peers allowed to supply X-Forwarded-Proto / X-Forwarded-For, usually the    ingress controller's pod CIDR. Feeds `config.dashboard.trusted_proxies`;    upstream rejects unbounded entries such as 0.0.0.0/0. | `[]` |
| deploymentAnnotations | object | Annotations to add to the Deployment or StatefulSet object. | `{}` |
| env | object | ------------------------------------------------------------------------- | `{"OPENAI_API_KEY":"sk-REPLACE_ME"}` |
| externalSecret | object | ------------------------------------------------------------------------- | `{"annotations":{},"data":[],"dataFrom":[],"enabled":false,"refreshInterval":"1h","secretStoreRef":{"kind":"ClusterSecretStore","name":""},"target":{"creationPolicy":"Owner","deletionPolicy":"Retain","name":""}}` |
| externalSecret.annotations | object | Annotations to add to the ExternalSecret, for example an Argo CD sync wave    so the Secret exists before the workload starts. | `{}` |
| externalSecret.data | list | Individual remoteRef -> key mappings. See the External Secrets    Operator docs for the full field set. | `[]` |
| externalSecret.dataFrom | list | Bulk provider-native secret imports. See the External Secrets    Operator docs for the full field set. | `[]` |
| externalSecret.enabled | bool | Render an ExternalSecret instead of the chart's own env Secret.    Requires the External Secrets Operator CRDs to already be installed    in-cluster. | `false` |
| externalSecret.refreshInterval | string | How often ESO resyncs the target Secret from the provider. | `"1h"` |
| externalSecret.secretStoreRef | object | Which SecretStore/ClusterSecretStore to pull from. `name` is required    when enabled. | `{"kind":"ClusterSecretStore","name":""}` |
| externalSecret.target.name | string | Target Secret name. Empty defaults to the chart's own env Secret    name (`<fullname>-env`); when set, every chart-owned envFrom    reference uses this name instead. | `""` |
| extraContainers | list | Extra sidecar containers appended to the Pod's main `containers:` list.    Distinct from `extraInitContainers` (init phase only). Full container    spec; giving a sidecar its own resources and a PSS-compatible    securityContext is the operator's responsibility. | `[]` |
| extraEnv | list | Plain (non-secret) env vars injected directly on the container. | `[]` |
| extraEnvFrom | list | Extra envFrom sources (reference existing ConfigMaps/Secrets). | `[]` |
| extraInitContainers | list | Extra init containers, appended after the chart's own (seed-config,    device-flow login). Full container spec; combine with `extraVolumes` for    one-time preparation of a user-provided volume (for example, a shared    knowledge volume used independently of the Discord team handoff). | `[]` |
| extraResources | list | Extra raw manifests rendered as-is alongside this chart's resources.    Each entry is `tpl`-rendered, so `{{ .Release.Namespace }}` etc. work, and    may be either an object or a multiline string (see examples/argocd/).    Useful for things this chart doesn't model directly, e.g. a SealedSecret    that a sealed-secrets controller decrypts into a Secret referenced via    `extraEnvFrom` (see examples/argocd/). | `[]` |
| extraVolumeMounts | list | Extra volume mounts on the hermes-agent container (pairs with extraVolumes). | `[]` |
| extraVolumes | list | Extra volumes on the pod, for anything the agent needs as a FILE rather    than an env var: e.g. a Secret holding a service-account JSON    (see values-google-vertex.yaml). | `[]` |
| fullnameOverride | string | Fully override the generated resource name (release-name-chart). | `""` |
| httpRoute.annotations | object | Annotations to add to the HTTPRoute (e.g. external-dns, cert-manager,    or Gateway implementation-specific policies). | `{}` |
| httpRoute.enabled | bool | Create a Gateway API HTTPRoute. The cluster must already provide the    Gateway API CRD and a Gateway selected by `parentRefs`. | `false` |
| httpRoute.hostnames | list | HTTP hostnames accepted by this route. | `[]` |
| httpRoute.parentRefs | list | Gateway API parent references. | `[]` |
| httpRoute.rules | list | HTTPRoute rules. An empty backendRef name targets this chart's Service. | `[]` |
| image.pullPolicy | string | Image pull policy. | `"IfNotPresent"` |
| image.repository | string | Container image repository (multi-arch: amd64 + arm64). | `"nousresearch/hermes-agent"` |
| image.tag | string | Image tag. Upstream uses semver tags (e.g. "v0.22.2") since October 2026; older images use date-based tags (e.g. "v2026.9.24"). Empty defaults to `.Chart.AppVersion`. | `""` |
| imagePullSecrets | list | Image pull secrets for private registries. | `[]` |
| ingress.annotations | object | Annotations to add to the Ingress (e.g. auth, cert-manager, rewrite rules). | `{}` |
| ingress.className | string | IngressClass name (e.g. "nginx", "traefik"). Empty uses the cluster default. | `""` |
| ingress.enabled | bool | Create an Ingress resource. | `false` |
| ingress.hosts | list | Host/path rules. Each path defaults to this chart's Service and the    legacy dashboard port; override `service` and `port` per listener. | `[{"host":"hermes-agent.example.com","paths":[{"path":"/","pathType":"Prefix"}]}]` |
| ingress.tls | list | TLS configuration for the Ingress. | `[]` |
| nameOverride | string | Override the chart name used in resource names. | `""` |
| networkPolicy | object | ------------------------------------------------------------------------- | `{"allowDns":true,"annotations":{},"blockPrivateEgress":true,"dns":{"namespaceSelector":{"matchLabels":{"kubernetes.io/metadata.name":"kube-system"}},"podSelector":{"matchLabels":{"k8s-app":"kube-dns"}}},"enabled":false,"extraEgress":[],"extraIngress":[]}` |
| networkPolicy.allowDns | bool | Permit DNS lookups to kube-dns/CoreDNS. Required for the agent to    resolve any provider/messaging endpoint. | `true` |
| networkPolicy.annotations | object | Annotations to add to the NetworkPolicy. | `{}` |
| networkPolicy.blockPrivateEgress | bool | Block RFC1918 ranges and the cloud metadata endpoint (both IPv4    169.254.0.0/16 and its IPv6 equivalent within fd00::/8) while still    permitting public internet egress. Set false when the agent must    reach an in-cluster proxy such as LiteLLM - see    values-networkpolicy-litellm.yaml for a precise allowlist instead. | `true` |
| networkPolicy.dns.namespaceSelector | object | Kubernetes' immutable namespace-name label keeps this peer limited    to kube-system. Override both selectors for a distribution whose    DNS runs elsewhere. | `{"matchLabels":{"kubernetes.io/metadata.name":"kube-system"}}` |
| networkPolicy.enabled | bool | Create a NetworkPolicy isolating both directions. Ingress is denied    entirely by default - not an oversight: `hermes gateway run` is    outbound-only, so nothing needs to reach this Pod unless a listener    (dashboard, apiServer, webhook, a2a, ...) is exposed. Use    `extraIngress` in that case. | `false` |
| networkPolicy.extraEgress | list | Additional raw NetworkPolicy egress rules, appended as-is. | `[]` |
| networkPolicy.extraIngress | list | Additional raw NetworkPolicy ingress rules, appended as-is. Required    before enabling networkPolicy alongside any exposed listener. | `[]` |
| nodeSelector | object | Node selector for Pod scheduling. | `{}` |
| persistence | object | ------------------------------------------------------------------------- | `{"accessModes":["ReadWriteOnce"],"annotations":{},"enabled":true,"existingClaim":"","mountPath":"/opt/data","size":"5Gi","storageClass":""}` |
| persistence.annotations | object | Annotations to add to the PVC, or to the StatefulSet's volumeClaimTemplate    (for example backup tool hints or `helm.sh/resource-policy: keep`). They are    not applied to `existingClaim`. Kubernetes does not allow changing a    StatefulSet's volumeClaimTemplates, so set them at install time. | `{}` |
| persistence.existingClaim | string | Use an existing PVC instead of creating a new one. When specified, the chart will use this PVC and skip creating its own. | `""` |
| persistence.storageClass | string | StorageClass for the volumeClaimTemplate. Empty = cluster default. | `""` |
| podAnnotations | object | Annotations to add to the Pod. | `{}` |
| podLabels | object | Labels to add to the Pod. | `{}` |
| podSecurityContext | object | Pod-level securityContext. Left empty by default to stay compatible with the image's s6-overlay init (which starts as root and drops privileges itself). Non-root and read-only rootfs are both CI-verified to work; see values-hardened.yaml for a Pod Security Standards `restricted`-compliant overlay rather than hand-rolling this. | `{}` |
| probes | object | Health probes. Empty = none. The image's s6-overlay already supervises and auto-restarts the gateway in-container, so k8s probes are optional. Provide a full probe spec to enable, e.g. an exec check:   liveness:     exec: { command: ["hermes","gateway","status"] }     initialDelaySeconds: 30     periodSeconds: 30 | `{"liveness":{},"readiness":{},"startup":{}}` |
| probes.liveness | object | Liveness probe spec. Empty = no liveness probe. | `{}` |
| probes.readiness | object | Readiness probe spec. Empty = no readiness probe. | `{}` |
| probes.startup | object | Startup probe spec. Empty = no startup probe. Use this when first start takes longer than the liveness probe allows. | `{}` |
| readyNotify.enabled | bool | Seed the hook and enable it. Off by default. | `false` |
| readyNotify.notify | string | Where to post: `discord` (DISCORD_BOT_TOKEN + DISCORD_HOME_CHANNEL) or    `telegram` (TELEGRAM_BOT_TOKEN + TELEGRAM_HOME_CHANNEL). Required when    enabled, unless `auth.deviceFlow.enabled` is true: then empty follows    `auth.deviceFlow.notify`. | `""` |
| replicaCount | int | Set to 0 to prepare GitOps resources (Secret, ConfigMap, PVC, ...)    without starting an agent Pod, then scale to 1 after credentials and    optional device login are ready. The gateway and device-login init    container do not run while paused. Hermes Agent is a single-writer    workload bound to one HERMES_HOME (ReadWriteOnce PVC), so values above 1    are unsupported: Deployment replicas contend for the same volume and    StatefulSet replicas are disconnected agent identities. | `1` |
| resources | object | Container resource requests/limits. Lightweight defaults aimed at small clusters (incl. Raspberry Pi / arm64). | `{"limits":{"cpu":"2","memory":"2Gi"},"requests":{"cpu":"100m","memory":"256Mi"}}` |
| runtimeClassName | string | RuntimeClass for the Pod. Set to a sandboxed runtime (gVisor: "gvisor",    Kata: "kata-containers") to add a kernel isolation boundary around the    agent's shell execution. Empty by default: the cluster's default runtime. | `""` |
| secretAnnotations | object | Annotations to add to the chart's env Secret. With `externalSecret.enabled`    the Secret is created by ESO, so use `externalSecret.annotations` instead. | `{}` |
| securityContext | object | Container-level securityContext. Same caveat as `podSecurityContext` above. | `{}` |
| service.annotations | object | Annotations to add to the Service. | `{}` |
| service.enabled | bool | Create a ClusterIP Service for explicitly selected listeners. | `false` |
| service.port | int | Legacy dashboard Service port. Used only while `service.ports` is empty,    preserving the existing dashboard-only Service behaviour. | `9119` |
| service.ports | list | Explicit Service ports. A non-empty list replaces the legacy dashboard    port entirely. Enabling apiServer or webhook does not add a Service port    automatically. | `[]` |
| service.type | string | Service type. | `"ClusterIP"` |
| serviceAccount.annotations | object | Annotations to add to the ServiceAccount. | `{}` |
| serviceAccount.automountServiceAccountToken | bool | Mount the ServiceAccount token into the Pod. The agent does not call    the Kubernetes API, so this chart turns it off. Behaviour change on    upgrade: without this field, Kubernetes applies its own default of    true. Set to true if something inside the Pod deliberately calls the    API (e.g. kubectl-style tooling in an extraContainer). | `false` |
| serviceAccount.create | bool | Create a ServiceAccount for the pod. | `true` |
| serviceAccount.name | string | Name to use; generated from fullname when empty. | `""` |
| soul | object | Contents of SOUL.md, seeded into HERMES_HOME alongside config.yaml. It    defines the agent's persistent identity. Empty means the chart seeds    nothing, so Hermes writes its own starter file on first run. | `{"text":""}` |
| team | object | ------------------------------------------------------------------------- | `{"enabled":false,"identity":"","leader":{"mentionEnv":"","name":"","username":""},"members":[],"name":"","platform":"discord","protocol":{"maxHandoffs":6},"role":"member","sharedVolume":{"accessModes":["ReadWriteMany"],"annotations":{},"claimName":"","create":false,"enabled":true,"mountPath":"/opt/data/team-knowledge","permissions":{"enabled":false,"gid":10000,"image":"busybox:1.38","securityContext":{"runAsGroup":0,"runAsUser":0},"uid":10000},"retain":true,"size":"10Gi","storageClass":""},"skill":{"configMapName":"","create":false,"enabled":true,"extraInstructions":"","name":""}}` |
| team.enabled | bool | Enable the chart-native leader/member team protocol, roster skill, and shared knowledge volume mount for this release. | `false` |
| team.identity | string | This release's identity. For a leader it must equal `leader.name`; for a member it must match one entry under `members`. | `""` |
| team.leader.mentionEnv | string | Environment variable containing the leader's Discord user ID. Supply it through a Secret/SealedSecret; the ID is expanded by Hermes at runtime. | `""` |
| team.leader.name | string | Leader identity shared by every release in the team. | `""` |
| team.leader.username | string | Telegram only: the leader bot's @username, without the `@`. | `""` |
| team.members | list | Configured members. ApplicationSet users define this once in the common template so every generated release receives the same complete roster. | `[]` |
| team.name | string | Stable team identifier used in the generated skill and default names. | `""` |
| team.platform | string | Chat platform the team coordinates on: `discord` or `telegram`. It picks the mention format and the gates team mode enforces (see the chart README, "Agent team"). Every release in one team must use the same platform. | `"discord"` |
| team.protocol.maxHandoffs | int | Maximum serial leader-to-member handoffs before escalating to a human. | `6` |
| team.role | string | This release's team role. | `"member"` |
| team.sharedVolume.accessModes | list | RWX access modes used only when `create=true`. | `["ReadWriteMany"]` |
| team.sharedVolume.annotations | object | Annotations to add to the shared PVC, used only when `create=true`. With    `retain: true` the `helm.sh/resource-policy: keep` annotation is always set. | `{}` |
| team.sharedVolume.claimName | string | Shared PVC name. Empty defaults to `<team.name>-knowledge`. | `""` |
| team.sharedVolume.create | bool | Create the shared PVC from this release. Set true on exactly one leader release; all members set false and reference the same `claimName`. | `false` |
| team.sharedVolume.enabled | bool | Mount a required RWX knowledge volume when team mode is enabled. | `true` |
| team.sharedVolume.mountPath | string | Mount path for durable accepted team knowledge. | `"/opt/data/team-knowledge"` |
| team.sharedVolume.permissions.enabled | bool | On the leader, chown the shared volume before Hermes starts. Enable only when the storage backend permits ownership changes. This init container needs root (see securityContext below), so it is incompatible with Pod Security Standards `restricted` - set false and rely on `podSecurityContext.fsGroup` instead when the storage backend honours it. See values-hardened.yaml. | `false` |
| team.sharedVolume.permissions.image | string | Init image used for shared-volume ownership preparation. | `"busybox:1.38"` |
| team.sharedVolume.permissions.securityContext | object | securityContext for the chown init container. Defaults to root - `chown` across arbitrary storage backends needs it. Not overridable to non-root; disable `permissions.enabled` instead under `restricted`. Setting this to `{}` does NOT restore an image-default user the way `auth.deviceFlow.securityContext: {}` does - it renders an explicit empty securityContext, which inherits podSecurityContext's fields (e.g. a hardened profile's non-root runAsUser), silently breaking the chown this container exists to perform. Disable `permissions.enabled` instead of clearing this value. | `{"runAsGroup":0,"runAsUser":0}` |
| team.sharedVolume.permissions.uid | int | Runtime owner for the shared knowledge directory. | `10000` |
| team.sharedVolume.retain | bool | Keep a chart-created shared claim when the owning release is removed. | `true` |
| team.sharedVolume.size | string | Requested shared storage size used only when `create=true`. | `"10Gi"` |
| team.sharedVolume.storageClass | string | StorageClass used only when `create=true`; empty uses cluster default. | `""` |
| team.skill.configMapName | string | Shared ConfigMap name. Empty defaults to `<team.name>-skill`. | `""` |
| team.skill.create | bool | Create the shared skill ConfigMap from this release. Set true on exactly one leader release; every member references the same ConfigMap. | `false` |
| team.skill.enabled | bool | Mount the shared team roster and protocol as a read-only skill. | `true` |
| team.skill.extraInstructions | string | Optional deployment-specific policy appended to the generated skill. Used only by the release with `skill.create=true`. | `""` |
| team.skill.name | string | Skill name. Empty defaults to `<team.name>-roster`. | `""` |
| terminationGracePeriodSeconds | string | Pod termination grace period in seconds. Empty = Kubernetes default (30s). The gateway (image v2026.7.1+) defaults `agent.restart_drain_timeout` to 0: on stop it interrupts in-flight runs immediately, persists the transcript, and exits fast: the default grace period is plenty. If you opt into a drain window via `config.agent.restart_drain_timeout: <seconds>`, raise this WELL ABOVE that value or the kubelet SIGKILLs the gateway mid-drain (stale lock + crash loop: the same race upstream warns about with systemd's TimeoutStopSec). See "Gateway lifecycle" in the README. | `""` |
| tests | object | ------------------------------------------------------------------------- | `{"annotations":{},"chat":{"enabled":false,"failOnError":false,"maxTurns":1,"models":[],"prompt":"Just say hi.","timeout":180},"doctorStrict":false,"doctorTimeout":120,"enabled":true,"image":{"pullPolicy":"","repository":"","tag":""},"isolateDoctor":false,"resources":{"limits":{"cpu":"1","memory":"1536Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}}` |
| tests.annotations | object | Extra annotations to add to the test Job. The chart's own Helm and Argo CD    hook annotations are always set, and a key here that repeats one of them    is ignored. | `{}` |
| tests.chat | object | ------------------------------------------------------------------------- | `{"enabled":false,"failOnError":false,"maxTurns":1,"models":[],"prompt":"Just say hi.","timeout":180}` |
| tests.chat.enabled | bool | Run a `hermes chat` round-trip and log the conversation. | `false` |
| tests.chat.failOnError | bool | When true, a failed/empty round-trip fails the test job. | `false` |
| tests.chat.maxTurns | int | Max agent turns for the round-trip. | `1` |
| tests.chat.models | list | Optional pool of `provider/model` ids to try in order (via `hermes chat    -m <id> --provider config.model.provider`), each with its own `timeout`.    Passes as soon as one succeeds: useful for free-tier models that are    sometimes overloaded. Leave empty to use `config.model.default` as-is    (single attempt, no `-m`/`--provider` override). | `[]` |
| tests.chat.prompt | string | Prompt sent to the agent. | `"Just say hi."` |
| tests.chat.timeout | int | Seconds to allow each round-trip attempt to run before timing out. | `180` |
| tests.doctorStrict | bool | When true, `hermes doctor` issues fail the test. When false, doctor runs    for visibility but only hard checks (hermes --version, seeded config) fail. | `false` |
| tests.doctorTimeout | int | Seconds to allow `hermes doctor` to run before timing out. | `120` |
| tests.enabled | bool | Render the chart test Job. | `true` |
| tests.image | object | Image used by the test Job. Empty fields fall back to the main `image.*` (so the hermes CLI + doctor are available and arch matches). | `{"pullPolicy":"","repository":"","tag":""}` |
| tests.isolateDoctor | bool | Run non-strict doctor in a separate container so a diagnostic OOM    does not kill the required checks. Opt-in; requires Kubernetes 1.33+    and a positive doctorTimeout. Each container uses tests.resources. | `false` |
| tests.resources | object | Resource requests/limits for the test Job's container. The memory limit    leaves room for `hermes doctor`, which needs several hundred MiB while it runs. | `{"limits":{"cpu":"1","memory":"1536Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}` |
| tolerations | list | Tolerations for Pod scheduling. | `[]` |
| webhook.enabled | bool | Enable Hermes' generic inbound webhook receiver. Native messenger    webhook modes (such as Telegram) are separate listeners configured via env/config. | `false` |
| webhook.port | int | Webhook receiver port. | `8644` |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
