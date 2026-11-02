-- T4: Resep dan farmasi (apoteker)
-- Alur: pilih kunjungan terbaru -> pelayanan medis -> penunjang medis (diminta dokter)
--       -> farmasi oleh apoteker -> 3 obat berbeda -> entri RME.
\set dok random(121, 190)
\set apt random(396, 420)
\set o1 random(1, 666)
\set o2 random(667, 1333)
\set o3 random(1334, 2000)

SELECT max(no_registrasi) AS maxreg FROM pendaftaran \gset
SELECT count(*) AS n_pl FROM penyediaan_layanan \gset
\set reg random(greatest(1, :maxreg - 5000), :maxreg)
\set k random(0, :n_pl - 1)

BEGIN;

INSERT INTO pelayanan_medis (waktu_mulai, waktu_selesai, no_registrasi, id_layanan, versi_harga, id_unit)
SELECT now(), now() + interval '10 minutes', :reg, pl.id_layanan,
       (SELECT max(t.versi_harga) FROM tarif t WHERE t.id_layanan = pl.id_layanan),
       pl.id_unit
FROM penyediaan_layanan pl
ORDER BY pl.id_unit, pl.id_layanan
OFFSET :k LIMIT 1
RETURNING id_pelayanan_medis \gset

INSERT INTO penunjang_medis (id_pelayanan_medis, laporan_penunjang_medis, tanggal_permintaan, status_kebutuhan, id_pegawai_medis, id_pegawai_paramedis)
VALUES (:id_pelayanan_medis, 'Resep rawat jalan', CURRENT_DATE, 'Selesai', :dok, :apt);

INSERT INTO farmasi (id_pelayanan_medis, laporan_transaksi_obat, id_pegawai)
VALUES (:id_pelayanan_medis, 'Obat diserahkan ke pasien', :apt);

SELECT no_obat, dosis_obat, produsen_obat
FROM obat
WHERE no_obat IN (:o1, :o2, :o3);

INSERT INTO pemberian_obat (id_pelayanan_medis, no_obat, jumlah)
VALUES (:id_pelayanan_medis, :o1, 10),
       (:id_pelayanan_medis, :o2, 15),
       (:id_pelayanan_medis, :o3, 30);

INSERT INTO entri_rme (waktu_entri, isi_entri, id_pegawai)
VALUES (now(), 'Penyerahan obat', :apt)
RETURNING id_entri \gset

INSERT INTO entri_pelayanan (id_entri, id_pelayanan_medis)
VALUES (:id_entri, :id_pelayanan_medis);

END;
