#!/bin/zsh
cd ${0:a:h}
until [ "$(ps aux | grep -c '[x]codebuild')" = "0" ]; do sleep 30; done
S=(testS1PushOne testS2PushThree testS3PopMidTransition testS4SwipeCancelThenSwipe testS5ReplaceInOneStep testS6PopToRoot testS7NestedSheets testS8TabSwitchKeepsStack testS9Stress)
EC=(testE0NoForwarding testE1EnvironmentKey testE2ObservableObject testE3RendererValue testE4WholeEnvironment testC1Title testC2Toolbar testC3BackTitle testC4Searchable testC5TabBarHidden testC6TitleModes)
S17=39168290-9C12-43D4-8ABE-4723457395D3
./run.sh uiKit $S17 r17b 4 $S >> runs/r.txt
./run.sh uiKit $S17 ecr17 1 $EC >> runs/r.txt
./run.sh swiftUI $S17 r17 5 $S >> runs/r.txt
./run.sh swiftUI $S17 ecr17 1 $EC >> runs/r.txt
echo finished
