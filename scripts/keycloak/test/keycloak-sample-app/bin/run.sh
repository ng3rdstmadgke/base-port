#!/bin/bash

PROJECT_DIR=$(cd $(dirname $0)/..; pwd)
cd $PROJECT_DIR
poetry install
poetry run uvicorn keycloak_sample_app.main:app --env-file .env --reload