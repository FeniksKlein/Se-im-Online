/* Seçim Online - Sokak Hareketleri UI. Mount with:
   window.SokakHareketleri.mount(containerElement, existingSupabaseClient);
   Uses the already authenticated Supabase client; never embed a service key.
*/
(function () {
  const escapeHTML = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  async function mount(root, supabase) {
    if (!root || !supabase || typeof supabase.rpc !== 'function') throw Error('Oyun oturumu gerekli');
    root.innerHTML = '<section class="sokak-hareketleri"><h2>Sokak Hareketleri</h2><p>Yükleniyor…</p></section>';
    const {data, error} = await supabase.rpc('sokak_eylemler');
    if (error) {root.textContent = 'Eylemler yüklenemedi: '+error.message;return;}
    const active = !!data?.aktif;
    root.innerHTML = '<section class="sokak-hareketleri"><h2>Sokak Hareketleri</h2>'+
      (!active ? '<p>Bu özellik henüz kullanıma açılmadı.</p>' :
       '<form id="sokak-baslat"><label>İl numarası (1–81)<input name="il" type="number" min="1" max="81" required></label><label>Eylemin gerekçesi<textarea name="gerekce" minlength="15" maxlength="400" required></textarea></label><p>Başlangıç bedeli parti kasasından tahsil edilir.</p><button type="submit">Eylem başlat</button></form>')+
      '<p id="sokak-mesaj" role="status"></p><h3>Eylemler</h3><div class="sokak-liste">'+
      ((data?.eylemler || []).map(e=>'<article><strong>'+escapeHTML(e.parti)+'</strong> — İl '+Number(e.il_id)+'<p>'+escapeHTML(e.gerekce)+'</p><small>'+escapeHTML(e.durum)+' · Muhalefet: '+Number(e.muhalefet_fonu).toLocaleString('tr-TR')+' ₺ · İktidar: '+Number(e.iktidar_fonu).toLocaleString('tr-TR')+' ₺</small></article>').join('') || '<p>Henüz eylem bulunmuyor.</p>')+'</div></section>';
    const form=root.querySelector('#sokak-baslat');
    if(form) form.addEventListener('submit',async ev=>{
      ev.preventDefault();
      const button=form.querySelector('button');button.disabled=true;
      const msg=root.querySelector('#sokak-mesaj');msg.textContent='İşlem kontrol ediliyor…';
      const fd=new FormData(form);
      const result=await supabase.rpc('sokak_eylem_baslat',{p_il:Number(fd.get('il')),p_gerekce:String(fd.get('gerekce'))});
      if(result.error){msg.textContent=result.error.message;button.disabled=false;return;}
      await mount(root,supabase);
    });
  }
  window.SokakHareketleri={mount};
})();
