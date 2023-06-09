#!/bin/bash

# Configure bash behavior
set -o errexit  # exit on failed command
set -o nounset  # exit on undeclared variables
set -o pipefail # exit on any failed command in pipes

# Verbosity settings
: ${VERBOSE=1}
SH=("/usr/bin/env" "bash")
if [ ${VERBOSE} -ge 2 ]; then
  SH=("${SH[@]}" "-x")
  set -o xtrace
fi

# Set magic variables for current file & dir
__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__FILE="${__DIR}/$(basename "${BASH_SOURCE[0]}")"
__BASE="$(basename ${__FILE} .sh)"
__ROOT="$(cd "$(dirname "${__DIR}")" && pwd)"
__CWD="$(pwd)"

# Prepare temporary files
TMP_OUT="$(mktemp $(basename $0)_out.XXXXXXXXXX)"
TMP_ERR="$(mktemp $(basename $0)_err.XXXXXXXXXX)"

# Make sure they will be deleted
trap "rm -f ${TMP_OUT} ${TMP_ERR}" EXIT

# Test inputs and set some defaults to avoid unbound variable
test -n "${INPUT_SRC}"      # Source directory or URL (e.g.: sftp://<user>:<pass>@<host><path>)
test -n "${INPUT_DST}"      # Destination directory or URL (e.g.: sftp://<user>:<pass>@<host><path>)
: ${INPUT_CONNECT_PROGRAM:=''} # Program to use for connecting (e.g.: ssh i <key> -o StrictHostKeyChecking=no)
: ${INPUT_DELETE:='false'}     # Enable deletion before transfer
: ${INPUT_VERBOSE:='false'}    # Enable verbose logging
: ${INPUT_MIRROR_OPTIONS:=''}  # Extra mirror options (e.g.: --exclude "\.git.*")
: ${INPUT_TIMEOUT:=300}        # Time limit for the completion (seconds)
: ${GITHUB_STEP_SUMMARY:=/dev/stdout}
: ${GITHUB_OUTPUT:=/dev/stdout}

# Enable debug mode if required
LFTP=( 'lftp' )
if [ ${VERBOSE} -ge 2 ]; then
  LFTP=( ${LFTP[@]} '-d' )
fi

# Detect direction from src and dst, then set remote and local var accordingly
if [[ "${INPUT_SRC}" =~ ^((.+)://)([^/]+)(/.+)?$ ]]; then
  REVERSE=false
  LOCAL_DIR="${INPUT_DST}"
  REMOTE_SCHEME="${BASH_REMATCH[2]}"
  REMOTE_HOST="${BASH_REMATCH[3]}"
  REMOTE_DIR="${BASH_REMATCH[4]}"
else
  REVERSE=true
  LOCAL_DIR="${INPUT_SRC}"
  if [[ "${INPUT_DST}" =~ ^((.+)://)([^/]+)(/.+)?$ ]]; then
    REMOTE_SCHEME="${BASH_REMATCH[2]}"
    REMOTE_HOST="${BASH_REMATCH[3]}"
    REMOTE_DIR="${BASH_REMATCH[4]}"
  else
    echo "FAILURE - Failed to parse src or dst" >> "${TMP_ERR}"
    echo ":x: Failed to parse src or dst" >> $GITHUB_STEP_SUMMARY
  fi
fi

# Detect remote user and password
if [[ "${REMOTE_HOST}" =~ ^([^:@]+)(:([^@]+))?@(.+)$ ]]; then
  REMOTE_USER="${BASH_REMATCH[1]}"
  REMOTE_PASS="${BASH_REMATCH[3]}"
  REMOTE_HOST="${BASH_REMATCH[4]}"
else
  echo "FAILURE - Failed to parse remote user or password" >> "${TMP_ERR}"
  echo ":x: Failed to parse remote user or password" >> $GITHUB_STEP_SUMMARY
fi

# Use dummy password if empty
if [ -z "${REMOTE_PASS}" ]; then
  REMOTE_PASS='lftp'
fi

# Prepare commands
CMD=""
# Configure connect program if needed
if [ -n "${INPUT_CONNECT_PROGRAM}" ] && [ "${REMOTE_SCHEME}" = fish -o "${REMOTE_SCHEME}" = sftp ]; then
  CMD="set ${REMOTE_SCHEME}:connect-program ${INPUT_CONNECT_PROGRAM};"
fi
# Open the connection if needed
if [ -n "${REMOTE_SCHEME}" ]; then
  CMD="${CMD} open ${REMOTE_SCHEME}://${REMOTE_USER}:${REMOTE_PASS}@${REMOTE_HOST};"
fi
# Always use mirror command
CMD="${CMD} mirror"
# Add mirror options if needed
if [ "${REVERSE}" = true ]; then
  CMD="${CMD} --reverse"
fi
if [ "${INPUT_DELETE}" = true ]; then
  CMD="${CMD} --delete"
fi
if [ "${INPUT_VERBOSE}" = true ]; then
  CMD="${CMD} --verbose"
fi
if [ -n "${INPUT_MIRROR_OPTIONS}" ]; then
  CMD="${CMD} ${INPUT_MIRROR_OPTIONS}"
fi
# Add paths and quit
if [ "${REVERSE}" = true ]; then
  CMD="${CMD} ${LOCAL_DIR} ${REMOTE_DIR}; quit;"
else
  CMD="${CMD} ${REMOTE_DIR} ${LOCAL_DIR}; quit;"
fi
# Run the command as constructed above
echo ":rocket: Mirroring by lftp has been started" >> $GITHUB_STEP_SUMMARY
timeout -s TERM -k 5s "${INPUT_TIMEOUT}s" \
"${LFTP[@]}" -e "${CMD}" > "${TMP_OUT}" 2> "${TMP_ERR}" && RET=0 || RET=1

# Append some info based on the exit code in result and summary
if [ $RET -eq 0 ]; then
  echo "SUCCESS - Directories have been mirrored" >> "${TMP_ERR}"
  echo ":heavy_check_mark: Directories have been mirrored" >> $GITHUB_STEP_SUMMARY
else
  echo "FAILURE - Directories have NOT been mirrored correctly" >> "${TMP_ERR}"
  echo ":x: Directories have NOT been mirrored correctly" >> $GITHUB_STEP_SUMMARY
fi

# Pass stdout as result output
echo "result<<$(basename "${TMP_OUT}")" >> $GITHUB_OUTPUT
cat "${TMP_OUT}" >> $GITHUB_OUTPUT
echo "$(basename ${TMP_OUT})" >> $GITHUB_OUTPUT

if [ ${INPUT_VERBOSE} = 'true' ]; then
  cat "${TMP_OUT}"
  cat "${TMP_ERR}"
fi

exit ${RET}
