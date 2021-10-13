#!/bin/bash
set -e
pushd dse;
  ./compile-jconstraints.sh
  mvn package;
popd;
pushd SPouT/espresso;
  mx --env native-ce build;
popd;
