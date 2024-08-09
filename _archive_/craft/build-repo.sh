#!/bin/bash

set -e -o pipefail

# -- Config --
REPO_ROOT_DIR='/srv/www/repo.vitalvas.com'
REPO_COMPONENT='main'

# -- End Config --

REPO_NAME=$1
TMP_DIR=$(mktemp -d)

function die_var_unset {
    echo "ERROR: Variable '$1' is required to be set."
    exit 1
}

function check_mkdir {
  [ -d "$1" ] || mkdir -p $1
}

function cleanup {
  [ -d "${TMP_DIR}" ] && {
    rm -Rf ${TMP_DIR}
  }
}

trap cleanup EXIT

[ -z "${REPO_NAME}" ] && die_var_unset 'REPO_NAME'
[ -z "${TMP_DIR}" ] && die_var_unset 'TMP_DIR'

[ -d "upload/repo/${REPO_NAME}" ] || {
  echo "Repo ${REPO_NAME} not found"
  exit 1
}

check_mkdir "${REPO_ROOT_DIR}/${REPO_NAME}/deb/${REPO_COMPONENT}"
check_mkdir "${REPO_ROOT_DIR}/${REPO_NAME}/deb/${REPO_COMPONENT}/binary"

for line in $(find upload/repo/${REPO_NAME}/deb/ -type f -name '*.deb'); do
  filename=$(basename -- "$line")
  pkgname=$(echo ${filename} | awk -F'_' '{print $1}')

  check_mkdir "${REPO_ROOT_DIR}/${REPO_NAME}/deb/${REPO_COMPONENT}/binary/${pkgname}"

  [ -f "${REPO_ROOT_DIR}/${REPO_NAME}/deb/${REPO_COMPONENT}/binary/${pkgname}/${filename}" ] || {
    cp ${line} ${REPO_ROOT_DIR}/${REPO_NAME}/deb/${REPO_COMPONENT}/binary/${pkgname}/
  }
done

cat <<EOF>${TMP_DIR}/aptftp.conf
APT::FTPArchive::DoByHash "1";
APT::FTPArchive::Release {
  Origin "${REPO_COMPONENT}";
  Label "${REPO_COMPONENT}";
  Architectures "all amd64";
  Suite "${REPO_COMPONENT}";
  Codename "${REPO_COMPONENT}";
  Acquire-By-Hash true;
  MD5 false;
  SHA1 false;
}
EOF

cat <<EOF>${TMP_DIR}/aptgenerate.conf
Dir {
  ArchiveDir ".";
  CacheDir ".";
}
Default {
  Packages {
    Extensions ".deb";
  };
  Packages::Compress ". gzip";
  Sources::Compress ". gzip";
  Contents::Compress ". gzip";
}
BinDirectory "${REPO_COMPONENT}/binary" {
  BinCacheDB "${REPO_COMPONENT}.db";
  Packages "${REPO_COMPONENT}/Packages";
  Contents "${REPO_COMPONENT}/Contents";
}
EOF

cd ${REPO_ROOT_DIR}/${REPO_NAME}/deb

apt-ftparchive generate -q -c=${TMP_DIR}/aptftp.conf ${TMP_DIR}/aptgenerate.conf

apt-ftparchive release -q -c=${TMP_DIR}/aptftp.conf ${REPO_COMPONENT} \
  | tee ${REPO_ROOT_DIR}/${REPO_NAME}/deb/${REPO_COMPONENT}/Release \
  | gzip -c -9 > ${REPO_ROOT_DIR}/${REPO_NAME}/deb/${REPO_COMPONENT}/Release.gz

apt-ftparchive clean -q -c=${TMP_DIR}/aptftp.conf ${TMP_DIR}/aptgenerate.conf
