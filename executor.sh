#!/bin/bash
OFFSET=$(dirname $BASH_SOURCE[0])
FLAGS="-truffle -ea"
if [[ "$OSTYPE" == "darwin"* ]]; then
    $OFFSET/SPouT/sdk/mxbuild/darwin-amd64/GRAALVM_ESPRESSO_NATIVE_CE_JAVA11/graalvm-espresso-native-ce-java11-21.2.0/Contents/Home/bin/java $FLAGS $@
else
   $OFFSET/SPouT/sdk/mxbuild/linux-amd64/GRAALVM_ESPRESSO_NATIVE_CE_JAVA11/graalvm-espresso-native-ce-java11-21.2.0/bin/java $FLAGS $@
fi
