# templates/_helpers.tpl

{{- define "monero-operator.name" -}}
{{ .Chart.Name }}
{{- end -}}

{{- define "monero-operator.labels" -}}
app.kubernetes.io/name: {{ include "monero-operator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
