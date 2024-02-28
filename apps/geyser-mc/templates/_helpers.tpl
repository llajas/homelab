{{/* Create a default fully qualified app name. */}}
{{- define "geysermc.fullname" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Generate basic labels */}}
{{- define "geysermc.labels" -}}
app.kubernetes.io/name: {{ include "geysermc.name" . }}
helm.sh/chart: {{ include "geysermc.chart" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Selector labels */}}
{{- define "geysermc.selectorLabels" -}}
app.kubernetes.io/name: {{ include "geysermc.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* Chart name and version */}}
{{- define "geysermc.chart" -}}
{{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end }}

{{/* Application name */}}
{{- define "geysermc.name" -}}
{{- default .Chart.Name .Values.nameOverride }}
{{- end }}
