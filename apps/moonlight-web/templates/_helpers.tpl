{{- define "moonlight-web.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "moonlight-web.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "moonlight-web.name" . -}}
{{- end -}}
{{- end -}}

{{- define "moonlight-web.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride -}}
{{- end -}}

{{- define "moonlight-web.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "moonlight-web.labels" -}}
helm.sh/chart: {{ include "moonlight-web.chart" . }}
app.kubernetes.io/name: {{ include "moonlight-web.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "moonlight-web.selectorLabels" -}}
app.kubernetes.io/name: {{ include "moonlight-web.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "moonlight-web.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "moonlight-web.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "moonlight-web.turnSecretName" -}}
{{- if .Values.turn.existingSecret -}}
{{- .Values.turn.existingSecret -}}
{{- else -}}
{{- .Values.turn.onePasswordItem.secretName -}}
{{- end -}}
{{- end -}}

{{- define "moonlight-web.pvcName" -}}
{{- if .Values.persistence.existingClaim -}}
{{- .Values.persistence.existingClaim -}}
{{- else -}}
{{- printf "%s-config" (include "moonlight-web.fullname" .) -}}
{{- end -}}
{{- end -}}
