{{/*
Expand the name of the chart.
*/}}
{{- define "regtech-frontend.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "regtech-frontend.fullname" -}}
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
{{- define "regtech-frontend.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "regtech-frontend.labels" -}}
helm.sh/chart: {{ include "regtech-frontend.chart" . }}
{{ include "regtech-frontend.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/name: {{ include "regtech-frontend.fullname" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: regtech-sbl
{{- end }}

{{/*
Selector labels
*/}}
{{- define "regtech-frontend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "regtech-frontend.fullname" . }}
app.kubernetes.io/instance: regtech-sbl
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "regtech-frontend.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "regtech-frontend.fullname" .) .Values.serviceAccount.name }}
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

{{/*
Decide if to prepend the release name to the API URLs defined in the
frontend configmap.  This will check if there is a global value defined,
and if so, if that does not equal the release name.  If so, prepend the release
name to the API urls.  If those conditions aren't met, don't prepend.  

This will allow a frontend developer to deploy their own release of the frontend
helm chart but still have their own version of the frontend talk to the normal/default
endpoints of the backend APIs.  This also allows someone to run a release of the
umbrella chart to deploy all the things, but with endpoints with their release name
prepended, providing an isolated path through the whole system without impacting other
releases.
*/}}
{{- define "apiPrefix" -}}
{{- if and .Values.global (ne .Release.Name .Values.global.chartName) }}
{{- .Release.Name | printf "%s-" -}}
{{- else -}}
{{- printf "" -}}
{{- end -}}
{{- end -}}