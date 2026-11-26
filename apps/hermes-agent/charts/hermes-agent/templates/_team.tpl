{{/* Validate the cross-field invariants that JSON Schema cannot express. */}}
{{- define "hermes-agent.team.validate" -}}
{{- if .Values.team.enabled -}}
  {{- $teamName := required "team.name is required when team.enabled=true" .Values.team.name -}}
  {{- $identity := required "team.identity is required when team.enabled=true" .Values.team.identity -}}
  {{- $leaderName := required "team.leader.name is required when team.enabled=true" .Values.team.leader.name -}}
  {{- $platform := .Values.team.platform | default "discord" -}}
  {{- if not (has $platform (list "discord" "telegram")) -}}
    {{- fail (printf "team.platform must be discord or telegram, got %q" $platform) -}}
  {{- end -}}
  {{- $leaderMention := include "hermes-agent.team.routingKey" (list $platform .Values.team.leader "team.leader") -}}
  {{- if lt (len .Values.team.members) 1 -}}
    {{- fail "team.members must contain at least one member when team.enabled=true" -}}
  {{- end -}}
  {{- if not .Values.team.sharedVolume.enabled -}}
    {{- fail "team.sharedVolume.enabled must be true when team.enabled=true" -}}
  {{- end -}}
  {{- if not .Values.team.skill.enabled -}}
    {{- fail "team.skill.enabled must be true when team.enabled=true" -}}
  {{- end -}}
  {{- if and (eq .Values.team.role "member") .Values.team.skill.create -}}
    {{- fail "only a team leader release may set team.skill.create=true" -}}
  {{- end -}}
  {{- if eq .Values.team.sharedVolume.mountPath .Values.persistence.mountPath -}}
    {{- fail "team.sharedVolume.mountPath must differ from persistence.mountPath" -}}
  {{- end -}}
  {{- if and (eq .Values.team.role "member") .Values.team.sharedVolume.create -}}
    {{- fail "only a team leader release may set team.sharedVolume.create=true" -}}
  {{- end -}}
  {{- if and .Values.team.sharedVolume.permissions.enabled (ne .Values.team.role "leader") -}}
    {{- fail "team.sharedVolume.permissions.enabled is supported only for the leader" -}}
  {{- end -}}

  {{- $names := dict $leaderName true -}}
  {{- $mentions := dict $leaderMention true -}}
  {{- $identityIsMember := false -}}
  {{- range .Values.team.members -}}
    {{- if hasKey $names .name -}}
      {{- fail (printf "team member name %q is duplicated or matches the leader" .name) -}}
    {{- end -}}
    {{- $_ := set $names .name true -}}
    {{- $key := include "hermes-agent.team.routingKey" (list $platform . (printf "team.members[%s]" .name)) -}}
    {{- if hasKey $mentions $key -}}
      {{- if eq $platform "telegram" -}}
        {{- fail (printf "team Telegram username %q is duplicated" $key) -}}
      {{- else -}}
        {{- fail (printf "team mention environment variable %q is duplicated" $key) -}}
      {{- end -}}
    {{- end -}}
    {{- $_ := set $mentions $key true -}}
    {{- if eq .name $identity -}}
      {{- $identityIsMember = true -}}
    {{- end -}}
  {{- end -}}
  {{- if and (eq .Values.team.role "leader") (ne $identity $leaderName) -}}
    {{- fail "team.identity must equal team.leader.name for a leader release" -}}
  {{- end -}}
  {{- if and (eq .Values.team.role "member") (not $identityIsMember) -}}
    {{- fail "team.identity must match one team.members entry for a member release" -}}
  {{- end -}}

  {{- $agent := default (dict) (get .Values.config "agent") -}}
  {{- $disabled := default (list) (get $agent "disabled_toolsets") -}}
  {{- if has "skills" $disabled -}}
    {{- fail "team mode requires the skills toolset; remove skills from config.agent.disabled_toolsets" -}}
  {{- end -}}

  {{- $reserved := list "DISCORD_ALLOW_BOTS" "DISCORD_THREAD_REQUIRE_MENTION" "DISCORD_REPLY_TO_MODE" "DISCORD_ALLOW_MENTION_REPLIED_USER" -}}
  {{- if eq $platform "telegram" -}}
    {{- $reserved = list "TELEGRAM_ALLOW_BOTS" "TELEGRAM_REQUIRE_MENTION" "TELEGRAM_BOTS_REQUIRE_MENTION" "TELEGRAM_REPLY_TO_MODE" -}}
  {{- end -}}
  {{- range .Values.extraEnv -}}
    {{- if has .name $reserved -}}
      {{- fail (printf "%s is managed by team mode; remove it from extraEnv" .name) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Per-platform routing key for a roster entry, validated here so every caller
sees the same rule. Discord routes on a user ID kept in an env var
(`mentionEnv`, expanded by Hermes at runtime); Telegram routes on the bot's
public @username, used literally. Call as:
  include "hermes-agent.team.routingKey" (list $platform $entry "field.path")
*/}}
{{- define "hermes-agent.team.routingKey" -}}
{{- $platform := index . 0 -}}
{{- $entry := index . 1 -}}
{{- $path := index . 2 -}}
{{- if eq $platform "telegram" -}}
  {{- $username := required (printf "%s.username is required when team.platform=telegram" $path) (get $entry "username") -}}
  {{- if not (regexMatch "^[A-Za-z][A-Za-z0-9_]{3,31}$" $username) -}}
    {{- fail (printf "%s.username %q is not a Telegram username (5-32 letters, digits or underscores, starting with a letter, without the @)" $path $username) -}}
  {{- end -}}
  {{- lower $username -}}
{{- else -}}
  {{- required (printf "%s.mentionEnv is required when team.enabled=true" $path) (get $entry "mentionEnv") -}}
{{- end -}}
{{- end -}}

{{/* Exact text another agent must write to address this roster entry. */}}
{{- define "hermes-agent.team.mention" -}}
{{- $platform := index . 0 -}}
{{- $entry := index . 1 -}}
{{- if eq $platform "telegram" -}}
@{{ get $entry "username" }}
{{- else -}}
{{ printf "<@${%s}>" (get $entry "mentionEnv") }}
{{- end -}}
{{- end -}}

{{- define "hermes-agent.team.platformLabel" -}}
{{- if eq (.Values.team.platform | default "discord") "telegram" -}}Telegram{{- else -}}Discord{{- end -}}
{{- end -}}

{{- define "hermes-agent.team.skillName" -}}
{{- .Values.team.skill.name | default (printf "%s-roster" .Values.team.name) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "hermes-agent.team.skillConfigMapName" -}}
{{- .Values.team.skill.configMapName | default (printf "%s-skill" .Values.team.name) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "hermes-agent.team.sharedClaimName" -}}
{{- .Values.team.sharedVolume.claimName | default (printf "%s-knowledge" .Values.team.name) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "hermes-agent.team.skillMountPath" -}}
{{- printf "%s/skills/%s" (.Values.persistence.mountPath | trimSuffix "/") (include "hermes-agent.team.skillName" .) -}}
{{- end -}}

{{/* Minimal always-on identity and routing context. The full protocol stays in the skill. */}}
{{- define "hermes-agent.team.environmentHint" -}}
You are {{ .Values.team.identity | quote }}, the {{ upper .Values.team.role }} of Hermes team {{ .Values.team.name | quote }}.
Load and follow /{{ include "hermes-agent.team.skillName" . }} for every team roster, member-status, delegation, handoff, review, or synthesis request.
{{- $platform := .Values.team.platform | default "discord" }}
{{- $label := include "hermes-agent.team.platformLabel" . }}
The configured leader is {{ .Values.team.leader.name | quote }} with exact {{ $label }} mention {{ include "hermes-agent.team.mention" (list $platform .Values.team.leader) }}.
{{- if eq .Values.team.role "leader" }}
Configured members and their exact {{ $label }} mentions:
{{- range .Values.team.members }}
- {{ .name }}: {{ include "hermes-agent.team.mention" (list $platform .) }} - {{ .role }}
{{- end }}
Only explicit {{ $label }} messages following the team skill are cross-agent handoffs.
To delegate, write your normal reply with the member's exact mention and a [TEAM run=<id> step=<n> TASK] marker. That reply is the handoff: no tool is needed, and not having a messaging tool does not mean you cannot delegate.
{{- else }}
Accept team work only from the configured leader and return the complete result to that leader according to the team skill.
A message from the leader that carries a [TEAM run=<id> step=<n> TASK] marker is a handoff: before answering it, load /{{ include "hermes-agent.team.skillName" . }}, then reply as its member workflow says (one complete response that begins with the leader's exact mention and ends with the matching RESULT marker). Do not add greetings, introductions, or profile questions to that reply.
{{- end }}
{{ $label }}'s typing indicator is display state, not authoritative evidence that a member is online or working.
Durable accepted team knowledge is mounted at {{ .Values.team.sharedVolume.mountPath }}; it is not a task queue or completion signal.
{{- end -}}

{{/*
Merge team-safe conversation settings and identity context into config.yaml.
The discord/group_sessions_per_user defaults below only fill in a key the
user hasn't already set under `config:` (see hermes-agent.setConfigDefault) -
an existing team install that never touched these keys renders byte-identical
config.yaml; anyone who wants different team-mode Discord behavior can now
set it themselves. agent.environment_hint is exempt: it's generated from the
team roster (team.members/team.leader/team.identity), not a static default,
so it always merges rather than only filling a gap.
*/}}
{{- define "hermes-agent.effectiveConfig" -}}
{{- include "hermes-agent.team.validate" . -}}
{{- $config := deepCopy .Values.config -}}
{{- if .Values.dashboard.enabled -}}
  {{- $dash := deepCopy (default (dict) (get $config "dashboard")) -}}
  {{- $url := include "hermes-agent.dashboard.publicUrl" . -}}
  {{- if $url -}}
    {{- $_ := include "hermes-agent.setConfigDefault" (list $dash "public_url" $url) -}}
  {{- end -}}
  {{- if .Values.dashboard.trustedProxies -}}
    {{- $_ := include "hermes-agent.setConfigDefault" (list $dash "trusted_proxies" .Values.dashboard.trustedProxies) -}}
  {{- end -}}
  {{- $_ := set $config "dashboard" $dash -}}
{{- end -}}
{{- if .Values.team.enabled -}}
  {{- $_ := include "hermes-agent.setConfigDefault" (list $config "group_sessions_per_user" false) -}}
  {{- if eq (.Values.team.platform | default "discord") "telegram" -}}
  {{- /* Explicit @username mentions route to exactly the named bots, and no
         shared wake word may pull a sibling bot into a handoff. Defaults
         only; the enforced gates are env vars (see hermes-agent.team.env). */ -}}
  {{- $telegram := deepCopy (default (dict) (get $config "telegram")) -}}
  {{- $_ := include "hermes-agent.setConfigDefault" (list $telegram "exclusive_bot_mentions" true) -}}
  {{- $_ := include "hermes-agent.setConfigDefault" (list $telegram "mention_patterns" (list)) -}}
  {{- $_ := set $config "telegram" $telegram -}}
  {{- else -}}
  {{- $discord := deepCopy (default (dict) (get $config "discord")) -}}
  {{- $_ := include "hermes-agent.setConfigDefault" (list $discord "thread_require_mention" true) -}}
  {{- $_ := include "hermes-agent.setConfigDefault" (list $discord "history_backfill" true) -}}
  {{- $_ := include "hermes-agent.setConfigDefault" (list $discord "history_backfill_limit" 50) -}}
  {{- $allowMentions := deepCopy (default (dict) (get $discord "allow_mentions")) -}}
  {{- $_ := include "hermes-agent.setConfigDefault" (list $allowMentions "everyone" false) -}}
  {{- $_ := include "hermes-agent.setConfigDefault" (list $allowMentions "roles" false) -}}
  {{- $_ := include "hermes-agent.setConfigDefault" (list $allowMentions "users" true) -}}
  {{- $_ := include "hermes-agent.setConfigDefault" (list $allowMentions "replied_user" false) -}}
  {{- $_ := set $discord "allow_mentions" $allowMentions -}}
  {{- $_ := set $config "discord" $discord -}}
  {{- end -}}

  {{- $agent := deepCopy (default (dict) (get $config "agent")) -}}
  {{- $existingHint := default "" (get $agent "environment_hint") -}}
  {{- $teamHint := include "hermes-agent.team.environmentHint" . -}}
  {{- if $existingHint -}}
    {{- $_ := set $agent "environment_hint" (printf "%s\n\n%s" ($existingHint | trim) ($teamHint | trim)) -}}
  {{- else -}}
    {{- $_ := set $agent "environment_hint" ($teamHint | trim) -}}
  {{- end -}}
  {{- $_ := set $config "agent" $agent -}}
{{- end -}}
{{- toYaml $config -}}
{{- end -}}

{{/*
Team-mode gates rendered as container env vars. Env wins over config.yaml,
so these are enforced, and hermes-agent.team.validate rejects the same names
in extraEnv. Discord: explicit body mentions are the only bot-to-bot trigger.
Telegram: another bot's message counts only when it explicitly @mentions this
bot (TELEGRAM_BOTS_REQUIRE_MENTION), because a quote-reply otherwise passes
the mention gate and two bots can answer each other forever; replies carry no
reply reference, and group messages need a mention at all.
*/}}
{{- define "hermes-agent.team.env" -}}
{{- if eq (.Values.team.platform | default "discord") "telegram" }}
# Team mode makes explicit @username mentions the only bot-to-bot trigger.
- name: TELEGRAM_ALLOW_BOTS
  value: "mentions"
- name: TELEGRAM_REQUIRE_MENTION
  value: "true"
- name: TELEGRAM_BOTS_REQUIRE_MENTION
  value: "true"
- name: TELEGRAM_REPLY_TO_MODE
  value: "off"
{{- else }}
# Team mode makes explicit body mentions the only bot-to-bot trigger.
- name: DISCORD_ALLOW_BOTS
  value: "mentions"
- name: DISCORD_THREAD_REQUIRE_MENTION
  value: "true"
- name: DISCORD_REPLY_TO_MODE
  value: "off"
- name: DISCORD_ALLOW_MENTION_REPLIED_USER
  value: "false"
{{- end }}
{{- end -}}
