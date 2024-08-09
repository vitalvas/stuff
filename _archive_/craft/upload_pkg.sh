#!/bin/bash

# --- 
# Upload package to Craft
# Example: ./upload_pkg.sh demo package_1.0.0_all.deb
# ---

set -e -o pipefail

function die_var_unset {
    echo "ERROR: Variable '$1' is required to be set."
    exit 1
}

REPO=$1
NAME=$2

[ -z "${REPO}" ] && die_var_unset 'REPO'
[ -z "${NAME}" ] && die_var_unset 'NAME'

sysdomain='craft.vitalvas.com'

extension="${NAME##*.}"

[ "${extension}" == "deb" ] || {
    echo "Unsupported package type: ${extension}"
    exit 1
}

pkgname=$(echo ${NAME} | awk -F'_' '{print $1}')

curl --user ${CRAFT_USER_NAME}:${CRAFT_USER_PASS} --silent --fail --upload-file ${NAME} \
    https://${sysdomain}/upload/repo/${REPO}/${extension}/${pkgname}/${NAME}
