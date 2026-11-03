#!/bin/bash
OFFSET=$(dirname $BASH_SOURCE[0])
FLAGS="-truffle -ea -Xmx9g -Xss1g"
# (the arguments are not quoted: DSE passes them as one string)
# SPouT: Espresso native standalone (JDK 25), built with mx --env native-ce in SPouT/espresso
case "$OSTYPE-$(uname -m)" in
  darwin*)        PLATFORM=darwin-aarch64 ;;
  *-aarch64)      PLATFORM=linux-aarch64 ;;
  *)              PLATFORM=linux-amd64 ;;
esac
JAVA=$OFFSET/SPouT/espresso/mxbuild/$PLATFORM/ESPRESSO_NATIVE_STANDALONE/bin/java
if [[ -z "$GDART_EXEC_LOG" ]]; then
    exec $JAVA $FLAGS $@
fi
# diagnosis: wall time of each execution (GDART_EXEC_LOG=<file>)
start=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
$JAVA $FLAGS $@
status=$?
end=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
echo "$start $end $(perl -e "printf '%.3f', $end - $start") exit=$status" >> "$GDART_EXEC_LOG"
exit $status
