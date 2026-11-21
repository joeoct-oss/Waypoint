#!/bin/zsh
cd ${0:a:h}
D=5A5E38C1-A97F-42D8-872D-BACCA686FA8E
until [ "$(ps aux | grep -c '[x]codebuild')" = "0" ]; do sleep 30; done
echo "start $(date +%H:%M)"
S=(testS1PushOne testS2PushThree testS3PopMidTransition testS4SwipeCancelThenSwipe testS5ReplaceInOneStep testS6PopToRoot testS7NestedSheets testS8TabSwitchKeepsStack testS9Stress)
EC=(testE0NoForwarding testE1EnvironmentKey testE2ObservableObject testE3RendererValue testE4WholeEnvironment testC1Title testC2Toolbar testC3BackTitle testC4Searchable testC5TabBarHidden testC6TitleModes)
for r in uiKit swiftUI; do
  ./run.sh $r $D w02 5 $S >> runs/w02.txt
  ./run.sh $r $D ecw02 1 $EC >> runs/w02.txt
done
xcrun simctl shutdown $D
echo "finished $(date +%H:%M)"
