#!/bin/bash
# Builds GDart (jConstraints, verifier stub, SPouT, DSE) from the submodules and sets up the tool directory
# (this directory: run-gdart.sh, executor.sh, jdk, version.txt) as in the SV-COMP archive.
#
# usage: git submodule update --init && ./compile-all.sh
#
# Requirements: git, python3, a C toolchain (Xcode command line tools / build-essential, zlib), cmake,
# maven >= 3.9, JDK 17 (JDK17_HOME, or found automatically). Network access (GitHub, JitPack, Maven Central,
# the labsjdk download of mx). Every step is skipped if its result exists, so the script can be restarted.
#
# For the SV-COMP archive, copy the directory without the sources; from SPouT only
# SPouT/espresso/mxbuild/<platform>/ESPRESSO_NATIVE_STANDALONE is needed, and jdk must be a copy (cp -rL).
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$ROOT"
MX_VERSION=7.54.5
LOGS=$ROOT/build-logs
mkdir -p "$LOGS"

log() { echo "$(date +%H:%M:%S) $*"; }
step() {  # name, command...: runs the command with its output in build-logs/<name>.log
    local name=$1; shift
    local start=$(date +%s)
    log "$name ..."
    if ! ( "$@" ) > "$LOGS/$name.log" 2>&1; then
        log "$name FAILED, see $LOGS/$name.log:"; tail -20 "$LOGS/$name.log"; exit 1
    fi
    log "$name done ($(( $(date +%s) - start )) s)"
}

for m in jconstraints dse SPouT verifier-stub; do
    [[ -e $m/.git ]] || { echo "submodule $m missing: git submodule update --init"; exit 1; }
done

# --- JDK 17 (maven, DSE, compiling the programs) -----------------------------------------------------------
if [[ -z "${JDK17_HOME:-}" ]]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        JDK17_HOME=$(/usr/libexec/java_home -v 17 2>/dev/null || true)
    else
        for j in /usr/lib/jvm/java-17-openjdk-* /usr/lib/jvm/temurin-17-*; do
            [[ -x $j/bin/javac ]] && { JDK17_HOME=$j; break; }
        done
    fi
fi
[[ -x "${JDK17_HOME:-}/bin/javac" ]] || { echo "JDK 17 not found: set JDK17_HOME"; exit 1; }
log "JDK 17: $JDK17_HOME"

# --- mx (GraalVM build tool) and labsjdk 25 with JVMCI (SPouT) ----------------------------------------------
if [[ ! -d mx ]]; then
    step mx bash -c "git clone -q https://github.com/graalvm/mx.git && cd mx && git checkout -q $MX_VERSION && \
        python3 '$ROOT/update_common.py' common.json && python3 '$ROOT/update_common.py' jdk-binaries.json"
fi
export PATH=$ROOT/mx:$PATH
if ! ls -d "$ROOT"/labsjdk-gdart* >/dev/null 2>&1; then
    step labsjdk bash -c "yes | mx fetch-jdk --strip-contents-home --to '$ROOT' labsjdk-gdart"
fi
LABSJDK=$(ls -d "$ROOT"/labsjdk-gdart* | head -1)
log "labsjdk: $LABSJDK"
if [[ ! -d envs/mx_env ]]; then
    step python-env bash -c "python3 -m venv envs/mx_env && envs/mx_env/bin/pip install -q ninja_syntax"
fi

# --- builds --------------------------------------------------------------------------------------------------
export JAVA_HOME=$JDK17_HOME
# jConstraints into ~/.m2 (DSE depends on it); the jSMTLIB dependency comes from JitPack
step jconstraints bash -c "cd jconstraints && ./gradlew publishToMavenLocal -x test"
[[ -f verifier-stub/target/verifier-stub-1.0.jar ]] || step verifier-stub bash -c "cd verifier-stub && mvn -q package"

# SPouT: native standalone of Espresso with the concolic analyses (the long step: 20-60 min)
if ! ls -d SPouT/espresso/mxbuild/*/ESPRESSO_NATIVE_STANDALONE/bin/java >/dev/null 2>&1; then
    step spout bash -c "source envs/mx_env/bin/activate && cd SPouT/espresso && \
        mx --java-home '$LABSJDK' --env native-ce build"
fi

# DSE: OPAL analyzes the JDK classes from the java.base.jmod of the JDK that SPouT runs (Java 25)
mkdir -p dse/src/main/resources/jmods
cp "$LABSJDK/jmods/java.base.jmod" dse/src/main/resources/jmods/
step dse bash -c "cd dse && mvn -q -DskipTests package"

# --- the tool directory --------------------------------------------------------------------------------------
ln -sfn "$JDK17_HOME" jdk
echo "$(git -C SPouT log -1 --format=%h)-$(git -C dse log -1 --format=%h)" > version.txt
log "built GDart $(cat version.txt); run: ./run-gdart.sh <property.prp> <input dir> ..."
