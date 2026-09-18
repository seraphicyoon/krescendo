const products=[
 {name:'IVE — REVIVE+ Album',type:'album',group:'IVE',price:649,color:'#ffe4ee'},
 {name:'BLACKPINK Official Lightstick',type:'goods',group:'BLACKPINK',price:1299,color:'#e8ddff'},
 {name:'SEVENTEEN — Happy Burstday',type:'album',group:'SEVENTEEN',price:729,color:'#d9f2ff'},
 {name:'aespa — Armageddon Poster Set',type:'poster',group:'aespa',price:349,color:'#fff0bd'},
 {name:'Stray Kids SKZOO Keyring',type:'goods',group:'Stray Kids',price:499,color:'#e2f6ed'},
 {name:'LE SSERAFIM — HOT Compact',type:'album',group:'LE SSERAFIM',price:459,color:'#f7def7'},
 {name:'NewJeans Supernatural Poster',type:'poster',group:'NewJeans',price:299,color:'#dcecff'},
 {name:'TWICE Candybong Infinity',type:'goods',group:'TWICE',price:1399,color:'#ffe7d2'}
];
const preorders=[{name:'JENNIE — The Ruby Experience',date:'Cierra 28 SEP',eta:'Envío estimado: noviembre',cover:'RUBY'},{name:'ENHYPEN — Desire : Unleash',date:'Cierra 04 OCT',eta:'Envío estimado: diciembre',cover:'DESIRE'},{name:'NMIXX — Blue Valentine',date:'Cierra 11 OCT',eta:'Envío estimado: diciembre',cover:'BLUE'},{name:'TXT — Tomorrow Chapter',date:'Cierra 18 OCT',eta:'Envío estimado: enero',cover:'TOMORROW'}];
const grid=document.querySelector('#stockGrid');let cart=[];
function money(n){return new Intl.NumberFormat('es-MX',{style:'currency',currency:'MXN',maximumFractionDigits:0}).format(n)}
function render(filter='all'){grid.innerHTML=products.filter(p=>filter==='all'||p.type===filter).map((p,i)=>`<article class="product"><div class="product-visual" style="background:${p.color}"><span class="tag">EN STOCK</span><button class="add" data-product="${products.indexOf(p)}" aria-label="Añadir ${p.name}">+</button></div><h3>${p.name}</h3><p>${p.group} · Oficial</p><span>${money(p.price)}</span></article>`).join('');}
render();
document.querySelector('#preorderGrid').innerHTML=preorders.map(p=>`<article class="pre-card"><div class="pre-cover">${p.cover}</div><div><small>${p.date}</small><h3>${p.name}</h3><p>${p.eta}</p><button>Ver preventa →</button></div></article>`).join('');
document.querySelector('.filters').addEventListener('click',e=>{if(!e.target.dataset.filter)return;document.querySelectorAll('.filters button').forEach(b=>b.classList.remove('active'));e.target.classList.add('active');render(e.target.dataset.filter)});
document.querySelectorAll('[data-category]').forEach(b=>b.addEventListener('click',()=>{document.querySelector(`[data-filter="${b.dataset.category}"]`).click();location.hash='stock'}));
const toast=document.querySelector('#toast');function notify(t){toast.textContent=t;toast.classList.add('show');setTimeout(()=>toast.classList.remove('show'),2200)}
grid.addEventListener('click',e=>{const i=e.target.dataset.product;if(i===undefined)return;cart.push(products[i]);updateCart();notify('Añadido a tu bolsa ♡')});
const cartPanel=document.querySelector('#cart'),overlay=document.querySelector('#overlay');
function updateCart(){document.querySelector('#cartCount').textContent=cart.length;document.querySelector('#cartItems').innerHTML=cart.length?cart.map((p,i)=>`<div class="cart-item"><span>${p.name}<small>${p.group}</small></span><b>${money(p.price)}</b></div>`).join(''):'<p class="empty">Tu bolsa está esperando su primer favorito ♡</p>';document.querySelector('#subtotal').textContent=money(cart.reduce((s,p)=>s+p.price,0))}
function cartOpen(on){cartPanel.classList.toggle('open',on);overlay.classList.toggle('show',on);cartPanel.setAttribute('aria-hidden',!on)}
document.querySelector('#bagBtn').onclick=()=>cartOpen(true);document.querySelector('#closeCart').onclick=()=>cartOpen(false);overlay.onclick=()=>cartOpen(false);
const modal=document.querySelector('#loginModal');document.querySelector('#loginBtn').onclick=()=>modal.showModal();modal.querySelector('.close').onclick=()=>modal.close();document.querySelector('#loginForm').onsubmit=e=>{e.preventDefault();modal.close();notify('Demo lista: conecta tu proveedor de autenticación')};
document.querySelector('#searchBtn').onclick=()=>{const q=prompt('¿Qué estás buscando?');if(!q)return;const match=products.find(p=>p.name.toLowerCase().includes(q.toLowerCase())||p.group.toLowerCase().includes(q.toLowerCase()));notify(match?`Encontramos: ${match.name}`:'No encontramos coincidencias')};
document.querySelector('.menu').onclick=()=>{const nav=document.querySelector('nav');nav.style.display=nav.style.display==='flex'?'none':'flex';nav.style.position='absolute';nav.style.top='88px';nav.style.left='0';nav.style.right='0';nav.style.background='white';nav.style.padding='25px';nav.style.flexDirection='column'};
