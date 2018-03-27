

corpus_root=/home/liang/work/speech/corpus/liang
H=`pwd`  #exp home

cd $H

#for corpus in xiaowanzi; do
for corpus in liang16k; do
  #echo "$corpus_root/$corpus"
  ./decode_corpus.sh "$corpus_root/$corpus"
done
