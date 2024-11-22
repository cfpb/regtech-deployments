{{/*
Expand the name of the chart.
*/}}
{{- define "regtech-api.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "regtech-api.fullname" -}}
{{- if .Values.fullnameOverride }}
  {{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
  {{- $name := default .Chart.Name .Values.nameOverride }}
  {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "regtech-api.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "regtech-api.labels" -}}
helm.sh/chart: {{ include "regtech-api.chart" . }}
{{ include "regtech-api.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/name: {{ include "regtech-api.fullname" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: regtech-sbl
{{- end }}

{{/*
Selector labels
*/}}
{{- define "regtech-api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "regtech-api.fullname" . }}
app.kubernetes.io/instance: regtech-sbl
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "regtech-api.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "regtech-api.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


{{/*
Decide if this is a regtech-sbl release, and if not, prepend the release name.

This is used for mapping host names to determine if the mapping should be 
created with a release specific host URL, or with the default/normal one.
This will allow releases to deployed that have a separate "path" without 
impacting other releases.
*/}}
{{- define "prefix" -}}
{{- if ne .Release.Name "regtech-sbl" -}}
{{- .Release.Name | printf "%s-" -}}
{{- else -}}
{{- printf "" -}}
{{- end -}}
{{- end -}}