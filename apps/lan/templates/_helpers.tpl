{{- define "lab-access.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "lab-access.fullname" -}}
{{- printf "%s" (include "lab-access.name" .) -}}
{{- end }}
