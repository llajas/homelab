{{/*
Expand the name of the chart.
*/}}
{{- define "paperless-ai.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "paperless-ai.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "paperless-ai.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "paperless-ai.labels" -}}
helm.sh/chart: {{ include "paperless-ai.chart" . }}
{{ include "paperless-ai.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "paperless-ai.selectorLabels" -}}
app.kubernetes.io/name: {{ include "paperless-ai.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "paperless-ai.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "paperless-ai.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generiert den Inhalt der .env-Datei aus den Werten in .Values.secretEnv
*/}}
{{- define "generateEnv" -}}
{{- if .Values.paperless.apiUrl }}PAPERLESS_API_URL={{ .Values.paperless.apiUrl }}{{ "\n" }}{{- end }}
{{- if .Values.ai.provider }}AI_PROVIDER={{ .Values.ai.provider }}{{ "\n" }}{{- end }}
{{- if .Values.ai.addProcessedTag }}ADD_AI_PROCESSED_TAG={{ .Values.ai.addProcessedTag }}{{ "\n" }}{{- end }}
{{- if .Values.ai.processedTagName }}AI_PROCESSED_TAG_NAME={{ .Values.ai.processedTagName }}{{ "\n" }}{{- end }}
{{- if .Values.ai.initialSetup }}PAPERLESS_AI_INITIAL_SETUP={{ .Values.ai.initialSetup }}{{ "\n" }}{{- end }}
{{- if .Values.prompt.useTags }}USE_PROMPT_TAGS={{ .Values.prompt.useTags }}{{ "\n" }}{{- end }}
{{- if .Values.prompt.tags }}PROMPT_TAGS={{ .Values.prompt.tags }}{{ "\n" }}{{- end }}
{{- if .Values.scanInterval }}SCAN_INTERVAL={{ .Values.scanInterval }}{{ "\n" }}{{- end }}
{{- if .Values.systemPrompt }}SYSTEM_PROMPT=`{{ .Values.systemPrompt }}`{{ "\n" }}{{- end }}
{{- if .Values.processPredefinedDocuments }}PROCESS_PREDEFINED_DOCUMENTS={{ .Values.processPredefinedDocuments }}{{ "\n" }}{{- end }}
TAGS={{ .Values.tags }}{{ "\n" }}
{{- if .Values.openAi.model }}OPENAI_MODEL={{ .Values.openAi.model }}{{ "\n" }}{{- end }}
{{- end }}
