# ShootingStar

Game Godot 4 (2D, renderer `mobile`) — projek utama `res://scene/main_menu/main_menu.tscn`.

Repo ini disediakan supaya projek boleh di-upload ke GitHub dan dibuka terus dalam
aplikasi **Xogot** (Godot untuk iPhone/iPad).

## Jalankan di Linux

Buka folder projek ini dalam Godot 4.7 (atau `godot --path .`). Fail `.godot/`
tidak di-commit, jadi Godot akan import semula aset secara automatik pada kali
pertama dibuka.

## Upload ke GitHub (sekali sahaja)

1. Buat repo **kosong** di https://github.com/new — jangan pilih "Add a README",
   `.gitignore` atau license supaya tiada konflik dengan commit sedia ada.
2. Di terminal, dari folder projek ini:

```bash
git remote add origin https://github.com/<USERNAME>/<REPO>.git
git branch -M main
git push -u origin main
```

Jika GitHub minta password, guna **Personal Access Token** sebagai password
(Settings → Developer settings → Personal access tokens), bukan password akaun.

Selepas ini, setiap kali ada perubahan:

```bash
git add -A
git commit -m "Update game"
git push
```

## Buka dalam Xogot di iPhone

Pilihan A — melalui Working Copy (git sebenar, boleh `pull` update):

1. Install **Working Copy** di iPhone, log masuk GitHub, clone repo ini.
2. Buka **Xogot** → Project Manager → Import/Open, pilih folder projek dari
   Working Copy (Xogot menyokong folder Working Copy secara terus).

Pilihan B — melalui ZIP (paling mudah, tiada app tambahan):

1. Buka repo di GitHub (Safari) → **Code → Download ZIP**.
2. Dalam app **Files**, tap ZIP itu untuk extract.
3. Tekan lama folder projek → **Copy**, kemudian pergi ke
   **On My iPhone → Xogot** dan **Paste**.
4. Buka Xogot — projek akan muncul dalam Project Manager (restart Xogot jika
   belum nampak).

Lepas projek dibuka, tekan Play untuk test game. Xogot juga boleh
**Export → Web** untuk main melalui link browser.

## Nota

- `.godot/` (cache import) tidak di-commit — ia dijana semula oleh Godot/Xogot.
- `addons/funplay_mcp/` ialah editor plugin MCP untuk workflow di PC. Ia hanya
  aktif dalam editor dan tidak diperlukan untuk bermain game.
- `.agents/` dan `.funplay/` tidak di-commit kerana mengandungi tetapan/token
  tempatan, bukan kandungan game.
- Guna Git LFS hanya jika aset besar (>50 MB) ditambah kemudian; sekarang saiz
  repo sekitar 15 MB.
