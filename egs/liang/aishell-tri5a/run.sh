

corpus_root=/home/liang/work/speech/corpus/liang
H=`pwd`  #exp home

cd $H

for corpus in ip7; do
  #echo "$corpus_root/$corpus"
  ./decode_corpus.sh "$corpus_root/$corpus"
done
