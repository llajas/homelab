{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "hytale.name" -}}
{{- $nameOverride := (and .Values (get .Values "nameOverride")) }}
{{- default .Chart.Name $nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Set the chart fullname
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the labels spec).
We change "+" with "_" for OCI compatibility
*/}}
{{- define "chart.fullname" -}}
{{- printf "%s-%s" .Chart.Name (.Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-") -}}
{{- end }}

{{/*
Set the chart version
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the labels spec).
We change "+" with "_" for OCI compatibility
*/}}
{{- define "chart.version" -}}
{{- default .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "hytale.fullname" -}}
{{- if and .Values (hasKey .Values "fullnameOverride") .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name (and .Values (get .Values "nameOverride")) }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "hytale.envMap" }}
{{- if ne (toString (index . 1)) "default" }}
{{- if or (index . 1) (kindIs "float64" (index . 1)) (kindIs "bool" (index . 1)) }}
        - name: {{ index . 0 }}
          value: {{ index . 1 | quote }}
{{- end }}
{{- end }}
{{- end }}
