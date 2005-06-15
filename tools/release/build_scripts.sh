#!/bin/sh

# builds all scripts to check that there is no breakage.


nab_scripts="warmup.ml diffusion_example.ml \
proto/aodv/scripts/test_3_nodes.ml \
proto/ler/scripts/routecosts.ml \
proto/aodv/scripts/test_6_nodes.ml \
proto/aodv/scripts/test_7_nodes_rerr.ml \
proto/str/scripts/strtest.ml \
proto/ler/scripts/eval_gradient.ml \
doc/lesson1.ml \
doc/lesson2.ml \
"

nabviz_scripts="doc/lesson3.ml"

error=0

check_exit()
{
  if [ $? -ne 0 ] ; then
      echo "\n\neeeeeeek!!! something appears to have failed"
      error=1
  fi
}

for s in $nab_scripts 
  do
  rm bin/nab;
  make SCRIPT=$s bin/nab;
  check_exit;
done

for s in $nabviz_scripts 
  do
  rm bin/nabviz;
  make SCRIPT=$s bin/nabviz;
  check_exit;
done

if [ $error -eq 0 ] 
    then
    echo " *"
    echo " * Looks ok!"
    echo " *"
else
    echo " X"
    echo " X Looks bad!!!!!!!!!!!!"
    echo " X"
fi

exit $error
