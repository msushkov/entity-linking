#! /bin/bash

#source "$APP_HOME/setup_database.sh"

if [ -f $DEEPDIVE_HOME/sbt/sbt ]; then
  echo "DeepDive $DEEPDIVE_HOME"
else
  echo "[ERROR] Could not find sbt in $DEEPDIVE_HOME!"
  exit 1
fi

cd $DEEPDIVE_HOME
$DEEPDIVE_HOME/sbt/sbt "run -c $APP_HOME/application.conf"

# after inference is done, populate the results file
source "$APP_HOME/populate_results.sh"

# run the evaluation script
perl $APP_HOME/evaluation/kbpenteval.pl $APP_HOME/evaluation/el_2010_eval_answers.tsv $APP_HOME/evaluation/results/out.tsv
