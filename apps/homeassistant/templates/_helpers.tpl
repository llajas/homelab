{{/*
Allow the release namespace to be overridden.
*/}}
{{- define "home-assistant.namespace" -}}
  {{- if .Values.namespaceOverride -}}
    {{- .Values.namespaceOverride -}}
  {{- else -}}
    {{- .Release.Namespace -}}
  {{- end -}}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "home-assistant.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "home-assistant.fullname" -}}
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
Create chart name and version.
*/}}
{{- define "home-assistant.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "home-assistant.selectorLabels" -}}
app.kubernetes.io/name: {{ include "home-assistant.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "home-assistant.labels" -}}
{{- $labels := dict -}}
{{- $labels = mergeOverwrite $labels (include "home-assistant.selectorLabels" . | fromYaml) -}}
{{- $labels = mergeOverwrite $labels (dict "helm.sh/chart" (include "home-assistant.chart" .)) -}}
{{- if .Chart.AppVersion -}}
{{- $labels = mergeOverwrite $labels (dict "app.kubernetes.io/version" .Chart.AppVersion) -}}
{{- end -}}
{{- $labels = mergeOverwrite $labels (dict "app.kubernetes.io/managed-by" .Release.Service) -}}
{{- with .Values.commonLabels -}}
{{- $labels = mergeOverwrite $labels . -}}
{{- end -}}
{{- toYaml $labels -}}
{{- end -}}

{{/*
Pod labels.
*/}}
{{- define "home-assistant.podLabels" -}}
{{- $labels := dict -}}
{{- $labels = mergeOverwrite $labels (include "home-assistant.labels" . | fromYaml) -}}
{{- $labels = mergeOverwrite $labels (include "home-assistant.selectorLabels" . | fromYaml) -}}
{{- toYaml $labels -}}
{{- end }}

{{/*
Service account name.
*/}}
{{- define "home-assistant.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "home-assistant.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Validate HTTPRoute configuration.
*/}}
{{- define "home-assistant.validateHTTPRoute" -}}
{{- if and .Values.httpRoute.enabled (not .Values.httpRoute.parentRefs) -}}
{{- fail "httpRoute.enabled is true but httpRoute.parentRefs is empty; set at least one parentRef so the HTTPRoute attaches to a Gateway" -}}
{{- end -}}
{{- end -}}

{{/*
Validate controller type.
*/}}
{{- define "home-assistant.validateController" -}}
{{- if ne .Values.controller.type "Deployment" -}}
{{- fail "controller.type must be 'Deployment' for this chart variant" -}}
{{- end -}}
{{- end -}}
