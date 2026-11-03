#!/bin/bash
# Copyright (C) 2025, Automated Quality Assurance Group,
# TU Dortmund University, Germany, together with
# Reliable Software and Distributed Systems Group,
# Bergische Universität Wuppertal, Germany.
# All rights reserved.
#
# run-gdart.sh is licensed under the Apache License,
# Version 2.0 (the "License"); you may not use this file except in compliance
# with the License. You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0.
#
# Unless required by applicable law or agreed to in writing, software distributed
# under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, either express or implied. See the License for the
# specific language governing permissions and limitations under the License.

SV_COMP_MODE=1

OFFSET=$(dirname $BASH_SOURCE[0])
# DSE configuration of the 2026-10 evaluation (strings, heap model, arrays):
# - Z3 (jconstraints lifts int/char comparisons over string lengths and indices to the integer domain;
#   z3.javaStrings=true is the default of DSE), no incremental solving, 10 s per query (DONT_KNOW after that)
# - BFS (the 2026 script misspelled the option as dse.eplore, which meant DFS)
# - incremental constructor summaries
# - DSE stops on its own before the CPU limit of 900 s (the executor uses several cores, CPU time grows faster
#   than wall time), so that the decision tree and the witness are still written
# - no bounded solving (dse.bounds) for now
# - the analysis of the errors of constructors (OPAL, follows calls into the JDK) stops after GDART_ERRORS_BUDGET
#   seconds (default 60) and approximates the rest by declared exceptions
# - GDART_OPAL_THREADS: number of threads of OPAL (default: OPAL's choice); GDART_DSE_JVM_OPTS: options of DSE's JVM
SOLVER_FLAGS="-Ddse.witness=true -Ddse.dp=z3 -Ddse.dp.incremental=false -Ddse.dp.timeout=10 -Ddse.explore=BFS -Ddse.summaries.mode=incremental -Ddse.timeout=${GDART_TIMEOUT:-600} -Ddse.b64encode=true -Djconstraints.multi=disableUnsatCoreChecking=true -Dtaint.flow=OFF -Ddse.errors.timeBudget=${GDART_ERRORS_BUDGET:-60}"
if [[ -z "$OFFSET" ]]; then
    OFFSET="."
fi

sha=$(cat ${OFFSET}/version.txt)

property=$1

if [ "$property" == "-v" ]; then
  echo "gdart-0.1-$sha"
  exit
fi

if [ "$property" == "--version" ]; then
  echo "gdart-0.1-$sha"
  exit
fi

ASSERTION=$(cat $property | grep assert)
EXCEPTION=$(cat $property | grep RuntimeException)

if [[ -z $ASSERTION ]] && [[ -z $EXCEPTION ]]; then
    echo "Unknown property, cannot analyze this!"
    exit 127
fi

if [[ ! -z $ASSERTION ]]; then
      echo "Adding assumption flag"
    SOLVER_FLAGS+=" -Ddse.terminate.on=assertion"
fi

if [[ ! -z $EXCEPTION ]]; then
    echo "Adding error flag"
    SOLVER_FLAGS+=" -Ddse.terminate.on=error"
fi

path=`pwd`

shift
# classpath=$OFFSET
workdir=$(mktemp -d)
classpath=$workdir
trap 'rm -rf "$workdir"' EXIT  # also when the run is interrupted

mainclass=""
for folder in $@; do
  cp -a $folder/* $classpath/
done
cp -a $OFFSET/verifier-stub/target/verifier-stub-1.0.jar $classpath/

if [[ -n $(find $classpath |grep Main.java) ]]; then
  mainclass=$(find $classpath |grep Main.java)
fi
echo $classpath
if [[ "$OSTYPE" == "darwin"* ]]; then
  # all classes of the SV-COMP API (Verifier, ObjectFactory, *) from the verifier stub of GDart
  find $classpath -name "*.java" -exec sed -i "" -e "s/org\.sosy_lab\.sv_benchmarks\./tools.aqua.concolic./g" {} \;;
else
  find $classpath -name "*.java" -exec sed -i "s/org\.sosy_lab\.sv_benchmarks\./tools.aqua.concolic./g" {} \;;
fi

if [[ -z $mainclass ]]; then
  echo "Could not find main class to execute program"
  echo "== DONT-KNOW"
  exit 1
fi
classpath="$classpath:$classpath/verifier-stub-1.0.jar"
echo "computed classpath: $classpath"
echo "found main class: $mainclass"

# SPouT (Espresso native standalone, JDK 25) runs the program (executor.sh); its java runs Espresso only.
# DSE and javac run on a regular JDK (17) in $OFFSET/jdk (a JDK home or a macOS bundle).
JDK_HOME=$OFFSET/jdk
if [[ -x $OFFSET/jdk/Contents/Home/bin/java ]]; then
    JDK_HOME=$OFFSET/jdk/Contents/Home  # a macOS JDK bundle
fi
JAVA=$JDK_HOME/bin/java
JAVAC=$JDK_HOME/bin/javac

DSE_JVM_OPTS="${GDART_DSE_JVM_OPTS:-}"
if [[ -n "${GDART_OPAL_THREADS:-}" ]]; then
    DSE_JVM_OPTS+=" -Dorg.opalj.threads.CPUBoundTasks=$GDART_OPAL_THREADS -Dorg.opalj.threads.IOBoundTasks=$GDART_OPAL_THREADS"
fi

echo "Env. Info ---------------------------------------------"
mpath=$(dirname $mainclass)
$JAVA -version
$JAVAC -version
ls -lah $mpath
echo "-------------------------------------------------------"

echo "$(date +%T) compiling: $JAVAC -nowarn --release 11 -cp $classpath $mainclass"
$JAVAC -nowarn --release 11 -cp $classpath $mainclass
if [[ $? -ne 0 ]]; then
  echo "Could not compile main class"
  echo "== DONT-KNOW"
  exit 1
fi

echo "$(date +%T) invoke DSE: $JAVA -cp $OFFSET/dse/target/dse-0.0.1-SNAPSHOT-jar-with-dependencies.jar tools.aqua.dse.DSELauncher $SOLVER_FLAGS -Ddse.executor=$OFFSET/executor.sh -Ddse.executor.args=\"-cp $classpath Main\" -Ddse.sources=$classpath"
$JAVA $DSE_JVM_OPTS -cp $OFFSET/dse/target/dse-0.0.1-SNAPSHOT-jar-with-dependencies.jar tools.aqua.dse.DSELauncher $SOLVER_FLAGS -Ddse.executor=$OFFSET/executor.sh -Ddse.executor.args="-cp $classpath -Dtaint.flow=OFF -Dconcolic.execution=true Main" -Ddse.sources=$classpath > _gdart.log 2> _gdart.err

echo "$(date +%T) DSE finished"

#Eventually, we print non readable character from the SMT solver to the log.
sed 's/[^[:print:]]//' _gdart.log > _gdart.processed
mv _gdart.processed _gdart.log

# There is a new SV-COMP Rule that we cannot write more than 2MB to stdout.
if [[ $SV_COMP_MODE == 0 ]]; then
    echo "# # # # # # #"

    cat _gdart.log

    echo "# # # # # # #"

    cat _gdart.err

    echo "# # # # # # #"

    cat witness.graphml

    echo "# # # # # # #"
fi

# the exploration of the program ended (the constructor summaries print an [END OF OUTPUT] of their own)
complete=`cat _gdart.log | grep -a "event=end"`

if [[ ! -z $ASSERTION ]]; then 
errors=`cat _gdart.log | grep -a ERROR | grep -a java.lang.AssertionError | cut -d '.' -f 3`
fi

if [[ ! -z $EXCEPTION ]]; then 
errors=`cat _gdart.log | grep -a ERROR | grep -a Exception | cut -d '.' -f 3`
fi

buggy=`cat _gdart.log | grep -a BUGGY | cut -d '.' -f 2`
# paths that were not explored completely or not decided: never OK
# (precision loss of SPouT is reported as [INCOMPLETE] and gives leaves with "complete path:false")
# (aborts after a violated Verifier.assume are not explored further on purpose)
incomplete=`cat _gdart.log | grep -a "complete path:false\|DONT_KNOW\|+ OPEN\|dse.timeout reached\|no trace obtained" | grep -av "assumption violation"`
diverged=`cat _gdart.log | grep -a DIVERGED | cut -d '.' -f 2`
# aborted paths (SKIPPED[...] with a reason) other than assumption violations; plain SKIPPED leaves are the
# unsatisfiable branches of assumptions (e.g. the length of symbolic strings is below 2^31)
skipped=`cat _gdart.log | grep -a "SKIPPED\[" | grep -av "assumption violation" | cut -d '.' -f 3`


echo "complete: $complete"
echo "err: $errors"
echo "buggy: $buggy"
echo "diverged: $diverged"
echo "skipped: $skipped"
echo "incomplete: $(echo "$incomplete" | grep -c .)"

if [[ -n "$errors" ]]; then
  echo "Errors:"
  echo "$errors"
  err=`echo $errors| wc -l`
fi


if [[ ! "$err" -eq "0" ]]; then
    echo "== ERROR"
else
    if [[ -z $buggy ]] && [[ -z $skipped ]] && [[ ! -z $complete ]] && [[ -z $diverged ]] && [[ -z $incomplete ]]; then
        echo "== OK"
    else
        echo "== DONT-KNOW"
    fi
fi

rm -rf "$workdir" #Delete the tmpdir
