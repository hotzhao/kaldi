

. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.
. ./path.sh

corpus_dir=$1
H=`pwd`  #exp home

echo ""
echo "##############################"
echo "Decoding $corpus_dir"
echo ""

########################################
# data prepare

rm -rf data
mkdir -p data/test
#create wav.scp, utt2spk.scp, spk2utt.scp, text
(
wavid=0
for x in test; do
  echo "cleaning data/$x"
  cd $H/data/$x
  rm -rf wav.scp utt2spk spk2utt word.txt phone.txt text
  echo "preparing scps and text in data/$x"
  for nn in `find  $corpus_dir/$x/*.wav | sort -u | xargs -i basename {} .wav`; do
      #echo "$nn"
      spkid="lz"
      wavid=$[$wavid+1]
      uttid=$(printf '%s_%.4d' "$spkid" "$wavid")
      echo $uttid $corpus_dir/$x/$nn.wav >> wav.scp
      echo $uttid $spkid >> utt2spk
      echo $uttid "$nn" >> word.txt
  done 
  cp word.txt text
  sort wav.scp -o wav.scp
  sort utt2spk -o utt2spk
  sort text -o text
  cat text
done
) || exit 1

cd $H
utils/utt2spk_to_spk2utt.pl data/test/utt2spk > data/test/spk2utt

########################################
# produce mfcc features

#for x in train dev test; do
for x in test; do
   #make  mfcc
   #steps/make_mfcc.sh --nj 1 --cmd "$train_cmd" data/$x log/make_mfcc/$x rawmfcc/$x || exit 1;
   steps/make_mfcc_pitch.sh --nj 1 --cmd "$train_cmd" data/$x log/make_mfcc/$x rawmfcc/$x || exit 1;
   #compute cmvn
   steps/compute_cmvn_stats.sh data/$x log/mfcc_cmvn/$x rawmfcc/$x || exit 1;
done

########################################
# decode
cd $H
rm -rf decode_test*

steps/decode_fmllr.sh --cmd "$decode_cmd" --nj 1 --config conf/decode.config \
   exp/tri5a/graph data/test exp/tri5a/decode_test || exit 1;

echo "Decode success!"
