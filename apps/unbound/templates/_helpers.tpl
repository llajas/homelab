{{/* vim: set filetype=mustache: */}}
{{/*

{{/*
Expand the name of the chart.
*/}}
{{- define "unbound.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a fully qualified app name
*/}}
{{- define "unbound.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "unbound.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "unbound.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
app.kubernetes.io/name: {{ template "unbound.name" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
helm.sh/chart: {{ template "unbound.chart" .  }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "unbound.selectorLabels" -}}
app.kubernetes.io/name: {{ template "unbound.name" . }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
{{- end -}}


{{/*
Pdb apiVersion according k8s version and capabilities
*/}}
{{- define "unbound.pdb.apiVersion" -}}
{{- if and (.Capabilities.APIVersions.Has "policy/v1") (semverCompare ">=1.21-0" .Capabilities.KubeVersion.GitVersion) -}}
policy/v1
{{- else -}}
policy/v1beta1
{{- end }}
{{- end -}}
