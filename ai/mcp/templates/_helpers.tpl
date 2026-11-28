{{/*
Chart name truncated to 63 chars.
*/}}
{{- define "mcp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name.
If fullnameOverride is set, use it directly.
Otherwise combine release name with chart name (deduplicating when they match).
Truncated to 63 chars per Kubernetes naming constraints.
*/}}
{{- define "mcp.fullname" -}}
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
Chart label value: <name>-<version>
*/}}
{{- define "mcp.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to every resource.
*/}}
{{- define "mcp.labels" -}}
{{ include "mcp.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels used in Deployment matchLabels and Service selectors.
*/}}
{{- define "mcp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mcp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Vault annotations for the Banzai Cloud mutating webhook.
Rendered only when vault.enabled is true and both vault.role and vault.path are provided.
*/}}
{{- define "mcp.vault" -}}
{{- if and .Values.vault.enabled .Values.vault.role .Values.vault.path -}}
vault.security.banzaicloud.io/vault-role: {{ .Values.vault.role | quote }}
vault.security.banzaicloud.io/vault-path: {{ .Values.vault.path | quote }}
{{- end }}
{{- end }}

{{/*
Kubernetes Secret name that External Secrets Operator will populate (envFrom target).
Defaults to chart fullname when externalSecrets.target.name is empty.
*/}}
{{- define "mcp.externalSecretsTargetSecretName" -}}
{{- default (include "mcp.fullname" .) .Values.externalSecrets.target.name | trunc 253 | trimSuffix "-" -}}
{{- end }}

{{/*
Fail when incompatible secrets options are combined. Include from deployment and ExternalSecret templates.
*/}}
{{- define "mcp.validateSecretsInjection" -}}
{{- if and .Values.externalSecrets.enabled .Values.vault.enabled -}}
{{- fail "externalSecrets.enabled and vault.enabled are mutually exclusive; disable one of them." -}}
{{- end -}}
{{- if and .Values.secret.enabled .Values.externalSecrets.enabled -}}
{{- $target := include "mcp.externalSecretsTargetSecretName" . -}}
{{- $full := include "mcp.fullname" . -}}
{{- if eq $target $full -}}
{{- fail "secret.enabled conflicts with externalSecrets when the ESO target Secret name equals the chart fullname; set secret.enabled to false or set externalSecrets.target.name to a different Secret." -}}
{{- end -}}
{{- end -}}
{{- if .Values.externalSecrets.enabled -}}
{{- $_ := required "externalSecrets.secretStoreRef.name is required when externalSecrets.enabled is true" .Values.externalSecrets.secretStoreRef.name -}}
{{- $esoData := .Values.externalSecrets.data | default list -}}
{{- $esoDataFrom := .Values.externalSecrets.dataFrom | default list -}}
{{- if and (eq (len $esoData) 0) (eq (len $esoDataFrom) 0) -}}
{{- fail "externalSecrets.enabled requires externalSecrets.data and/or externalSecrets.dataFrom to be non-empty." -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
ServiceAccount name — uses the override, or falls back to fullname when create=true,
otherwise uses the default ServiceAccount.
*/}}
{{- define "mcp.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "mcp.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Normalize proxy.gateway.outputTransport to the value supergateway expects.
Accepts the legacy "streamable-http" spelling used by the previous gateway package.
*/}}
{{- define "mcp.proxyTransport" -}}
{{- $raw := .Values.proxy.gateway.outputTransport | default "streamableHttp" -}}
{{- $normalized := $raw | lower | replace "-" "" | replace "_" "" -}}
{{- if eq $normalized "streamablehttp" -}}
streamableHttp
{{- else if eq $normalized "sse" -}}
sse
{{- else if eq $normalized "ws" -}}
ws
{{- else -}}
{{- fail (printf "proxy.gateway.outputTransport %q is not supported; use streamableHttp, sse or ws" $raw) -}}
{{- end -}}
{{- end }}

{{/*
Full supergateway command line for proxy mode, rendered as a single shell string.
*/}}
{{- define "mcp.proxyCommand" -}}
{{- $gw := .Values.proxy.gateway -}}
{{- $transport := include "mcp.proxyTransport" . -}}
{{- $stdio := required "proxy.gateway.stdioCommand is required in proxy mode" $gw.stdioCommand -}}
{{- $args := list "npx" "-y" ($gw.package | default "supergateway" | squote) -}}
{{- $args = concat $args (list "--stdio" ($stdio | squote)) -}}
{{- $args = concat $args (list "--outputTransport" $transport) -}}
{{- $args = concat $args (list "--port" ($gw.port | int | toString)) -}}
{{- if eq $transport "streamableHttp" -}}
{{- $args = concat $args (list "--streamableHttpPath" ($gw.httpPath | default "/mcp" | squote)) -}}
{{- if $gw.stateful -}}
{{- $args = concat $args (list "--stateful") -}}
{{- if $gw.sessionTimeout -}}
{{- $args = concat $args (list "--sessionTimeout" ($gw.sessionTimeout | int | toString)) -}}
{{- end -}}
{{- end -}}
{{- else if eq $transport "sse" -}}
{{- $args = concat $args (list "--ssePath" ($gw.httpPath | default "/sse" | squote)) -}}
{{- $args = concat $args (list "--messagePath" ($gw.messagePath | default "/message" | squote)) -}}
{{- if $gw.baseUrl -}}
{{- $args = concat $args (list "--baseUrl" ($gw.baseUrl | squote)) -}}
{{- end -}}
{{- else -}}
{{- $args = concat $args (list "--messagePath" ($gw.messagePath | default "/message" | squote)) -}}
{{- end -}}
{{- if $gw.logLevel -}}
{{- $args = concat $args (list "--logLevel" $gw.logLevel) -}}
{{- end -}}
{{- range $gw.healthEndpoints | default list -}}
{{- $args = concat $args (list "--healthEndpoint" (. | squote)) -}}
{{- end -}}
{{- with $gw.extraArgs -}}
{{- range . -}}
{{- $args = concat $args (list (. | toString | squote)) -}}
{{- end -}}
{{- end -}}
{{- if $gw.cors.enabled -}}
{{- $origins := $gw.cors.origins | default list -}}
{{- if eq (len $origins) 0 -}}
{{- $args = concat $args (list "--cors" "'*'") -}}
{{- else -}}
{{- range $origins -}}
{{- $args = concat $args (list "--cors" (. | squote)) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- join " " $args -}}
{{- end }}
