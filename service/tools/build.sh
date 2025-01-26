#!/bin/bash

function usage {
cat >&2 <<EOS
[usage]
 $0 [options]

[options]
 -h | --help:
   ヘルプを表示
 --push <STAGE>:
   同時に指定したステージにプッシュを行う
   <STAGE>: pushするステージ名を指定(stg, prd, など)
 --no-cache:
   キャッシュを使わないでビルド

[example]
 ビルドのみを実行する場合
 $0

 本番環境のイメージをpushする場合
 $0 --push prd --no-cache
EOS
exit 1
}


AWS_REGION="ap-northeast-1"
PUSH=
BUILD_OPTIONS="--rm"
args=()
while [ "$#" != 0 ]; do
  case $1 in
    -h | --help ) usage ;;
    --push      ) shift; PUSH="1" ;;
    --no-cache  ) BUILD_OPTIONS="$BUILD_OPTIONS --no-cache" ;;
    -* | --*    ) error "$1 : 不正なオプションです" ;;
    *           ) args+=("$1") ;;
  esac
  shift
done

[ "${#args[@]}" != 0 ] && usage

set -e

cd "${PROJECT_DIR}"

# AWSアカウントIDの取得
AWS_ACCOUNT_ID=$(aws $AWS_PROFILE_OPTION sts get-caller-identity --query 'Account' --output text)
echo "AWS_ACCOUNT_ID: $AWS_ACCOUNT_ID"

#############################
# イメージのbuild
#############################
REMOTE_IMAGE="$(terraform -chdir=${PROJECT_DIR}/terraform/env/helm/prd output -raw tools_ecr)"
VERSION=$(date +"%Y%m%d.%H%M")

# app
docker build $BUILD_OPTIONS \
  -f docker/tools/Dockerfile \
  -t $REMOTE_IMAGE:latest \
  .

# ビルドのみの場合はここで終了
[ -z "$PUSH" ] && exit 0

#############################
# イメージのpush
#############################
# ECRログイン
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# push
docker push ${REMOTE_IMAGE}:latest

echo "イメージのプッシュが完了しました。"
echo "IMAGE_URI: ${REMOTE_IMAGE}:${VERSION} (latest)"