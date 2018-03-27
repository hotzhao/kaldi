#!/bin/bash

. ./path.sh

textcorpus=data/text
lexicon=data/dict/lexicon.txt

######################################
# check input files
for x in "$textcorpus" "$lexicon"; do
  [ ! -f $x ] && echo "$0: No such file $x" && exit 1;
done

rm -rf data/lm
mkdir -p data/lm

kaldi_lm=`which train_lm.sh`
if [ -z $kaldi_lm ]; then
  echo "$0: train_lm.sh is not found. That might mean it's not installed"
  echo "$0: or it is not added to PATH"
  echo "$0: Use the script tools/extra/install_kaldi_lm.sh to install it"
  exit 1
fi

cat $textcorpus | awk -v lex=$lexicon 'BEGIN{while((getline<lex) >0){ seen[$1]=1; } }
  {for(n=2; n<=NF;n++) {  if (seen[$n]) { printf("%s ", $n); } else {printf("<SPOKEN_NOISE> ");} } printf("\n");}' \
  > data/lm/text.no_oov || exit 1;
ngram-count -text data/lm/text.no_oov -order 3 -lm data/lm/arpalm.txt

mkdir -p data/lang
cat data/lm/arpalm.txt | \
  arpa2fst "--disambig-symbol=#0" \
    --read-symbol-table=data/dict/words.txt - \
    data/lang/G.fst

set +e
fstisstochastic data/lang/G.fst
set -e

# Everything below is only for diagnostic.
# Checking that G has no cycles with empty words on them (e.g. <s>, </s>);
# this might cause determinization failure of CLG.
# #0 is treated as an empty word.
mkdir -p data/lang/tmpdir.g
awk '{if(NF==1){ printf("0 0 %s %s\n", $1,$1); }}
     END{print "0 0 #0 #0"; print "0";}' \
     < "$lexicon" > data/lang/tmpdir.g/select_empty.fst.txt

fstcompile --isymbols=data/dict/words.txt --osymbols=data/dict/words.txt \
  data/lang/tmpdir.g/select_empty.fst.txt \
  | fstarcsort --sort_type=olabel \
  | fstcompose - data/lang/G.fst > data/lang/tmpdir.g/empty_words.fst

fstinfo data/lang/tmpdir.g/empty_words.fst | grep cyclic | grep -w 'y' \
  && echo "Language model has cycles with empty words" && exit 1

rm -r data/lang/tmpdir.g

utils/mkgraph.sh data/lang exp/tri5a exp/tri5a/graph || exit 1;

echo "Generate small grammar done!"
