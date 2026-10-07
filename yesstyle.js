const cfg=window.KRESCENDO_CONFIG||{};
const button=document.querySelector('#yesstyleWhatsapp');
if(button){
  const number=String(cfg.whatsappNumber||'').replace(/\D/g,'');
  const message=encodeURIComponent('Hola Krescendo ✨ Quiero cotizar mi carrito de YesStyle con el 50% de descuento. Te envío la captura de mi carrito.');
  button.href='https://wa.me/'+number+'?text='+message;
}
const menu=document.querySelector('.menu');
if(menu){menu.onclick=function(){const nav=document.querySelector('nav');nav.classList.toggle('mobile-open')}};
