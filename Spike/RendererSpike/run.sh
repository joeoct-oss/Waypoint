#!/bin/zsh
# usage: run.sh <renderer> <simid> <label> <iterations> <test...>
cd ${0:a:h}
r=$1 sim=$2 label=$3 n=$4; shift 4
only=(); for t in "$@"; do only+=(-only-testing:RendererSpikeUITests/SpikeTests/$t); done
for i in $(seq 1 $n); do
  log=runs/$label-$r-$i.log
  TEST_RUNNER_RENDERER=$r xcodebuild test-without-building -workspace RendererSpike.xcworkspace -scheme RendererSpike \
    -destination id=$sim -derivedDataPath ./DD -parallel-testing-enabled NO $only > $log 2>&1
  grep -E "^Test Case .*(passed|failed)" $log | sed -E "s/.*SpikeTests (test[A-Za-z0-9]+)\]. (passed|failed).*/$label $r $i \1 \2/"
done
