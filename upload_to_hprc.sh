
set -euo pipefail

SUBMISSION_ID="8A3BE2F8-37EE-4D50-9173-15A493A386D8"
SUBMISSION_NAME="HPRC_Y1_QC_NUCFLAG"
INPUT_DIR="/project/logsdon_shared/projects/HPRC/NucFlag-HPRC-release1/results/nucflag/final"

ssds staging upload \
--submission-id "${SUBMISSION_ID}" \
--name "${SUBMISSION_NAME}" \
"${INPUT_DIR}"
