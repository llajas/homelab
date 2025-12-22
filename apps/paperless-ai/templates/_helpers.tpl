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
{{- if .Values.ollama.apiUrl }}OLLAMA_API_URL={{ .Values.ollama.apiUrl }}{{ "\n" }}{{- end }}
{{- if .Values.ollama.model }}OLLAMA_MODEL={{ .Values.ollama.model }}{{ "\n" }}{{- end }}
{{/* External API Configuration - required by app even if disabled */}}
EXTERNAL_API_ENABLED={{ .Values.externalApi.enabled | default "no" }}{{ "\n" }}
{{- if .Values.externalApi.url }}EXTERNAL_API_URL={{ .Values.externalApi.url }}{{ "\n" }}{{- end }}
{{- if .Values.externalApi.method }}EXTERNAL_API_METHOD={{ .Values.externalApi.method }}{{ "\n" }}{{- end }}
{{- if .Values.externalApi.headers }}EXTERNAL_API_HEADERS={{ .Values.externalApi.headers }}{{ "\n" }}{{- end }}
{{- if .Values.externalApi.body }}EXTERNAL_API_BODY={{ .Values.externalApi.body }}{{ "\n" }}{{- end }}
{{- if .Values.externalApi.timeout }}EXTERNAL_API_TIMEOUT={{ .Values.externalApi.timeout }}{{ "\n" }}{{- end }}
{{- if .Values.externalApi.transform }}EXTERNAL_API_TRANSFORM={{ .Values.externalApi.transform }}{{ "\n" }}{{- end }}
{{/* AI Restriction settings */}}
RESTRICT_TO_EXISTING_TAGS={{ .Values.ai.restrictToExistingTags | default "no" }}{{ "\n" }}
RESTRICT_TO_EXISTING_CORRESPONDENTS={{ .Values.ai.restrictToExistingCorrespondents | default "no" }}{{ "\n" }}
RESTRICT_TO_EXISTING_DOCUMENT_TYPES={{ .Values.ai.restrictToExistingDocumentTypes | default "no" }}{{ "\n" }}
{{/* Limit functions */}}
ACTIVATE_TAGGING={{ .Values.ai.activateTagging | default "yes" }}{{ "\n" }}
ACTIVATE_CORRESPONDENTS={{ .Values.ai.activateCorrespondents | default "yes" }}{{ "\n" }}
ACTIVATE_DOCUMENT_TYPE={{ .Values.ai.activateDocumentType | default "yes" }}{{ "\n" }}
ACTIVATE_TITLE={{ .Values.ai.activateTitle | default "yes" }}{{ "\n" }}
ACTIVATE_CUSTOM_FIELDS={{ .Values.ai.activateCustomFields | default "yes" }}{{ "\n" }}
{{/* Other settings */}}
{{- if .Values.tokenLimit }}TOKEN_LIMIT={{ .Values.tokenLimit }}{{ "\n" }}{{- end }}
{{- if .Values.responseTokens }}RESPONSE_TOKENS={{ .Values.responseTokens }}{{ "\n" }}{{- end }}
{{- if .Values.disableAutomaticProcessing }}DISABLE_AUTOMATIC_PROCESSING={{ .Values.disableAutomaticProcessing }}{{ "\n" }}{{- end }}
{{- if .Values.useExistingData }}USE_EXISTING_DATA={{ .Values.useExistingData }}{{ "\n" }}{{- end }}
{{- end }}
