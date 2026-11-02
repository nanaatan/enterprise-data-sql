-- Dipanggil oleh seed_data.sql (\ir), bukan dijalankan sendiri.
-- Syarat: temp table _b (id, reg, ts, peg) sudah dibuat, dan variabel psql
-- :cat (kategori layanan), :durasi, :isi, :nreg sudah di-set.

INSERT INTO pelayanan_medis (id_pelayanan_medis, waktu_mulai, waktu_selesai, no_registrasi, id_layanan, versi_harga, id_unit)
OVERRIDING SYSTEM VALUE
SELECT b.id, b.ts, b.ts + :'durasi'::interval, b.reg, pl.id_layanan,
       CASE WHEN b.ts < '2025-01-01' THEN '2024' WHEN b.ts < '2026-01-01' THEN '2025' ELSE '2026' END,
       pl.id_unit
FROM _b b
JOIN _plc c ON c.cat = :'cat'
JOIN _pl pl ON pl.cat = c.cat AND pl.rn = 1 + pg_temp.h(b.id, 900) % c.n;

INSERT INTO entri_rme (id_entri, waktu_entri, isi_entri, id_pegawai)
OVERRIDING SYSTEM VALUE
SELECT :nreg + b.id, b.ts + :'durasi'::interval, :'isi', b.peg
FROM _b b;

INSERT INTO entri_pelayanan (id_entri, id_pelayanan_medis)
SELECT :nreg + b.id, b.id
FROM _b b;
