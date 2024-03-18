#!/bin/bash

# Source: https://github.com/vitalvas/stuff

set -e -o pipefail

ROOT_DIR="/opt/aptly"

WORKDIR="${ROOT_DIR}/repos"
UPLOAD="${ROOT_DIR}/upload"
ARCHIVE="${ROOT_DIR}/archive"

/usr/bin/env which aptly >/dev/null 2>&1 || {
  echo "aptly not installed"
  exit 1
}

/usr/bin/env which jq >/dev/null 2>&1 || {
  echo "jq not installed"
  exit 1
}

ARCH="all,amd64,arm64,armel,armhf,i386"
NOW=$(date +'%Y%m%d-%H%M%S')

for REPONAME in $(ls -A ${WORKDIR}); do
  for OSNAME in $(ls -A ${WORKDIR}/${REPONAME}); do
    for OSDIST in $(ls -A ${WORKDIR}/${REPONAME}/${OSNAME}); do
      APTLY_CONF="${WORKDIR}/${REPONAME}/${OSNAME}/${OSDIST}/aptly.conf"

      [ -f "${APTLY_CONF}" ] && {
        APTLY_REPO=${REPONAME}-${OSNAME}-${OSDIST}

        ROOT_DIR=$(/usr/bin/jq -r '.rootDir' ${APTLY_CONF})
        [ ! -d "${ROOT_DIR}" ] && {
          echo "==> creating repository"
          /usr/bin/aptly -config=${APTLY_CONF} repo create \
            -distribution=${OSDIST} \
            -architectures=${ARCH} \
            -comment="APT Repository for ${REPONAME}/${OSNAME}/${OSDIST}" \
            ${APTLY_REPO}
        }

        UPLOAD_PATH="${UPLOAD}/${REPONAME}/${OSNAME}/${OSDIST}"
        [ ! -d "${UPLOAD_PATH}" ] && /usr/bin/mkdir -p ${UPLOAD_PATH}

        DEBS=$(ls -A ${UPLOAD_PATH}/*.deb 2>/dev/null)

        [ ! -z "${DEBS}" ] && {
          /usr/bin/aptly -config=${APTLY_CONF} repo add ${APTLY_REPO} ${DEBS}

          [ ! -d "${ARCHIVE}/${REPONAME}/${OSNAME}/${OSDIST}/${NOW}" ] && {
            /usr/bin/mkdir -p ${ARCHIVE}/${REPONAME}/${OSNAME}/${OSDIST}/${NOW}
          }

          for file in ${DEBS}; do
            /usr/bin/mv ${file} ${ARCHIVE}/${REPONAME}/${OSNAME}/${OSDIST}/${NOW}/
          done

          SNAPSHOT=${APTLY_REPO}-${NOW}

          echo "==> creating snapshot"
          /usr/bin/aptly -config=${APTLY_CONF} snapshot create ${SNAPSHOT} from repo ${APTLY_REPO}

          [ ! -z "$(/usr/bin/grep 'FileSystemPublishEndpoints' ${APTLY_CONF})" ] && {
            for name in $(/usr/bin/jq -r '.FileSystemPublishEndpoints | to_entries | .[] | .key' ${APTLY_CONF}); do
              PREFIX=${REPONAME}/${OSNAME}/${OSDIST}
              ENDPOINT="filesystem:${name}:${PREFIX}"

              [ ! -z "$(/usr/bin/aptly -config=${APTLY_CONF} publish list -raw | /usr/bin/grep ${ENDPOINT})" ] && {
                echo "==> dropping published snapshot from ${ENDPOINT}"
                /usr/bin/aptly -config=${APTLY_CONF} publish drop ${OSDIST} ${ENDPOINT}
              }

              echo "==> publishing snapshot to ${ENDPOINT}"
              /usr/bin/aptly -config=${APTLY_CONF} publish snapshot -architectures=${ARCH} ${SNAPSHOT} ${ENDPOINT}
            done
          }

          [ ! -z "$(/usr/bin/grep 'S3PublishEndpoints' ${APTLY_CONF})" ] && {
            for name in $(/usr/bin/jq -r '.S3PublishEndpoints | to_entries | .[] | .key' ${APTLY_CONF}); do
              PREFIX=${REPONAME}/${OSNAME}/${OSDIST}
              ENDPOINT="s3:${name}:${PREFIX}"

              [ ! -z "$(/usr/bin/aptly -config=${APTLY_CONF} publish list -raw | /usr/bin/grep ${ENDPOINT})" ] && {
                echo "==> dropping published snapshot from ${ENDPOINT}"
                /usr/bin/aptly -config=${APTLY_CONF} publish drop ${OSDIST} ${ENDPOINT}
              }

              echo "==> publishing snapshot to ${ENDPOINT}"
              /usr/bin/aptly -config=${APTLY_CONF} publish snapshot -architectures=${ARCH} ${SNAPSHOT} ${ENDPOINT}
            done
          }
        }
      }
    done
  done
done

/usr/bin/find ${ARCHIVE} -type d -empty -delete
