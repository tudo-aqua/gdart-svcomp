#!/bin/bash
# Copyright (C) 2021, Automated Quality Assurance Group,
# TU Dortmund University, Germany. All rights reserved.
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

OFFSET=$(dirname $BASH_SOURCE[0])
SOLVER_FLAGS="-Ddse.witness=true -Ddse.dp=multi -Ddse.bounds=true -Ddse.bounds.iter=6 -Ddse.bounds.step=6 -Ddse.terminate.on=assertion -Ddse.eplore=BFS -Ddse.b64encode=true -Djconstraints.multi=disableUnsatCoreChecking=true"
if [[ -z "$OFFSET" ]]; then
    OFFSET="."
fi

sha=$(cat ${OFFSET}/version.txt)

property=$1

if [ "$property" == "-v" ]; then
  echo "gdart-0.1-$sha"
  exit
fi

path=`pwd`

shift
classpath=$OFFSET

mainclass=""
for folder in $@; do
    classpath="$classpath:$folder"
    if [[ -n $(find $folder |grep Main.java) ]]; then
      mainclass=$(find $folder |grep Main.java)
    fi
    if [[ "$OSTYPE" == "darwin"* ]]; then
        find $folder -name *.java -exec sed -i "" -e "s/org\.sosy_lab\.sv_benchmarks\.Verifier/tools\.aqua\.concolic\.Verifier/g" {} \;;
    else
        find $folder -name *.java -exec sed -i "s/org\.sosy_lab\.sv_benchmarks\.Verifier/tools\.aqua\.concolic\.Verifier/g" {} \;;
    fi

done
if [[ -z $mainclass ]]; then
  echo "Could not find main class to execute program"
  echo "== DONT-KNOW"
  exit 1
fi
echo "computed classpath: $classpath"
echo "found main class: $mainclass"

if [[ "$OSTYPE" == "darwin"* ]]; then
    JAVAC=$OFFSET/SPouT/sdk/mxbuild/darwin-amd64/GRAALVM_ESPRESSO_NATIVE_CE_JAVA11/graalvm-espresso-native-ce-java11-21.2.0/Contents/Home/bin/javac
    JAVA=$OFFSET/SPouT/sdk/mxbuild/darwin-amd64/GRAALVM_ESPRESSO_NATIVE_CE_JAVA11/graalvm-espresso-native-ce-java11-21.2.0/Contents/Home/bin/java
else
    JAVAC=$OFFSET/SPouT/sdk/mxbuild/linux-amd64/GRAALVM_ESPRESSO_NATIVE_CE_JAVA11/graalvm-espresso-native-ce-java11-21.2.0/bin/javac
    JAVA=$OFFSET/SPouT/sdk/mxbuild/linux-amd64/GRAALVM_ESPRESSO_NATIVE_CE_JAVA11/graalvm-espresso-native-ce-java11-21.2.0/bin/java
fi
echo "compiling: $JAVAC -cp $classpath $mainclass"
$JAVAC -cp $classpath $mainclass

echo "invoke DSE: $JAVA -cp $OFFSET/dse/target/dse-0.0.1-SNAPSHOT-jar-with-dependencies.jar tools.aqua.dse.DSELauncher $SOLVER_FLAGS -Ddse.executor=$OFFSET/executor.sh -Ddse.executor.args=\"-cp $classpath Main\""
$JAVA -cp $OFFSET/dse/target/dse-0.0.1-SNAPSHOT-jar-with-dependencies.jar tools.aqua.dse.DSELauncher $SOLVER_FLAGS -Ddse.executor=$OFFSET/executor.sh -Ddse.executor.args="-cp $classpath Main" -Ddse.sources=$classpath > _gdart.log 2> _gdart.err

for folder in $@; do
    classpath="$classpath:$folder"
    if [[ -n $(find $folder |grep Main.java) ]]; then
      mainclass=$(find $folder |grep Main.java)
    fi
    if [[ "$OSTYPE" == "darwin"* ]]; then
        find $folder -name *.java -exec sed -i "" -e "s/tools\.aqua\.concolic\.Verifier/org\.sosy_lab\.sv_benchmarks\.Verifier/g" {} \;;
    else
        find $folder -name *.java -exec sed -i "s/tools\.aqua\.concolic\.Verifier/org\.sosy_lab\.sv_benchmarks\.Verifier/g" {} \;;
    fi

done

#Eventually, we print non readable character from the SMT solver to the log.
sed 's/[^[:print:]]//' _gdart.log > _gdart.processed
mv _gdart.processed _gdart.log

echo "# # # # # # #"

cat _gdart.log

echo "# # # # # # #"

cat _gdart.err

echo "# # # # # # #"

cat witness.graphml

echo "# # # # # # #"

complete=`cat _gdart.log | grep -a "END OF OUTPUT"`
errors=`cat _gdart.log | grep -a ERROR | grep -a java.lang.AssertionError | cut -d '.' -f 3`
buggy=`cat _gdart.log | grep -a BUGGY | cut -d '.' -f 2`
diverged=`cat _gdart.log | grep -a DIVERGED | cut -d '.' -f 2`
skipped=`cat _gdart.log | grep -a SKIPPED | egrep -v "assumption violation" | cut -d '.' -f 3`

echo "complete: $complete"
echo "err: $errors"
echo "buggy: $buggy"
echo "diverged: $diverged"
echo "skipped: $skipped"

if [[ -n "$errors" ]]; then
  echo "Errors:"
  echo "$errors"
  err=`echo $errors| wc -l`
fi


if [[ ! "$err" -eq "0" ]]; then
    echo "== ERROR"
else
    if [[ -z $buggy ]] && [[ -z $skipped ]] && [[ ! -z $complete ]] && [[ -z $diverged ]]; then
        echo "== OK"
    else
        echo "== DONT-KNOW"
    fi
fi
