{{- define "prefix" -}}
{{- if ne .Release.Name .Values.global.chartName -}}
  {{ .Release.Name | printf "%s-" }}
{{- else -}}
  {{printf "" }}
{{- end -}}
{{- end -}}