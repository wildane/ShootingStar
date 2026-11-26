shader_type canvas_item;
render_mode blend_add, unshaded;

// ==========================================
// GLOW SILUET PERISAI
// ==========================================
// Sprite ini memakai tekstur yang sama dengan sprite pemain (Angkasa / Base),
// jadi glow mengikut bentuk kapal itu sendiri — bukan bulatan atau kotak.
// Kawasan dalam badan sprite dibuat telus supaya hanya bahagian luar bercahaya.

uniform vec4 warna_glow : source_color = vec4(0.30, 0.90, 1.0, 1.0);
// Lebar glow dalam piksel tekstur. Skrip mengira nilainya ikut skala sprite
// supaya lebar di skrin sentiasa ~2 piksel walaupun tekstur asal besar.
uniform float lebar_glow : hint_range(0.0, 400.0) = 60.0;
uniform float keamatan : hint_range(0.0, 4.0) = 1.0;

// Piksel separa telus (kabur/kesan sampingan tekstur) dianggap kosong supaya
// glow hanya mengikut badan sprite yang jelas, bukan seluruh kotak tekstur.
float tegas(float alfa) {
	return step(0.5, alfa);
}

void fragment() {
	float asal = tegas(texture(TEXTURE, UV).a);
	float jumlah = 0.0;
	vec2 px = TEXTURE_PIXEL_SIZE * lebar_glow;

	// 8 arah x 3 jarak: cahaya lembut di luar siluet sprite.
	// Sampel di luar UV (0..1) diabaikan supaya glow tidak merebak dari tepi tekstur.
	for (int i = 0; i < 8; i++) {
		float sudut = float(i) * 0.785398;
		vec2 arah = vec2(cos(sudut), sin(sudut));
		vec2 u1 = UV + arah * px * 0.35;
		vec2 u2 = UV + arah * px * 0.65;
		vec2 u3 = UV + arah * px;
		if (u1.x >= 0.0 && u1.x <= 1.0 && u1.y >= 0.0 && u1.y <= 1.0) {
			jumlah += tegas(texture(TEXTURE, u1).a) * 0.5;
		}
		if (u2.x >= 0.0 && u2.x <= 1.0 && u2.y >= 0.0 && u2.y <= 1.0) {
			jumlah += tegas(texture(TEXTURE, u2).a) * 0.3;
		}
		if (u3.x >= 0.0 && u3.x <= 1.0 && u3.y >= 0.0 && u3.y <= 1.0) {
			jumlah += tegas(texture(TEXTURE, u3).a) * 0.2;
		}
	}

	float luar = clamp(jumlah / 8.0 - asal, 0.0, 1.0);
	COLOR = vec4(warna_glow.rgb, luar * warna_glow.a * keamatan);
}
