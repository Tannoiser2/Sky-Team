#!/usr/bin/env python3
"""Scarica le immagini satellitari intorno alla soglia della pista di ogni aeroporto.

Fonte: Sentinel-2 cloudless 2020 di EOX (https://s2maps.eu), licenza CC BY-NC-SA 4.0,
"Sentinel-2 cloudless - https://s2maps.eu by EOX IT Services GmbH
(Contains modified Copernicus Sentinel data 2020)".
Gira nella GitHub Action «mappe» (dal container di sviluppo il sito non è raggiungibile).
Ogni immagine copre LATO pixel di livello Z, centrata sulla soglia, ridotta a USCITA pixel,
con i bordi sfumati in trasparenza.
"""
import io, json, math, os, sys, time, urllib.request
from PIL import Image, ImageDraw, ImageFilter

Z = 13
LATO = 2048
USCITA = 1024
URL = "https://tiles.maps.eox.at/wmts/1.0.0/s2cloudless-2020_3857/default/g/{z}/{y}/{x}.jpg"
QUI = os.path.dirname(os.path.abspath(__file__))
DATI = os.path.join(QUI, "..", "assets", "dati", "aeroporti.json")
DEST = os.path.join(QUI, "..", "assets", "img", "mappe")

def pixel(lat, lon):
    n = 256 * 2 ** Z
    x = (lon + 180.0) / 360.0 * n
    la = math.radians(max(-85.0, min(85.0, lat)))
    y = (1.0 - math.log(math.tan(la) + 1.0 / math.cos(la)) / math.pi) / 2.0 * n
    return x, y

def tessera(x, y, cache):
    k = (x, y)
    if k in cache:
        return cache[k]
    n = 2 ** Z
    if y < 0 or y >= n:
        im = Image.new("RGB", (256, 256), (235, 240, 245))
    else:
        url = URL.format(z=Z, x=x % n, y=y)
        for prova in range(4):
            try:
                req = urllib.request.Request(url, headers={"User-Agent": "SkyTeam-ludoteca/1.0 (github.com/Tannoiser2/Sky-Team)"})
                im = Image.open(io.BytesIO(urllib.request.urlopen(req, timeout=30).read())).convert("RGB")
                break
            except Exception as e:
                print("  errore", url, e)
                time.sleep(2)
        else:
            im = Image.new("RGB", (256, 256), (90, 110, 80))
    cache[k] = im
    return im

def mappa(codice, a):
    cx, cy = pixel(a["lat"], a["lon"])
    x0, y0 = int(cx - LATO / 2), int(cy - LATO / 2)
    tx0, ty0 = x0 // 256, y0 // 256
    tx1, ty1 = (x0 + LATO) // 256, (y0 + LATO) // 256
    tela = Image.new("RGB", ((tx1 - tx0 + 1) * 256, (ty1 - ty0 + 1) * 256))
    cache = {}
    for ty in range(ty0, ty1 + 1):
        for tx in range(tx0, tx1 + 1):
            tela.paste(tessera(tx, ty, cache), ((tx - tx0) * 256, (ty - ty0) * 256))
    ox, oy = cx - LATO / 2 - tx0 * 256, cy - LATO / 2 - ty0 * 256
    im = tela.transform((LATO, LATO), Image.AFFINE, (1, 0, ox, 0, 1, oy), resample=Image.BILINEAR)
    im = im.resize((USCITA, USCITA), Image.LANCZOS)
    # bordi sfumati: la mappa si fonde con il terreno intorno
    m = Image.new("L", (USCITA, USCITA), 0)
    b = int(USCITA * 0.09)
    ImageDraw.Draw(m).ellipse((b, b, USCITA - b, USCITA - b), fill=255)
    m = m.filter(ImageFilter.GaussianBlur(USCITA * 0.06))
    im.putalpha(m)
    im.save(os.path.join(DEST, codice.lower() + ".webp"), quality=78, method=6)
    print(codice, "ok")

def main():
    os.makedirs(DEST, exist_ok=True)
    dati = json.load(open(DATI, encoding="utf-8"))
    scelti = sys.argv[1:] or list(dati)
    for c in scelti:
        mappa(c, dati[c])

if __name__ == "__main__":
    main()
