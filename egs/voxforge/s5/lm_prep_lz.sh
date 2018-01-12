#!/bin/bash

source path.sh
source cmd.sh

DATA=~/work/voice/corpus/voxforge/selected
locdata=$DATA/local
loctmp=$locdata/tmp
logdir=exp/data_prep
njobs=2

# language model order
order=3

rm $loctmp/test_utt.txt >/dev/null 2>&1
rm $loctmp/corpus.txt >/dev/null 2>&1

# Prepare a LM training corpus from the transcripts _not_ in the test set
cut -f2- -d' ' < $locdata/test_trans.txt |\
  sed -e 's:[ ]\+: :g' |\
  sort -u > $loctmp/test_utt.txt

cat $loctmp/test_utt.txt > $loctmp/corpus.txt

loc=`which ngram-count`;
if [ -z $loc ]; then
  if uname -a | grep 64 >/dev/null; then # some kind of 64 bit...
    sdir=$KALDI_ROOT/tools/srilm/bin/i686-m64 
  else
    sdir=$KALDI_ROOT/tools/srilm/bin/i686
  fi
  if [ -f $sdir/ngram-count ]; then
    echo Using SRILM tools from $sdir
    export PATH=$PATH:$sdir
  else
    echo You appear to not have SRILM tools installed, either on your path,
    echo or installed in $sdir.  See tools/install_srilm.sh for installation
    echo instructions.
    exit 1
  fi
fi

ngram-count -order $order -write-vocab $locdata/vocab-full.txt -wbdiscount \
  -text $loctmp/corpus.txt -lm $locdata/lm.arpa

echo "*** Finished building the LM model!"

