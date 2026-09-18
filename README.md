# Krescendo

Tienda demo responsive de K-pop merch, lista para desplegar como sitio estático.

## Publicar en Vercel

1. Sube esta carpeta a un repositorio de GitHub.
2. En Vercel, importa el repositorio.
3. Framework Preset: `Other`.
4. Build Command: vacío.
5. Output Directory: `dist`.

## Activar Supabase y el panel

1. Crea un proyecto gratuito en Supabase.
2. Abre SQL Editor, pega el archivo supabase-setup.sql y ejecútalo.
3. Ve a Authentication > Users > Add user y crea tu cuenta administrativa.
4. En Settings > API, copia Project URL y la clave pública anon.
5. Pega ambos valores en dist/config.js. Nunca uses la clave service_role.
6. Sube el cambio a GitHub; Vercel volverá a desplegarlo.
7. Abre /admin.html en tu dominio.

El panel permite crear, editar y eliminar productos, cambiar stock, administrar preventas y categorías.
# Krescendo V12

La tienda incluye catálogo, portada fotográfica editable desde administración, reseñas, registro exclusivo mediante claves de invitación, bolsa persistente y checkout por transferencia bancaria.

## Activar pedidos

1. Ejecuta `orders-setup.sql` completo en Supabase > SQL Editor. También activa las invitaciones de un solo uso.
2. Edita los datos de transferencia dentro de `dist/config.js`, en la sección `bank`.
3. Sube el contenido de `dist` a la raíz de GitHub y deja los archivos SQL como respaldo.

La función SQL calcula los precios desde la base de datos y descuenta existencias. Nunca confía en el total enviado por el navegador.
