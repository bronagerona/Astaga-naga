import React, {useEffect, useRef, useState} from 'react';
import {SafeAreaView, StatusBar, Text, View, TouchableOpacity, ActivityIndicator, Alert, StyleSheet} from 'react-native';
import {pick, types, keepLocalCopy} from '@react-native-documents/picker';
import {WebView} from 'react-native-webview';
import {initLlama} from 'llama.rn';

export default function App() {
  const [ready,setReady]=useState(false);
  const [busy,setBusy]=useState(false);
  const [status,setStatus]=useState('Pilih model Gemma 3 1B GGUF untuk komentar companion.');
  const webRef=useRef(null);
  const ctxRef=useRef(null);
  const modelRef=useRef(null);
  const inferenceRef=useRef(false);
  const lastCommentAtRef=useRef(0);

  useEffect(()=>()=>{if(ctxRef.current&&ctxRef.current.release){ctxRef.current.release()}},[]);

  async function chooseLocalModel(){
    const picked=await pick({type:[types.allFiles]});
    const file=Array.isArray(picked)?picked[0]:picked;
    if(!file||!file.name||!file.name.toLowerCase().endsWith('.gguf')) {
      throw new Error('Pilih file model berformat .gguf.');
    }
    setStatus('Menyalin model lokal ke penyimpanan aplikasi…');
    const copies=await keepLocalCopy({
      files:[{uri:file.uri,fileName:'zenia-'+file.name}],
      destination:'cachesDirectory'
    });
    const local=copies&&copies[0];
    if(!local||local.status!=='success'||!local.localUri) {
      throw new Error((local&&local.copyError)||'Gagal menyalin model GGUF.');
    }
    return {path:local.localUri,name:file.name};
  }

  async function createTestedContext(model){
    let next=null;
    try{
      next=await initLlama({
        model:model.path,
        n_ctx:2048,
        n_threads:4,
        n_gpu_layers:0,
        use_mmap:true
      });
      const probe=await next.completion({
        prompt:'<start_of_turn>user\nBalas tepat satu kata: SIAP<end_of_turn>\n<start_of_turn>model\n',
        n_predict:12,
        temperature:0
      });
      if(!probe||!probe.text||!probe.text.trim()){
        throw new Error('Model tidak memberi respons pada tes awal.');
      }
      const tested=next;
      next=null;
      return tested;
    }finally{
      if(next&&next.release){try{await next.release()}catch(_){}}
    }
  }

  async function chooseModel(){
    if(busy||inferenceRef.current)return;
    setBusy(true);
    try{
      setStatus('Pilih file Gemma 3 1B GGUF…');
      const model=await chooseLocalModel();
      setStatus('Memuat dan mengetes model lokal…');
      const context=await createTestedContext(model);
      if(ctxRef.current&&ctxRef.current.release){try{await ctxRef.current.release()}catch(_){}}
      ctxRef.current=context;
      modelRef.current=model;
      lastCommentAtRef.current=0;
      setReady(true);
      setStatus('Gemma lokal aktif: '+model.name+' · komentar saja');
    }catch(e){
      const cancelled=String(e&&e.code||'').toLowerCase().includes('cancel');
      setStatus(cancelled?'Pemilihan model dibatalkan.':'Model belum siap. Periksa file GGUF dan coba lagi.');
      if(!cancelled)Alert.alert('Gemma lokal belum siap',String(e&&e.message||e));
    }finally{
      setBusy(false);
    }
  }

  function sendComment(text){
    const safe=String(text||'').trim().slice(0,100);
    if(!safe||!webRef.current)return;
    webRef.current.injectJavaScript(
      'window.ZeniaLocalAI&&window.ZeniaLocalAI.receiveComment('+JSON.stringify(safe)+'); true;'
    );
  }

  async function onGameMessage(event){
    let msg;
    try{msg=JSON.parse(event.nativeEvent.data)}catch(_){return}
    if(!msg||msg.type!=='zenia_comment_request')return;
    if(!ctxRef.current||inferenceRef.current)return;
    const now=Date.now();
    if(now-lastCommentAtRef.current<7000)return;
    inferenceRef.current=true;
    lastCommentAtRef.current=now;
    try{
      const c=msg.context||{};
      const eventNames={
        hurt:'Joni baru saja terkena serangan',
        low_hp:'HP Joni tinggal sedikit, situasi genting',
        kill:'Joni baru saja mengalahkan monster',
        boss:'boss muncul, pertarungan berat dimulai',
        boss_defeated:'boss baru saja dikalahkan'
      };
      const eventText=eventNames[String(msg.event)]||'ada kejadian di petualangan';
      const context=[
        'Lokasi: '+String(c.map||'petualangan'),
        'Level: '+Number(c.level||1),
        'HP: '+Number(c.hp||0)+'/'+Number(c.maxHp||0)+' ('+Number(c.hpPercent||0)+'%)',
        'Monster terkait: '+String(msg.monster||'monster'),
        'Musuh dekat: '+Number(c.nearby||0),
        'Boss dekat: '+(c.boss?'ya':'tidak'),
        'Quest: '+String(c.quest||'belum ada')
      ].join('; ');
      const prompt='<start_of_turn>user\n'+
        'Kamu companion serigala lucu di game RPG Zenia. Buat SATU komentar pendek, spontan, kocak, dan relevan dalam bahasa Indonesia santai untuk Joni. Maksimal 1 kalimat pendek, sekitar 4-12 kata. Boleh usil atau dramatis ringan. Jangan mengarang aksi yang tidak disebutkan. Jangan memberi instruksi gameplay. Jangan keluarkan label, roleplay panjang, markdown, atau tanda kutip. Kamu hanya menghasilkan komentar; kamu tidak mengendalikan gerakan atau aksi game.\n'+
        'Kejadian: '+eventText+'. Konteks: '+context+'\n'+
        'Tulis hanya komentarnya.<end_of_turn>\n<start_of_turn>model\n';
      const result=await ctxRef.current.completion({
        prompt,
        n_predict:48,
        temperature:0.78,
        top_p:0.9
      });
      let answer=String(result&&result.text||'')
        .replace(/<end_of_turn>[\s\S]*$/i,'')
        .replace(/<start_of_turn>[\s\S]*$/i,'')
        .replace(/[\r\n]+/g,' ')
        .replace(/^\s*["'“”*#>\-]+|["'“”*#>\-]+\s*$/g,'')
        .trim();
      if(!/[a-zA-ZÀ-ÿ0-9]/.test(answer))throw new Error('Model tidak menghasilkan komentar yang terbaca.');
      if(answer.length>100)answer=answer.slice(0,97).replace(/\s+\S*$/,'')+'…';
      sendComment(answer);
      setStatus('Gemma lokal aktif · komentar companion dibuat dari konteks game');
    }catch(e){
      setStatus('Gemma tetap lokal, tetapi komentar kali ini gagal dibuat. Gameplay tetap berjalan.');
    }finally{
      inferenceRef.current=false;
    }
  }

  return <SafeAreaView style={styles.root}>
    <StatusBar backgroundColor="#080d20" barStyle="light-content"/>
    <View style={styles.head}>
      <Text style={styles.title}>ZENIA QUEST · LOCAL AI</Text>
      <Text style={styles.status}>{status}</Text>
      <TouchableOpacity style={styles.btn} onPress={chooseModel} disabled={busy}>
        <Text style={styles.btnText}>{busy?'Menyiapkan Gemma…':ready?'Ganti model GGUF':'Pilih model Gemma GGUF'}</Text>
      </TouchableOpacity>
    </View>
    {ready?
      <WebView
        ref={webRef}
        style={styles.game}
        source={{uri:'file:///android_asset/index.html'}}
        javaScriptEnabled
        domStorageEnabled
        allowFileAccess
        originWhitelist={['*']}
        onMessage={onGameMessage}
      />:
      <View style={styles.loader}>
        {busy?<ActivityIndicator size="large" color="#a78bfa"/>:<Text style={styles.emoji}>🐺</Text>}
        <Text style={styles.loaderTitle}>{busy?'Menyiapkan model lokal…':'Aktifkan komentar companion'}</Text>
        <Text style={styles.loaderText}>Pilih file Gemma 3 1B berformat GGUF dari penyimpanan HP. Model berjalan lokal di perangkat. AI hanya membuat komentar pendek di bubble dekat companion; pergerakan, serangan, dan seluruh gameplay tetap dikendalikan Zenia.</Text>
      </View>}
  </SafeAreaView>;
}

const styles=StyleSheet.create({
  root:{flex:1,backgroundColor:'#080d20'},
  head:{backgroundColor:'#101a32',padding:12},
  title:{fontSize:19,fontWeight:'bold',color:'#c4b5fd'},
  status:{color:'#e7efff',marginVertical:7},
  btn:{backgroundColor:'#5b42b5',padding:10,borderRadius:8,alignItems:'center'},
  btnText:{color:'#fff',fontWeight:'bold'},
  game:{flex:1},
  loader:{flex:1,alignItems:'center',justifyContent:'center',padding:28},
  emoji:{fontSize:48,marginBottom:12},
  loaderTitle:{fontSize:20,fontWeight:'bold',color:'#e7efff',marginBottom:10,textAlign:'center'},
  loaderText:{textAlign:'center',color:'#c0cde8',lineHeight:22}
});