{{/*
Unified chart name.
*/}}
{{- define "aks-3tier-poc.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Unified full name.
*/}}
{{- define "aks-3tier-poc.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "aks-3tier-poc.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Common labels.
*/}}
{{- define "aks-3tier-poc.labels" -}}
app.kubernetes.io/name: {{ include "aks-3tier-poc.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}

{{/*
Global ingress paths.
*/}}
{{- define "aks-3tier-poc.frontendPath" -}}
/
{{- end -}}

{{- define "aks-3tier-poc.apiPath" -}}
/api
{{- end -}}
