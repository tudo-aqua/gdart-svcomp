#!/bin/bash
OFFSET=$(dirname $BASH_SOURCE[0])
FLAGS="-truffle -ea -Xmx9g -Xss1g -Djava.lang.invoke.stringConcat=BC_SB -Dconcolic.execution=true"
if [[ "$OSTYPE" == "darwin"* ]]; then
   echo "$OFFSET/SPouT/sdk/mxbuild/darwin-aarch64/GRAALVM_ESPRESSO_NATIVE_CE_JAVA17/graalvm-espresso-native-ce-java17-22.2.0.1-dev/Contents/Home/bin/java $FLAGS $@"
    $OFFSET/SPouT/sdk/mxbuild/darwin-aarch64/GRAALVM_ESPRESSO_NATIVE_CE_JAVA17/graalvm-espresso-native-ce-java17-22.2.0.1-dev/Contents/Home/bin/java $FLAGS $@
else
  if [[ "$(uname -m)" == "aarch64" ]]; then
    $OFFSET/SPouT/sdk/mxbuild/linux-aarch64/GRAALVM_ESPRESSO_NATIVE_CE_JAVA17/graalvm-espresso-native-ce-java17-22.2.0.1-dev/bin/java $FLAGS $@
  else 
    $OFFSET/SPouT/sdk/mxbuild/linux-amd64/GRAALVM_ESPRESSO_NATIVE_CE_JAVA17/graalvm-espresso-native-ce-java17-22.2.0.1-dev/bin/java $FLAGS $@
  fi
fi
