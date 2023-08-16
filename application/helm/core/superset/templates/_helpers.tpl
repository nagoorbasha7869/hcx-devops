{{/*

 Licensed to the Apache Software Foundation (ASF) under one or more
 contributor license agreements.  See the NOTICE file distributed with
 this work for additional information regarding copyright ownership.
 The ASF licenses this file to You under the Apache License, Version 2.0
 (the "License"); you may not use this file except in compliance with
 the License.  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.

*/}}
{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "superset.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "superset.fullname" -}}
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
Create the name of the service account to use
*/}}
{{- define "superset.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "superset.fullname" .) .Values.serviceAccountName -}}
{{- else -}}
{{- default "default" .Values.serviceAccountName -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "superset.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "superset-config" }}
from flask_appbuilder.security.manager import AUTH_OID
from keycloak_security_manager import OIDCSecurityManager
import os
from cachelib.redis import RedisCache
from my_security_manager import CustomSecurityManager

import requests

user_search_url = '{{ .Values.hcx_url }}/api/{{ .Values.api_version }}/user/search'
participant_search_url = '{{ .Values.hcx_url }}/api/{{ .Values.api_version }}/participant/search'
token_url = '{{ .Values.hcx_url }}/api/{{ .Values.api_version }}/participant/auth/token/generate'


def get_participant_emails(user_id):
    token_headers = {
      'content-type': 'application/x-www-form-urlencoded'
    }

    token_body = {
      'username': '{{ .Values.hcx_admin_username }}',
      'password': '{{ .Values.hcx_admin_password }}'
    }

    keycloak_response = requests.post(url=token_url, headers=token_headers, data=token_body)
        
    access_token = ''
    if keycloak_response.status_code == 200:
        response_data = keycloak_response.json()
        access_token = f"Bearer {response_data.get('access_token')}" 
    else:
        print(f"Not able to generate keycloak token, status code: {keycloak_response.status_code}")
        print(keycloak_response.text)
    
    headers = {
      'Content-Type': 'application/json',
      'Authorization': access_token
    }

    data = {
      "filters": {
            "user_id": {
               "eq": user_id
        }
      } 
    }

    print("User Request Body: ", data)

    response = requests.post(url=user_search_url, headers=headers, json=data)
    if response.status_code == 200:
        result = response.json()
        print("User Search Results",result)  

        participant_codes_list = []
        users = result.get('users', [])
        for user in users:
            tenant_roles = user.get('tenant_roles', [])
            codes = [tenant['participant_code'] for tenant in tenant_roles]
            participant_codes_list.extend(codes)  # Append roles to the list

        print("Participant Codes:", participant_codes_list)
        return get_emails(participant_codes_list,headers)
    else:
        print(f"Request failed with status code: {response.status_code}")
        print(response.text)

def get_emails(participant_codes_list,headers):
    participant_request_filters = {
          "filters": {
            "participant_code": {
               "or": participant_codes_list
          }
       } 
    }
    
    print("Participant request ", participant_request_filters)
    participant_response = requests.post(url=participant_search_url, headers=headers, json=participant_request_filters)
    print("participant status ",participant_response.status_code)
    if participant_response.status_code == 200:
        participant_result = participant_response.json()
        participants = participant_result.get('participants', [])
        primary_emails = [participant.get('primary_email', None) for participant in participants]
        print("Participant emails ", primary_emails)
        email_string = "','".join(primary_emails)
        return email_string
    else:
        print(f"Participant Search Request failed with status code: {response.status_code}")
        print(response.text)   


JINJA_CONTEXT_ADDONS = {
    "get_participant_emails": get_participant_emails
}

ENABLE_CORS = True
CORS_OPTIONS = {
    'supports_credentials': True,
    'allow_headers': ['*'],
    'resources':['*'],
    'origins': ['*'],
}
ENABLE_PROXY_FIX = True
PUBLIC_ROLE_LIKE_GAMMA = True
SESSION_COOKIE_SAMESITE = "None"
SESSION_COOKIE_SECURE = True 
SESSION_COOKIE_HTTPONLY = True
def env(key, default=None):
    return os.getenv(key, default)

MAPBOX_API_KEY = env('MAPBOX_API_KEY', '')
CACHE_CONFIG = {
      'CACHE_TYPE': 'redis',
      'CACHE_DEFAULT_TIMEOUT': 300,
      'CACHE_KEY_PREFIX': 'superset_',
      'CACHE_REDIS_HOST': env('REDIS_HOST'),
      'CACHE_REDIS_PORT': env('REDIS_PORT'),
      'CACHE_REDIS_PASSWORD': env('REDIS_PASSWORD'),
      'CACHE_REDIS_DB': env('REDIS_DB', 1),
}
DATA_CACHE_CONFIG = CACHE_CONFIG

SQLALCHEMY_DATABASE_URI = f"postgresql+psycopg2://{env('DB_USER')}:{env('DB_PASS')}@{env('DB_HOST')}:{env('DB_PORT')}/{env('DB_NAME')}"
SQLALCHEMY_TRACK_MODIFICATIONS = True
SECRET_KEY = env('SECRET_KEY', 'thisISaSECRET_1234')

TALISMAN_CONFIG = {
"content_security_policy": "None",
"force_https": False,
"force_https_permanent": False,
}
CSRF_ENABLED = False
# Flask-WTF flag for CSRF
WTF_CSRF_ENABLED = False
# Add endpoints that need to be exempt from CSRF protection
WTF_CSRF_EXEMPT_LIST = []
# A CSRF token that expires in 1 year
WTF_CSRF_TIME_LIMIT = 60 * 60 * 24 * 365
class CeleryConfig(object):
  CELERY_IMPORTS = ('superset.sql_lab', )
  CELERY_ANNOTATIONS = {'tasks.add': {'rate_limit': '10/s'}}
{{- if .Values.supersetNode.connections.redis_password }}
  BROKER_URL = f"redis://:{env('REDIS_PASSWORD')}@{env('REDIS_HOST')}:{env('REDIS_PORT')}/0"
  CELERY_RESULT_BACKEND = f"redis://:{env('REDIS_PASSWORD')}@{env('REDIS_HOST')}:{env('REDIS_PORT')}/0"
{{- else }}
  BROKER_URL = f"redis://{env('REDIS_HOST')}:{env('REDIS_PORT')}/0"
  CELERY_RESULT_BACKEND = f"redis://{env('REDIS_HOST')}:{env('REDIS_PORT')}/0"
{{- end }}

CELERY_CONFIG = CeleryConfig
RESULTS_BACKEND = RedisCache(
      host=env('REDIS_HOST'),
{{- if .Values.supersetNode.connections.redis_password }}
      password=env('REDIS_PASSWORD'),
{{- end }}
      port=env('REDIS_PORT'),
      key_prefix='superset_results'
)
# OIDC config
#AUTH_TYPE = AUTH_OID
OIDC_CLIENT_SECRETS = '/app/pythonpath/client_secret.json'
OIDC_ID_TOKEN_COOKIE_SECURE = False
OIDC_REQUIRE_VERIFIED_EMAIL = False
OIDC_OPENID_REALM = env('OIDC_OPENID_REALM')
# OIDC_INTROSPECTION_AUTH_METHOD = 'client_secret_post'
CUSTOM_SECURITY_MANAGER = CustomSecurityManager
AUTH_USER_REGISTRATION = True
AUTH_USER_REGISTRATION_ROLE = 'Gamma'
APP_NAME = env('APP_NAME')
{{ if .Values.configOverrides }}
# Overrides
{{- range $key, $value := .Values.configOverrides }}
# {{ $key }}
{{ tpl $value $ }}
{{- end }}
{{- end }}
{{ if .Values.configOverridesFiles }}
# Overrides from files
{{- $files := .Files }}
{{- range $key, $value := .Values.configOverridesFiles }}
# {{ $key }}
{{ $files.Get $value }}
{{- end }}
{{- end }}

{{- end }}
