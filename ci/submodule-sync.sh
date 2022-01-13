#!/bin/bash
#
# Copyright (c) 2022, NVIDIA CORPORATION. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -ex

OWNER=${OWNER:-"pxLi"}
REPO=${REPO:-"spark-rapids-jni"}
PARALLEL_LEVEL=${PARALLEL_LEVEL:-4}
REPO_LOC="github.com/${OWNER}/${REPO}.git"

git submodule update --init --recursive

INTERMEDIATE_HEAD=bot-submodule-sync-${REF}
cudf_prev_sha=$(git -C thridparth/cudf rev-parse HEAD)
git checkout -b ${INTERMEDIATE_HEAD} origin/${REF}
git submodule update --remote --merge
cudf_sha=$(git -C thridparth/cudf rev-parse HEAD)
if [[ "${cudf_sha}" == "${cudf_prev_sha}" ]]; then
  echo "Submodule is up to date."
  exit 0
fi

echo "Try update cudf submodule to ${cudf_sha}..."
git add .
git commit -s -m "Update submodule cudf to ${cudf_sha}"
sha=$(git rev-parse HEAD)

set +e
mvn verify \
  -DCPP_PARALLEL_LEVEL=${PARALLEL_LEVEL} \
  -Dlibcudf.build.configure=true \
  -DUSE_GDS=ON
ret="$?"
set -e

test_pass="False"
[[ "${ret}" == "0" ]] && test_pass="True"

git push https://${GIT_USER}:${GIT_PWD}@${REPO_LOC} ${INTERMEDIATE_HEAD}

.github/workflows/action-helper/python/submodule-sync.py \
  --owner=${OWNER} \
  --repo=${REPO} \
  --head=${INTERMEDIATE_HEAD} \
  --base=${REF} \
  --sha=${sha} \
  --cudf_sha=${cudf_sha} \
  --token=${GIT_PWD} \
  --passed ${test_pass}
