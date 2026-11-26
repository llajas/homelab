{{/*
Expand the name of the chart.
*/}}
{{- define "hermes-agent.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a fully qualified app name.
*/}}
{{- define "hermes-agent.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Chart name and version label.
*/}}
{{- define "hermes-agent.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "hermes-agent.labels" -}}
helm.sh/chart: {{ include "hermes-agent.chart" . }}
{{ include "hermes-agent.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "hermes-agent.selectorLabels" -}}
app.kubernetes.io/name: {{ include "hermes-agent.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service account name.
*/}}
{{- define "hermes-agent.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "hermes-agent.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/* Runtime identity used by Hermes services for mutable HERMES_HOME files. */}}
{{- define "hermes-agent.migrationUID" -}}
{{- $uid := "10000" -}}
{{- if .Values.podSecurityContext.runAsUser }}{{- $uid = printf "%v" .Values.podSecurityContext.runAsUser -}}{{- end }}
{{- if .Values.securityContext.runAsUser }}{{- $uid = printf "%v" .Values.securityContext.runAsUser -}}{{- end }}
{{- with index .Values.env "PUID" }}{{- $uid = printf "%v" . -}}{{- end }}
{{- with index .Values.env "HERMES_UID" }}{{- $uid = printf "%v" . -}}{{- end }}
{{- $uid -}}
{{- end }}

{{- define "hermes-agent.migrationGID" -}}
{{- $gid := "10000" -}}
{{- if .Values.podSecurityContext.runAsGroup }}{{- $gid = printf "%v" .Values.podSecurityContext.runAsGroup -}}{{- end }}
{{- if .Values.securityContext.runAsGroup }}{{- $gid = printf "%v" .Values.securityContext.runAsGroup -}}{{- end }}
{{- with index .Values.env "PGID" }}{{- $gid = printf "%v" . -}}{{- end }}
{{- with index .Values.env "HERMES_GID" }}{{- $gid = printf "%v" . -}}{{- end }}
{{- $gid -}}
{{- end }}

{{/*
Shell snippet shared by the seed-config and test-Job init containers: run
Hermes' config migration as the runtime user. The image's `hermes` command is
a shim that drops root to the hermes user; the migration calls Python
directly, so it must drop privileges the same way. Run as root it would create
logs/, sessions/, skills/ and the rest of the HERMES_HOME skeleton as root, which
the gateway (and the test Job's `hermes` shim) then cannot write. When the init
container starts as root, hand over only the top-level HERMES_HOME and the
files the chart itself wrote (non-recursive, the same scope the image's own
stage2 first-boot fix uses); a non-root init container (hardened profile)
already creates everything as the runtime user.
*/}}
{{- define "hermes-agent.migrateConfig" -}}
echo "Migrating persisted Hermes config when supported"
case "$HERMES_MIGRATION_UID:$HERMES_MIGRATION_GID" in
  *[!0-9:]*|:*|*:) echo "HERMES_MIGRATION_UID/GID must be numeric" >&2; exit 1 ;;
esac
if [ "$(id -u)" = 0 ]; then
  if [ -L "$HERMES_HOME" ]; then
    echo "Refusing to change ownership through symlink $HERMES_HOME" >&2; exit 1
  fi
  chown "$HERMES_MIGRATION_UID:$HERMES_MIGRATION_GID" "$HERMES_HOME"
  for name in config.yaml .env SOUL.md; do
    path="$HERMES_HOME/$name"
    if [ -f "$path" ] && [ ! -L "$path" ]; then
      chown "$HERMES_MIGRATION_UID:$HERMES_MIGRATION_GID" "$path"
    fi
  done
  HOME="$HERMES_HOME" setpriv --reuid="$HERMES_MIGRATION_UID" \
    --regid="$HERMES_MIGRATION_GID" --clear-groups \
    /opt/hermes/.venv/bin/python /seed/migrate-config.py
else
  /opt/hermes/.venv/bin/python /seed/migrate-config.py
fi
{{- end }}

{{/*
Headless service name used for StatefulSet governance.
*/}}
{{- define "hermes-agent.headlessServiceName" -}}
{{- printf "%s-headless" (include "hermes-agent.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Name that device-login and ready messages use for this release: the team
identity in team mode, the release name otherwise.
*/}}
{{- define "hermes-agent.loginLabel" -}}
{{- if and .Values.team.enabled .Values.team.identity -}}
{{- .Values.team.identity -}}
{{- else -}}
{{- include "hermes-agent.fullname" . -}}
{{- end -}}
{{- end }}

{{/*
Channel the ready message goes to. readyNotify.notify wins; empty follows
auth.deviceFlow.notify when the device flow is enabled. Only discord and
telegram can carry a message, so any other result fails the render when
readyNotify is enabled.
*/}}
{{- define "hermes-agent.readyNotify.channel" -}}
{{- $channel := .Values.readyNotify.notify -}}
{{- if and (not $channel) .Values.auth.deviceFlow.enabled -}}
{{- $channel = .Values.auth.deviceFlow.notify -}}
{{- end -}}
{{- if not (has $channel (list "discord" "telegram")) -}}
{{- fail (printf "readyNotify.enabled needs readyNotify.notify set to discord or telegram (got %q). It follows auth.deviceFlow.notify only when auth.deviceFlow.enabled is true and that is discord or telegram" $channel) -}}
{{- end -}}
{{- $channel -}}
{{- end }}

{{/*
Name of the env Secret referenced by every chart-owned envFrom (main
container, auth-device-login init container, helm test Job). Normally the
chart's own Secret (secret.yaml); when externalSecret.enabled, secret.yaml
never renders and this becomes the ExternalSecret's target name instead -
externalSecret.target.name when set, or the same <fullname>-env default
otherwise, so every reference stays in lockstep without extraEnvFrom.
*/}}
{{- define "hermes-agent.envSecretName" -}}
{{- if and .Values.externalSecret.enabled .Values.externalSecret.target.name -}}
{{- .Values.externalSecret.target.name -}}
{{- else -}}
{{- printf "%s-env" (include "hermes-agent.fullname" .) -}}
{{- end -}}
{{- end }}

{{/*
Main image reference. Falls back to Chart.AppVersion when image.tag is empty.
*/}}
{{- define "hermes-agent.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) }}
{{- end }}

{{/*
Test image reference. Falls back to the main image when tests.image fields are empty.
*/}}
{{- define "hermes-agent.testImage" -}}
{{- $repo := .Values.tests.image.repository | default .Values.image.repository }}
{{- $tag := .Values.tests.image.tag | default .Values.image.tag | default .Chart.AppVersion }}
{{- printf "%s:%s" $repo $tag }}
{{- end }}

{{/*
Set $dict[$key] = $default, but only when $dict doesn't already have that key
- so a chart-computed default (team mode's config.yaml overlay, or any future
one) never clobbers a value the user already set under `config:`. Go maps are
reference types, so mutating $dict here is visible to the caller with no
return value needed. Call as:
  {{- $_ := include "hermes-agent.setConfigDefault" (list $dict "key" $default) -}}
*/}}
{{- define "hermes-agent.setConfigDefault" -}}
{{- $dict := index . 0 -}}
{{- $key := index . 1 -}}
{{- $default := index . 2 -}}
{{- if not (hasKey $dict $key) -}}
  {{- $_ := set $dict $key $default -}}
{{- end -}}
{{- end -}}

{{/*
Logical ports exposed by the chart Service. An empty explicit list keeps the
legacy dashboard-only Service byte-for-byte compatible. Callers may parse this
list for another Kubernetes port shape, such as containerPorts.
*/}}
{{- define "hermes-agent.servicePorts" -}}
{{- if .Values.service.ports }}
{{- range .Values.service.ports }}
- name: {{ .name }}
  port: {{ .port }}
  targetPort: {{ .targetPort | default .port }}
  protocol: {{ .protocol | default "TCP" }}
{{- end }}
{{- else -}}
# Intended for the management dashboard (port 9119). Requires the dashboard
# to be enabled (HERMES_DASHBOARD=1) with an auth provider configured; it
# binds 0.0.0.0 inside the container by default (see values-ingress.yaml).
- name: dashboard
  port: {{ .Values.service.port }}
  targetPort: {{ .Values.service.port }}
  protocol: TCP
{{- end }}
{{- end }}

{{/*
Public URL the dashboard is reached at. An explicit dashboard.publicUrl wins;
otherwise it is derived from the first Ingress host (https when the Ingress
has TLS entries). Empty when neither is available.
*/}}
{{- define "hermes-agent.dashboard.publicUrl" -}}
{{- if .Values.dashboard.publicUrl -}}
{{- .Values.dashboard.publicUrl -}}
{{- else if and .Values.ingress.enabled .Values.ingress.hosts -}}
{{- $scheme := ternary "https" "http" (not (empty .Values.ingress.tls)) -}}
{{- printf "%s://%s" $scheme (index .Values.ingress.hosts 0).host -}}
{{- end -}}
{{- end }}

{{/*
True (non-empty) when an env var name is provided through `env` or `extraEnv`.
Call as: include "hermes-agent.dashboard.hasEnv" (list . "NAME")
*/}}
{{- define "hermes-agent.dashboard.hasEnv" -}}
{{- $root := index . 0 -}}
{{- $name := index . 1 -}}
{{- if hasKey (default (dict) $root.Values.env) $name -}}true
{{- else -}}
{{- range $root.Values.extraEnv -}}{{- if eq .name $name -}}true{{- end -}}{{- end -}}
{{- end -}}
{{- end }}

{{/*
Fail early when the dashboard is enabled but no upstream auth provider would be
configured: on a non-loopback bind the dashboard fails closed and stays down,
so an Ingress in front of it only answers 502/503. dashboard.auth.provider
"external" skips the check for credentials injected through extraEnvFrom or an
ExternalSecret, which the chart cannot inspect.
*/}}
{{- define "hermes-agent.dashboard.validate" -}}
{{- if .Values.dashboard.enabled -}}
{{- $provider := .Values.dashboard.auth.provider -}}
{{- $cfgDash := default (dict) (get (default (dict) .Values.config) "dashboard") -}}
{{- $cfgOauth := default (dict) (get $cfgDash "oauth") -}}
{{- if eq $provider "basic" -}}
  {{- $user := include "hermes-agent.dashboard.hasEnv" (list . "HERMES_DASHBOARD_BASIC_AUTH_USERNAME") -}}
  {{- $pass := or (include "hermes-agent.dashboard.hasEnv" (list . "HERMES_DASHBOARD_BASIC_AUTH_PASSWORD")) (include "hermes-agent.dashboard.hasEnv" (list . "HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH")) -}}
  {{- if not (and $user $pass) -}}
    {{- fail "dashboard.enabled with auth.provider=basic needs env.HERMES_DASHBOARD_BASIC_AUTH_USERNAME and env.HERMES_DASHBOARD_BASIC_AUTH_PASSWORD (or _PASSWORD_HASH); set them, or set dashboard.auth.provider=external when the credentials come from extraEnvFrom or an ExternalSecret" -}}
  {{- end -}}
{{- else if eq $provider "oauth" -}}
  {{- if not (or (include "hermes-agent.dashboard.hasEnv" (list . "HERMES_DASHBOARD_OAUTH_CLIENT_ID")) (get $cfgOauth "client_id")) -}}
    {{- fail "dashboard.enabled with auth.provider=oauth needs env.HERMES_DASHBOARD_OAUTH_CLIENT_ID or config.dashboard.oauth.client_id; set it, or set dashboard.auth.provider=external when it comes from extraEnvFrom or an ExternalSecret" -}}
  {{- end -}}
{{- else if eq $provider "oidc" -}}
  {{- $sh := default (dict) (get $cfgOauth "self_hosted") -}}
  {{- $issuer := or (include "hermes-agent.dashboard.hasEnv" (list . "HERMES_DASHBOARD_OIDC_ISSUER")) (get $sh "issuer") -}}
  {{- $client := or (include "hermes-agent.dashboard.hasEnv" (list . "HERMES_DASHBOARD_OIDC_CLIENT_ID")) (get $sh "client_id") -}}
  {{- if not (and $issuer $client) -}}
    {{- fail "dashboard.enabled with auth.provider=oidc needs HERMES_DASHBOARD_OIDC_ISSUER and HERMES_DASHBOARD_OIDC_CLIENT_ID (env/extraEnv) or config.dashboard.oauth.self_hosted.issuer/client_id; set them, or set dashboard.auth.provider=external when they come from extraEnvFrom or an ExternalSecret" -}}
  {{- end -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
Pod template (metadata + spec), shared by the StatefulSet and Deployment
controllers. Caller is expected to nest this under `template:` with `nindent 4`.
*/}}
{{- define "hermes-agent.podTemplate" -}}
{{- include "hermes-agent.team.validate" . -}}
{{- include "hermes-agent.dashboard.validate" . -}}
metadata:
  annotations:
    # Roll pods when config/secret content changes.
    checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
    # secret.yaml never renders while externalSecret.enabled (see that
    # template and hermes-agent.envSecretName) - hash the ExternalSecret
    # manifest instead, so changing its target/data still rolls the Pod.
    checksum/secret: {{ include (print $.Template.BasePath (ternary "/externalsecret.yaml" "/secret.yaml" .Values.externalSecret.enabled)) . | sha256sum }}
    {{- if and .Values.team.enabled .Values.team.skill.enabled }}
    # Roll leaders and members when the rendered shared skill changes. Members
    # reference the leader-owned ConfigMap, so hashing only the created resource
    # would leave their existing Pods on the previous in-memory protocol.
    checksum/team-skill: {{ tpl (.Files.Get "files/skills/hermes-team-roster/SKILL.md") . | sha256sum }}
    {{- end }}
    {{- with .Values.podAnnotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  labels:
    {{- include "hermes-agent.selectorLabels" . | nindent 4 }}
    {{- with .Values.podLabels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  serviceAccountName: {{ include "hermes-agent.serviceAccountName" . }}
  automountServiceAccountToken: {{ .Values.serviceAccount.automountServiceAccountToken }}
  {{- with .Values.runtimeClassName }}
  runtimeClassName: {{ . | quote }}
  {{- end }}
  {{- with .Values.terminationGracePeriodSeconds }}
  terminationGracePeriodSeconds: {{ . }}
  {{- end }}
  {{- with .Values.imagePullSecrets }}
  imagePullSecrets:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  securityContext:
    {{- toYaml .Values.podSecurityContext | nindent 4 }}
  {{- if or .Values.bootstrap.enabled .Values.auth.deviceFlow.enabled .Values.extraInitContainers (and .Values.team.enabled .Values.team.sharedVolume.permissions.enabled) }}
  initContainers:
    {{- if .Values.bootstrap.enabled }}
    # Seed chart-managed files into HERMES_HOME (the writable volume). Hermes
    # merges config.yaml over its built-in defaults and also writes to its home
    # at runtime, so the ConfigMap is not mounted there read-only.
    - name: seed-config
      image: "{{ include "hermes-agent.image" . }}"
      imagePullPolicy: {{ .Values.image.pullPolicy }}
      securityContext:
        {{- toYaml .Values.securityContext | nindent 8 }}
      command:
        - sh
        - -c
        - |
          set -eu
          seed() {
            dest="$1"
            source="$2"
            if [ "{{ .Values.bootstrap.overwrite }}" = "true" ] || [ ! -f "$dest" ]; then
              echo "Seeding $dest (overwrite={{ .Values.bootstrap.overwrite }})"
              cp "$source" "$dest"
            else
              echo "Keeping existing $dest (overwrite=false)"
            fi
          }
          seed "{{ .Values.persistence.mountPath }}/config.yaml" /seed/config.yaml
          if [ -f /seed/SOUL.md ]; then
            seed "{{ .Values.persistence.mountPath }}/SOUL.md" /seed/SOUL.md
          fi
          {{- if .Values.readyNotify.enabled }}
          # Chart-owned gateway:startup hook: always refreshed, never user-edited.
          mkdir -p "{{ .Values.persistence.mountPath }}/hooks/ready-notify"
          cp /seed/ready-notify-HOOK.yaml "{{ .Values.persistence.mountPath }}/hooks/ready-notify/HOOK.yaml"
          cp /seed/ready-notify-handler.py "{{ .Values.persistence.mountPath }}/hooks/ready-notify/handler.py"
          {{- end }}
          {{- include "hermes-agent.migrateConfig" . | nindent 10 }}
      env:
        - name: HERMES_HOME
          value: {{ .Values.persistence.mountPath | quote }}
        - name: HERMES_MIGRATION_UID
          value: {{ include "hermes-agent.migrationUID" . | quote }}
        - name: HERMES_MIGRATION_GID
          value: {{ include "hermes-agent.migrationGID" . | quote }}
      volumeMounts:
        - name: config
          mountPath: /seed
          readOnly: true
        - name: data
          mountPath: {{ .Values.persistence.mountPath }}
    {{- end }}
    {{- if .Values.auth.deviceFlow.enabled }}
    {{- $df := .Values.auth.deviceFlow }}
    {{- $p := index $df.providers $df.provider }}
    {{- if not $p }}{{ fail (printf "auth.deviceFlow.provider %q has no matching entry under auth.deviceFlow.providers" $df.provider) }}{{- end }}
    {{- $flow := $p.flow | default "github" }}
    # Bootstrap the selected provider credential before the agent starts.
    # GitHub writes .env; OpenAI Codex uses Hermes' native auth.json store.
    - name: auth-device-login
      {{- if eq $flow "openai-codex" }}
      image: "{{ include "hermes-agent.image" . }}"
      {{- else }}
      image: "{{ $df.image.repository }}:{{ $df.image.tag }}"
      {{- end }}
      imagePullPolicy: {{ .Values.image.pullPolicy }}
      {{- with $df.securityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      command: ["python3", "/login/device_login.py"]
      env:
        - name: HERMES_HOME
          value: {{ .Values.persistence.mountPath | quote }}
        - name: DEVICE_FLOW_KIND
          value: {{ $flow | quote }}
        - name: OAUTH_CLIENT_ID
          value: {{ $p.clientId | default "" | quote }}
        - name: OAUTH_SCOPE
          value: {{ $p.scope | default "read:user" | quote }}
        - name: AUTH_HOST
          value: {{ $p.authHost | default "github.com" | quote }}
        - name: TOKEN_ENV
          value: {{ $p.tokenEnv | default "" | quote }}
        - name: VALIDATE_URL
          value: {{ $p.validateUrl | default "" | quote }}
        - name: OPENAI_CODEX_ISSUER
          value: {{ $p.issuer | default "https://auth.openai.com" | quote }}
        - name: NOTIFY
          value: {{ $df.notify | quote }}
        - name: LOGIN_LABEL
          value: {{ include "hermes-agent.loginLabel" . | quote }}
        - name: LOGIN_TIMEOUT_SECONDS
          value: {{ $df.timeoutSeconds | quote }}
        - name: FORCE_RELOGIN
          value: {{ $df.forceRelogin | quote }}
        - name: CHOWN_UID
          value: {{ $df.tokenOwner.uid | quote }}
        - name: CHOWN_GID
          value: {{ $df.tokenOwner.gid | quote }}
        - name: PYTHONUNBUFFERED
          value: "1"
        {{- with .Values.extraEnv }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      envFrom:
        - secretRef:
            name: {{ include "hermes-agent.envSecretName" . }}
        {{- with .Values.extraEnvFrom }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- with $df.resources }}
      resources:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      volumeMounts:
        - name: login-script
          mountPath: /login
          readOnly: true
        - name: data
          mountPath: {{ .Values.persistence.mountPath }}
    {{- end }}
    {{- if and .Values.team.enabled .Values.team.sharedVolume.permissions.enabled }}
    # Optional ownership preparation for a chart-managed RWX knowledge volume.
    - name: init-team-shared
      image: {{ .Values.team.sharedVolume.permissions.image | quote }}
      imagePullPolicy: IfNotPresent
      securityContext:
        {{- toYaml .Values.team.sharedVolume.permissions.securityContext | nindent 8 }}
      command:
        - sh
        - -c
        - chown -R {{ .Values.team.sharedVolume.permissions.uid }}:{{ .Values.team.sharedVolume.permissions.gid }} /team-shared
      volumeMounts:
        - name: team-shared
          mountPath: /team-shared
    {{- end }}
    {{- with .Values.extraInitContainers }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- end }}
  containers:
    - name: hermes-agent
      image: "{{ include "hermes-agent.image" . }}"
      imagePullPolicy: {{ .Values.image.pullPolicy }}
      {{- with .Values.command }}
      command:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.args }}
      args:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- if .Values.service.ports }}
      ports:
        {{- range (include "hermes-agent.servicePorts" . | fromYamlArray) }}
        - name: {{ .name }}
          containerPort: {{ .targetPort | default .port }}
          protocol: {{ .protocol | default "TCP" }}
        {{- end }}
      {{- end }}
      securityContext:
        {{- toYaml .Values.securityContext | nindent 8 }}
      env:
        - name: HERMES_HOME
          value: {{ .Values.persistence.mountPath | quote }}
        {{- if .Values.readyNotify.enabled }}
        - name: READY_NOTIFY
          value: {{ include "hermes-agent.readyNotify.channel" . | quote }}
        - name: READY_NOTIFY_LABEL
          value: {{ include "hermes-agent.loginLabel" . | quote }}
        {{- end }}
        {{- if .Values.dashboard.enabled }}
        - name: HERMES_DASHBOARD
          value: "1"
        {{- end }}
        {{- if .Values.apiServer.enabled }}
        - name: API_SERVER_ENABLED
          value: "true"
        - name: API_SERVER_HOST
          value: {{ .Values.apiServer.host | quote }}
        - name: API_SERVER_PORT
          value: {{ .Values.apiServer.port | quote }}
        {{- with .Values.apiServer.corsOrigins }}
        - name: API_SERVER_CORS_ORIGINS
          value: {{ . | quote }}
        {{- end }}
        {{- end }}
        {{- if .Values.webhook.enabled }}
        - name: WEBHOOK_ENABLED
          value: "true"
        - name: WEBHOOK_PORT
          value: {{ .Values.webhook.port | quote }}
        {{- end }}
        {{- if .Values.team.enabled }}
        {{- include "hermes-agent.team.env" . | trim | nindent 8 }}
        {{- end }}
        {{- with .Values.extraEnv }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      envFrom:
        - secretRef:
            name: {{ include "hermes-agent.envSecretName" . }}
        {{- with .Values.extraEnvFrom }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- with .Values.probes.startup }}
      startupProbe:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.probes.liveness }}
      livenessProbe:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- if .Values.probes.readiness }}
      readinessProbe:
        {{- toYaml .Values.probes.readiness | nindent 8 }}
      {{- else if and .Values.dashboard.enabled .Values.dashboard.readinessProbe.enabled }}
      # Dashboard-aware readiness: the pod only joins the Service once the
      # dashboard listens (first start can take minutes while bundled skills
      # sync onto the volume). Readiness never restarts the container.
      readinessProbe:
        tcpSocket:
          port: {{ .Values.service.port }}
        periodSeconds: {{ .Values.dashboard.readinessProbe.periodSeconds }}
        failureThreshold: 3
      {{- end }}
      resources:
        {{- toYaml .Values.resources | nindent 8 }}
      volumeMounts:
        - name: data
          mountPath: {{ .Values.persistence.mountPath }}
        {{- if and .Values.team.enabled .Values.team.skill.enabled }}
        - name: team-skill
          mountPath: {{ include "hermes-agent.team.skillMountPath" . }}
          readOnly: true
        {{- end }}
        {{- if and .Values.team.enabled .Values.team.sharedVolume.enabled }}
        - name: team-shared
          mountPath: {{ .Values.team.sharedVolume.mountPath }}
          readOnly: {{ ne .Values.team.role "leader" }}
        {{- end }}
        {{- with .Values.extraVolumeMounts }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    {{- with .Values.extraContainers }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  volumes:
    {{- if .Values.bootstrap.enabled }}
    - name: config
      configMap:
        name: {{ include "hermes-agent.fullname" . }}-config
    {{- end }}
    {{- if .Values.auth.deviceFlow.enabled }}
    - name: login-script
      configMap:
        name: {{ include "hermes-agent.fullname" . }}-login
        defaultMode: 0555
    {{- end }}
    {{- if .Values.persistence.enabled }}
    {{- if .Values.persistence.existingClaim }}
    - name: data
      persistentVolumeClaim:
        claimName: {{ .Values.persistence.existingClaim | quote }}
    {{- else if eq .Values.controller.type "deployment" }}
    - name: data
      persistentVolumeClaim:
        claimName: {{ include "hermes-agent.fullname" . }}
    {{- end }}
    {{- else }}
    - name: data
      emptyDir: {}
    {{- end }}
    {{- if and .Values.team.enabled .Values.team.skill.enabled }}
    - name: team-skill
      configMap:
        name: {{ include "hermes-agent.team.skillConfigMapName" . }}
    {{- end }}
    {{- if and .Values.team.enabled .Values.team.sharedVolume.enabled }}
    - name: team-shared
      persistentVolumeClaim:
        claimName: {{ include "hermes-agent.team.sharedClaimName" . }}
    {{- end }}
    {{- with .Values.extraVolumes }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with .Values.nodeSelector }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.affinity }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.tolerations }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
